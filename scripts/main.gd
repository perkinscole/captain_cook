extends Node3D
## Chart one island, anchor at Matavai Bay, and show the chart to Captain Cook.
## This script builds the scene in code and wires the separate systems
## together. Each system lives in its own file and knows as little as it can
## about the others:
##
##   Weather -> Wind -> Ship <- OrdersMode        sailing
##   Sea                                          the waves she rides
##   Ship + Island -> Charting -> ChartView       the survey
##   Seabed -> LeadLine                           soundings
##   Supplies -> Crew                             the people, and how well they work
##   Dialogue -> DialogueBox + Figure             talk
##   Landfall                                     the anchorage and the beach
##   Tutorial, Hud, GameMenu, SoundBoard          teaching, showing and sounding

const PAINTERLY := preload("res://shaders/painterly.gdshader")
const START_POSITION := Vector3(0.0, 0.0, 700.0)
const DECK_Y := ShipVisual.DECK_Y
const COOK_POSITION := Vector3(2.6, DECK_Y, 8.0)  # quarterdeck, starboard side
const COOK_IDLE_FACING := -0.9                    # looking out over the bow
const MATAVAI_ANGLE := -1.74  # where the bay lies: on the north side, just west of Point Venus
const AIM_CONE := 0.9996  # cosine of how near the cross-hairs a landmark must be
const NAKED_EYE_FOV := 75.0
const SPYGLASS_FOV := 14.0

var wind: Wind
var weather: Weather
var sea: Sea
var atmosphere: Atmosphere
var ship: Ship
var island: Island
var seabed: Seabed
var lead: LeadLine
var supplies: Supplies
var crew: Crew
var charting: Charting
var landfall: Landfall
var camera: DeckCamera
var control: OrdersMode
var story := StoryState.new()
var dialogue: Dialogue
var tutorial: Tutorial
var sound: SoundBoard
var cook: Figure

var hud: Hud
var menu: GameMenu
var chart_view: ChartView
var dialogue_box: DialogueBox

var cook_in_view: bool = false
var hand_in_view: Hand = null
var landmark_in_view: int = -1
var chart_large: bool = false
var spyglass_up: bool = false
var groundings: int = 0

var _spyglass: Spyglass
var _paint: ColorRect
var _lead_gauge: LeadGauge
var _last_safe := Vector2.ZERO
var _lookout_quiet: float = 0.0
var _aground_lately: float = 0.0
var _speaker: Figure
var _scene: String = ""        # which kind of conversation is running
var _cast: Dictionary = {}     # speaker id -> Figure
var _hand_figures: Dictionary = {}  # Hand -> Figure
var _tupaia_aboard: Figure
var _told_of_bay: bool = false
var _sail_settled: bool = true
var _was_shivering: bool = false


func _ready() -> void:
	atmosphere = Atmosphere.new()
	add_child(atmosphere)

	sound = SoundBoard.new()
	add_child(sound)
	wind = Wind.new()
	add_child(wind)
	sea = Sea.new()
	sea.wind = wind
	add_child(sea)
	weather = Weather.new()
	weather.wind = wind
	weather.held = true  # fair weather until the lessons are over
	add_child(weather)
	weather.changed.connect(_on_weather_changed)

	island = Island.new()
	island.keep_clear_angle = wrapf(MATAVAI_ANGLE, 0.0, TAU)
	add_child(island)
	island.build(1769)
	var gulls := Birds.new()
	gulls.count = 14
	gulls.spread = Vector2(240.0, 430.0)
	gulls.heights = Vector2(20.0, 70.0)
	add_child(gulls)

	seabed = Seabed.new()
	seabed.island = island
	add_child(seabed)
	seabed.build(1770)
	landfall = Landfall.new()
	landfall.island = island
	add_child(landfall)
	landfall.build(MATAVAI_ANGLE)
	seabed.clear_around(landfall.anchorage, Landfall.ANCHOR_RADIUS + 60.0)
	sea.set_depth_map(seabed, Vector2(island.position.x, island.position.z))

	ship = Ship.new()
	ship.wind = wind
	ship.position = START_POSITION
	add_child(ship)
	ship.sail_carried_away.connect(_on_sail_carried_away)
	ship.sail_repaired.connect(_on_sail_repaired)
	_last_safe = Vector2(START_POSITION.x, START_POSITION.z)
	sea.follow(ship.position)
	var wake := Wake.new()
	wake.ship = ship
	wake.sea = sea
	add_child(wake)
	var visual := ShipVisual.new()
	visual.ship = ship
	ship.add_child(visual)

	camera = DeckCamera.new()
	camera.position = Vector3(0.0, DECK_Y + 1.75, 11.5)
	camera.fov = 75.0
	camera.near = 0.1
	camera.far = 9000.0
	ship.add_child(camera)
	camera.make_current()
	landfall.deck_camera = camera
	var followers := Birds.new()
	followers.count = 4
	followers.spread = Vector2(25.0, 70.0)
	followers.heights = Vector2(22.0, 40.0)
	followers.follow = ship
	add_child(followers)

	lead = LeadLine.new()
	lead.ship = ship
	lead.seabed = seabed
	add_child(lead)
	lead.cast_made.connect(_on_cast_made)
	lead.swing_started.connect(func() -> void: hud.callout("Pascoe, in the chains", "Heave!"))

	charting = Charting.new()
	charting.ship = ship
	charting.island = island
	add_child(charting)
	charting.start()
	charting.completed.connect(_on_chart_completed)

	control = OrdersMode.new()
	add_child(control)
	control.activate(ship)

	cook = Figure.new()
	cook.position = COOK_POSITION
	cook.idle_facing = COOK_IDLE_FACING
	ship.add_child(cook)
	_tupaia_aboard = Figure.new()
	Landfall.dress_as_tupaia(_tupaia_aboard)
	_tupaia_aboard.position = COOK_POSITION + Vector3(-1.2, 0.0, 1.6)
	_tupaia_aboard.visible = false
	ship.add_child(_tupaia_aboard)
	_cast = {"cook": cook, "tupaia_deck": _tupaia_aboard}
	_cast.merge(landfall.figures)

	supplies = Supplies.new()
	add_child(supplies)
	supplies.news.connect(_on_news)
	supplies.day_began.connect(_on_day_began)
	crew = Crew.new()
	crew.supplies = supplies
	add_child(crew)
	crew.news.connect(_on_news)
	supplies.set_process(false)  # the clock starts when the lessons end
	crew.set_process(false)
	_place_hand("helm", Vector3(0.0, DECK_Y, 13.6), 0.0)
	_place_hand("lead", Vector3(3.3, DECK_Y, 2.0), -PI * 0.5)
	_place_hand("sails", Vector3(-1.7, DECK_Y, -2.0), PI)
	_place_hand("cook", Vector3(1.6, DECK_Y, -8.5), PI)
	_place_hand("lookout", Vector3(0.0, DECK_Y + 30.0 * ShipVisual.TOP_AT + 0.08, 0.85), 0.0)

	dialogue = Dialogue.new()
	dialogue.story = story
	add_child(dialogue)
	dialogue.line_changed.connect(_on_dialogue_line)
	dialogue.finished.connect(_on_dialogue_finished)

	tutorial = Tutorial.new()
	tutorial.ship = ship
	tutorial.control = control
	tutorial.charting = charting
	add_child(tutorial)
	tutorial.step_done.connect(func() -> void: sound.play("bell_2", -12.0))
	tutorial.finished.connect(_on_lessons_over)

	_build_ui()


# --- every frame -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not dialogue.active:
		control.steer(ship, delta)
	charting.visibility = weather.visibility
	ship.sail_handling = crew.efficiency("sails")
	control.helm_skill = crew.efficiency("helm")
	lead.skill = crew.efficiency("lead")
	_aground_lately = maxf(0.0, _aground_lately - delta)
	_ride_the_waves(delta)

	var here := Vector2(ship.position.x, ship.position.z)
	var depth := seabed.depth_at(here)
	if depth < Seabed.SHIP_DRAUGHT:
		_run_aground()
	elif depth > Seabed.SHIP_DRAUGHT + 1.5:
		_last_safe = here

	# In clear weather the masthead lookout can see pale water ahead.
	_lookout_quiet -= delta
	var sharp := crew.efficiency("lookout")  # a sick or miserable lookout sees less far
	if _lookout_quiet <= 0.0 and weather.visibility > 0.7 and ship.speed > 0.5 and sharp > 0.5:
		var ahead := here + Compass.to_vector(ship.heading_deg) * 120.0 * sharp
		if seabed.depth_at(ahead) < Seabed.SHIP_DRAUGHT + 1.0:
			_lookout_quiet = 10.0
			hud.callout("Young, at the masthead", "Pale water dead ahead!")
			if not sound.say("pale_water"):
				sound.play("pipe_attention", -10.0)


func _process(delta: float) -> void:
	sea.sea_state = weather.sea_state
	sea.follow(ship.position)
	atmosphere.apply(weather.gloom, weather.visibility, wind.from_deg,
			fposmod(supplies.days * 0.5, 1.0), delta)
	sea.storm = weather.gloom
	sea.sky_color = atmosphere.horizon
	sound.set_ambience(wind.strength, absf(ship.speed), weather.sea_state)
	_sail_sounds()

	var talking := dialogue.active
	if talking:
		spyglass_up = false
	var ease := 1.0 - exp(-10.0 * delta)
	camera.fov = lerpf(camera.fov, SPYGLASS_FOV if spyglass_up else NAKED_EYE_FOV, ease)
	camera.sensitivity_scale = camera.fov / NAKED_EYE_FOV
	_spyglass.raised = spyglass_up
	if talking and _speaker != null:
		landfall.active_camera().ease_toward(_speaker.eye_position(), 1.0 - exp(-3.0 * delta))

	# What is the player looking at, and what could they do about it?
	var to_cook := (ship.to_global(cook.eye_position()) - camera.global_position).normalized()
	cook_in_view = not spyglass_up and to_cook.dot(-camera.global_transform.basis.z) > 0.93
	hand_in_view = null if cook_in_view or spyglass_up else _find_hand_in_view()
	var someone := cook_in_view or hand_in_view != null
	landmark_in_view = _find_landmark_in_view() if spyglass_up else -1
	_spyglass.aimed = landmark_in_view
	var may_anchor := not story.has_flag("landfall_done") and landfall.can_anchor(ship)
	if not _told_of_bay and not story.has_flag("landfall_done") and landfall.is_near(ship):
		_told_of_bay = true
		_say("This is Matavai Bay. To anchor, bring her nearly to a stop "
				+ "(under 5 knots) and press Enter.", 10.0)

	hud.groundings = groundings
	hud.set_quiet(talking)
	if talking:
		hud.set_lesson("", "")
	else:
		hud.set_lesson(tutorial.title(), tutorial.text())
		if may_anchor:
			hud.set_prompt("Enter", "anchor in %s" % landfall.anchorage_name)
		elif cook_in_view:
			hud.set_prompt("E", "speak with Captain Cook")
		elif hand_in_view != null:
			hud.set_prompt("E", "speak with %s" % hand_in_view.full_name)
		elif landmark_in_view >= 0:
			hud.set_prompt("F", "take a bearing on %s" % island.landmark_name(landmark_in_view))
		elif spyglass_up:
			hud.set_prompt("Q", "lower the spyglass.  Put the cross on a named landmark.")
		else:
			hud.set_prompt("", "")

	_lead_gauge.visible = not talking
	chart_view.detailed = chart_large
	var view := get_viewport().get_visible_rect().size
	var side := minf(view.x, view.y) - 80.0 if chart_large else 250.0
	chart_view.size = Vector2(side, side)
	if chart_large:
		chart_view.position = (view - chart_view.size) * 0.5
	else:
		chart_view.position = view - chart_view.size - Vector2(16.0, 16.0)
	_lead_gauge.position = Vector2((view.x - LeadGauge.BAR.x) * 0.5, view.y - 120.0)


## Lifts and tilts the ship with the water under her bow, stern and sides.
func _ride_the_waves(delta: float) -> void:
	var p := ship.position
	var fwd := ship.forward()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var bow := sea.height_at(p.x + fwd.x * 13.0, p.z + fwd.z * 13.0)
	var stern := sea.height_at(p.x - fwd.x * 13.0, p.z - fwd.z * 13.0)
	var starboard := sea.height_at(p.x + right.x * 4.0, p.z + right.z * 4.0)
	var port := sea.height_at(p.x - right.x * 4.0, p.z - right.z * 4.0)
	var ease := 1.0 - exp(-3.0 * delta)  # she is heavy, and follows the sea slowly
	ship.wave_lift = lerpf(ship.wave_lift, (bow + stern + starboard + port) * 0.2, ease)
	ship.wave_pitch = lerpf(ship.wave_pitch, atan2(bow - stern, 26.0) * 0.8, ease)
	ship.wave_roll = lerpf(ship.wave_roll, atan2(starboard - port, 8.0) * 0.35, ease)


func _sail_sounds() -> void:
	var settled := absf(ship.canvas - Ship.SAIL_AREA[ship.sail]) < 0.01
	if settled and not _sail_settled and ship.canvas > 0.05:
		sound.play("sail_thump", -6.0)
	_sail_settled = settled
	var shivering := ship.trim() == Ship.Trim.SHIVERING or ship.trim() == Ship.Trim.ABACK
	if shivering and not _was_shivering:
		sound.play("sail_flap", -6.0)
	_was_shivering = shivering


# --- keys and mouse --------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			spyglass_up = event.pressed and not dialogue.active  # hold to look
		elif event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not dialogue.active:
			camera.look(event.relative)
			tutorial.looked(event.relative.length())
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if key == KEY_ESCAPE:
			menu.show_pause()
		elif key == KEY_P:
			_toggle_painted_look()
		elif dialogue.active:
			_dialogue_key(key)
		else:
			_sailing_key(key)


func _sailing_key(key: Key) -> void:
	match key:
		KEY_A, KEY_D:
			control.handle_key(ship, key)
			var side := "port" if key == KEY_A else "starboard"
			hud.callout("Trull, at the wheel", "%s a point, aye! Steering %s." % [
				side.capitalize(), Compass.point_name(control.ordered_deg)])
			if not sound.say("helm_" + side):
				sound.play("pipe_helm", -14.0)
		KEY_W:
			_order_sail(ship.sail + 1)
		KEY_S:
			_order_sail(ship.sail - 1)
		KEY_SPACE:
			lead.heave()
		KEY_Q:
			spyglass_up = not spyglass_up
			sound.play("tick")
		KEY_F:
			if not spyglass_up:
				_say("Raise the spyglass first (Q), and put the cross on a landmark.", 5.0)
			elif landmark_in_view >= 0:
				var fixed_before := charting.fixed_count()
				_say(charting.take_bearing(landmark_in_view), 7.0)
				sound.play("tick")
				if charting.fixed_count() > fixed_before:
					crew.cheer(1.5)  # the work is going well, and they can see it
					tutorial.note("fix")
		KEY_E:
			if cook_in_view:
				_speak_with_cook()
			elif hand_in_view != null:
				_speak_with_hand(hand_in_view)
		KEY_ENTER:
			if not story.has_flag("landfall_done") and landfall.can_anchor(ship):
				_anchor_at_matavai()
		KEY_M:
			chart_large = not chart_large
			sound.play("paper")
			tutorial.note("chart_opened" if chart_large else "chart_closed")
		KEY_C:
			if hud.toggle_crew():
				tutorial.note("crew_panel")
		KEY_H:
			hud.toggle_help()
		KEY_T:
			tutorial.skip()
		KEY_R:
			supplies.cycle_rations()
			_say("Rations: %s." % Supplies.RATION_NAMES[supplies.rations], 4.0)
		KEY_K:
			supplies.serving_krout = not supplies.serving_krout
			_say("Sour krout will be served with dinner." if supplies.serving_krout
					else "No more sour krout at dinner.", 4.0)
		KEY_G:
			if supplies.grog > 0:
				supplies.grog -= 1
				crew.cheer(12.0)
				sound.play("pipe_attention", -8.0)
				_say("An extra issue of grog. The people give a cheer.", 5.0)
			else:
				_say("There is no grog to spare.", 4.0)


func _order_sail(level: int) -> void:
	var before := ship.sail
	var granted := ship.set_sail(level)
	if not granted and ship.sail_limit < Ship.MAX_SAIL:
		_say("No more sail until the hands have bent a new one.", 4.0)
	if ship.sail == before:
		return
	tutorial.note("sail")
	var making := ship.sail > before
	hud.callout("Harker, boatswain's mate", "%s! %s it is." % [
		"Hands aloft, make sail" if making else "Hands aloft, shorten sail",
		Ship.SAIL_NAMES[ship.sail]])
	if not sound.say("make_sail" if making else "shorten_sail"):
		sound.play("pipe_make_sail" if making else "pipe_shorten_sail", -8.0)


func _dialogue_key(key: Key) -> void:
	if not dialogue_box.is_fully_shown():
		if key == KEY_SPACE or key == KEY_E or key == KEY_ENTER:
			dialogue_box.show_all()
	elif dialogue.choices.is_empty():
		if key == KEY_SPACE or key == KEY_E or key == KEY_ENTER:
			dialogue.advance()
	elif key >= KEY_1 and key <= KEY_9:
		dialogue.choose(key - KEY_1)


func _toggle_painted_look() -> void:
	_paint.visible = not _paint.visible
	menu.set_painted_look(_paint.visible)


# --- starting, and the lessons ---------------------------------------------

func _on_begin(with_lessons: bool) -> void:
	if with_lessons:
		tutorial.start()
	else:
		_on_lessons_over()


## The lessons are done (or skipped): start the clock and let the weather go.
func _on_lessons_over() -> void:
	weather.held = false
	supplies.set_process(true)
	crew.set_process(true)
	sound.play("bell_8", -8.0)
	_say("You have the deck. Chart the island, keep your people well, "
			+ "and bring the captain a chart he can trust.", 10.0)


# --- talk ------------------------------------------------------------------

func _speak_with_hand(h: Hand) -> void:
	_scene = "hand"
	_speaker = _hand_figures[h]
	_speaker.facing = camera.yaw_to_face_me(_speaker.position)
	crew.noticed(h)
	tutorial.note("talked")
	var line := CrewLines.line_for(h, supplies, weather.visibility < 0.6, _aground_lately > 0.0)
	dialogue.start({
		"start": "line",
		"nodes": {"line": {"who": "%s, %s" % [h.full_name, h.title], "text": line}},
	})


func _speak_with_cook() -> void:
	chart_large = false
	ship.hove_to = true
	_scene = "cook"
	_speaker = cook
	cook.facing = camera.yaw_to_face_me(cook.position)
	tutorial.note("talked")
	if not charting.complete:
		dialogue.start(CookScenes.ORDERS)
	elif not story.has_flag("chart_shown"):
		if charting.accuracy() >= 0.75:
			story.flags["chart_fine"] = true
		elif charting.accuracy() < 0.4:
			story.flags["chart_rough"] = true
		dialogue.start(CookScenes.THE_CHART)
	else:
		dialogue.start(CookScenes.CARRY_ON)


func _anchor_at_matavai() -> void:
	_scene = "landfall"
	chart_large = false
	ship.hove_to = true
	ship.set_sail(0)
	_speaker = null
	_tupaia_aboard.visible = true
	sound.play("anchor")
	if not sound.say("anchor"):
		sound.play("pipe_still", -10.0)
	dialogue.start(TahitiScenes.LANDFALL)


func _finish_landfall() -> void:
	story.flags["landfall_done"] = true
	landfall.set_stage("deck")
	_tupaia_aboard.visible = false
	ship.set_sail(1)
	control.activate(ship)

	# What came of it. Good relations fill the boat; a quarrel empties it.
	var goodwill: int = story.relations.get("tahiti", 0)
	var barter_bonus := 1.0 if story.has_flag("open_barter") else 0.0
	supplies.greens = clampf(3.0 + goodwill, 1.0, 7.0)
	supplies.provisions += clampf(2.0 + 0.5 * goodwill + barter_bonus, 0.5, 5.0)
	crew.cheer(6.0 + goodwill)
	var outcome := "The boat comes back well laden."
	if goodwill >= 3:
		outcome = "The boat comes back loaded to the gunwales, and with an invitation."
	elif goodwill < 0:
		outcome = "The boat comes back half empty. Nobody ashore will trade."
	_say("%s Fresh food for %d days. The anchor is weighed." % [
		outcome, roundi(supplies.greens)], 12.0)


func _on_dialogue_line() -> void:
	dialogue_box.refresh()
	sound.play("tick", -6.0)
	var node := dialogue.current
	if node.has("stage") and node["stage"] != landfall.stage:
		landfall.set_stage(node["stage"])
		_speaker = null  # nobody to look at until someone here speaks
	if node.has("speaker") and _cast.has(node["speaker"]):
		var next_speaker: Figure = _cast[node["speaker"]]
		if next_speaker != _speaker:
			_speaker = next_speaker
			_speaker.facing = landfall.active_camera().yaw_to_face_me(_speaker.position)
	if _speaker != null and dialogue.who != "":
		_speaker.set_pose(dialogue.pose)


func _on_dialogue_finished() -> void:
	ship.hove_to = false
	for id: String in _cast:
		var figure: Figure = _cast[id]
		figure.facing = figure.idle_facing
		figure.set_pose("at_ease")
	if _speaker != null:
		_speaker.facing = _speaker.idle_facing
		_speaker.set_pose("at_ease")
	if _scene == "landfall":
		_finish_landfall()
	if _scene != "cook":
		return
	chart_view.dot_guesses = story.has_flag("chart_dotted")
	if story.has_flag("chart_shown") and not story.has_flag("chart_scene_done"):
		story.flags["chart_scene_done"] = true
		chart_large = true
		sound.play("paper")
		if story.has_flag("chart_dotted"):
			crew.cheer(3.0)
			_say("The doubtful coast is pricked in with dots.  (M to put the chart away)", 12.0)
		else:
			_say("The chart stands as you drew it.  (M to put the chart away)", 12.0)


# --- things that happen ----------------------------------------------------

func _on_chart_completed() -> void:
	sound.play("bell_2", -6.0)
	_say("The coast is all sketched in, with %d of %d landmarks fixed. Fix more for a "
			% [charting.fixed_count(), charting.mark_error.size()]
			+ "truer chart, or show it to Captain Cook on the quarterdeck (look at him, press E).",
			20.0)


func _on_news(text: String) -> void:
	_say(text, 8.0)


func _on_day_began(_day: int) -> void:
	sound.play("bell_8", -12.0)


func _on_cast_made(cry: String, voice: String) -> void:
	if voice != "lead_too_fast":
		sound.play("splash", -4.0)
	hud.callout("Pascoe, in the chains", cry)
	sound.say(voice)
	tutorial.note("sounding")


func _run_aground() -> void:
	groundings += 1
	_aground_lately = 90.0
	crew.cheer(-8.0)
	sound.play("grounding")
	sound.say("aground")
	ship.run_aground(Vector3(_last_safe.x, 0.0, _last_safe.y))
	ship.heading_deg = Compass.from_vector(seabed.deeper_direction(_last_safe))
	ship.set_sail(1)
	control.activate(ship)
	_say("She strikes! Coral under the keel. It takes the boats and the anchors "
			+ "to haul her off. Sound before you stand in.", 9.0)


func _on_weather_changed(state: Weather.State) -> void:
	match state:
		Weather.State.BUILDING:
			sound.play("pipe_attention", -6.0)
			_say("A squall is making up to windward. Shorten sail while you can.", 8.0)
		Weather.State.SQUALL:
			_say("The squall is on us! Mind the wind shift.", 6.0)
		Weather.State.CLEARING:
			if ship.sail_limit == Ship.MAX_SAIL:
				crew.cheer(3.0)  # came through it with nothing carried away
			_say("It is blowing over.", 5.0)
		Weather.State.MIST:
			_say("Mist is closing in. You must stand closer in to fix the coast.", 8.0)
		Weather.State.FAIR:
			_say("Fair weather again.", 5.0)


func _on_sail_carried_away() -> void:
	crew.cheer(-4.0)
	sound.play("sail_flap")
	_say("A sail has blown out of its bolt-ropes! She is down to topsails.", 8.0)


func _on_sail_repaired() -> void:
	_say("New canvas is bent on. You may make sail again.", 5.0)


func _say(text: String, seconds: float) -> void:
	hud.notify(text, seconds)


# --- finding things in view ------------------------------------------------

func _find_hand_in_view() -> Hand:
	var eye := camera.global_position
	var looking := -camera.global_transform.basis.z
	var best: Hand = null
	var best_dot := 0.975
	for h: Hand in _hand_figures:
		var figure: Figure = _hand_figures[h]
		var d := (ship.to_global(figure.eye_position()) - eye).normalized().dot(looking)
		if d > best_dot:
			best_dot = d
			best = h
	return best


func _find_landmark_in_view() -> int:
	var eye := camera.global_position
	var looking := -camera.global_transform.basis.z
	var best := -1
	var best_dot := AIM_CONE
	for k in island.landmarks.size():
		if not charting.can_take_bearing(k):
			continue
		var d := (island.landmark_aim_point(k) - eye).normalized().dot(looking)
		if d > best_dot:
			best_dot = d
			best = k
	return best


# --- building the scene ----------------------------------------------------

func _place_hand(role: String, at: Vector3, facing: float) -> void:
	var h := crew.hand_for(role)
	var figure := Figure.new()
	figure.position = at
	figure.idle_facing = facing
	figure.coat_color = h.jacket
	figure.legs_color = Color(0.80, 0.76, 0.66)
	figure.skin_color = h.skin
	figure.hair_color = h.hair
	figure.neck_color = h.kerchief
	if h.boy:
		figure.scale = Vector3(0.8, 0.8, 0.8)
	figure.wears_hat = false
	figure.long_coat = false
	ship.add_child(figure)
	_hand_figures[h] = figure


func _build_ui() -> void:
	# The painted look sits between the 3D picture and the interface, so the
	# picture is painted and the words stay sharp.
	var paint_layer := CanvasLayer.new()
	paint_layer.layer = 0
	add_child(paint_layer)
	_paint = ColorRect.new()
	_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paint_mat := ShaderMaterial.new()
	paint_mat.shader = PAINTERLY
	_paint.material = paint_mat
	paint_layer.add_child(_paint)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	layer.add_child(root)

	hud = Hud.new()
	hud.ship = ship
	hud.wind = wind
	hud.weather = weather
	hud.control = control
	hud.crew = crew
	hud.supplies = supplies
	root.add_child(hud)

	_spyglass = Spyglass.new()
	_spyglass.camera = camera
	_spyglass.island = island
	_spyglass.charting = charting
	root.add_child(_spyglass)
	root.move_child(_spyglass, 0)  # under the read-outs, over the picture

	_lead_gauge = LeadGauge.new()
	_lead_gauge.lead = lead
	root.add_child(_lead_gauge)

	chart_view = ChartView.new()
	chart_view.charting = charting
	chart_view.lead = lead
	chart_view.ship = ship
	chart_view.wind = wind
	chart_view.centre = Vector2(island.position.x, island.position.z)
	chart_view.anchorage = landfall.anchorage
	chart_view.anchorage_name = landfall.anchorage_name
	root.add_child(chart_view)

	dialogue_box = DialogueBox.new()
	dialogue_box.dialogue = dialogue
	root.add_child(dialogue_box)

	menu = GameMenu.new()
	root.add_child(menu)
	menu.begin.connect(_on_begin)
	menu.painted_look_toggled.connect(_toggle_painted_look)
