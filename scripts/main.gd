extends Node3D
## Chart one island, with milestone 1 "sailing feel" on top.
## Builds the whole scene in code and wires the separate systems together:
## Weather -> Wind -> Ship <- ControlMode, and Ship + Island -> Charting -> ChartView.

const OCEAN_SHADER := preload("res://shaders/ocean.gdshader")
const START_POSITION := Vector3(0.0, 0.0, 900.0)

const FAIR_SKY_TOP := Color(0.20, 0.33, 0.52)
const FAIR_HORIZON := Color(0.85, 0.72, 0.55)
const FOUL_SKY_TOP := Color(0.10, 0.12, 0.15)
const FOUL_HORIZON := Color(0.33, 0.35, 0.36)

var wind: Wind
var weather: Weather
var ship: Ship
var island: Island
var charting: Charting
var chart_view: ChartView
var camera: DeckCamera

var modes: Array[ControlMode] = []
var mode_index: int = 0
var chart_large: bool = false
var notice: String = ""
var notice_time: float = 0.0

var _ocean: MeshInstance3D
var _ocean_mat: ShaderMaterial
var _sky_mat: ProceduralSkyMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _hud: Label
var _notice_label: Label


func _ready() -> void:
	_build_sky_and_sun()
	_build_ocean()

	wind = Wind.new()
	add_child(wind)

	weather = Weather.new()
	weather.wind = wind
	add_child(weather)
	weather.changed.connect(_on_weather_changed)

	island = Island.new()
	add_child(island)
	island.build(1769)

	ship = Ship.new()
	ship.wind = wind
	ship.position = START_POSITION
	add_child(ship)
	ship.sail_carried_away.connect(_on_sail_carried_away)
	ship.sail_repaired.connect(_on_sail_repaired)

	var visual := ShipVisual.new()
	visual.ship = ship
	ship.add_child(visual)

	camera = DeckCamera.new()
	camera.position = Vector3(0.0, 4.9, 11.5)
	camera.fov = 75.0
	camera.far = 6000.0
	ship.add_child(camera)
	camera.make_current()

	charting = Charting.new()
	charting.ship = ship
	charting.island = island
	add_child(charting)
	charting.start()
	charting.completed.connect(_on_chart_completed)

	modes.append(OrdersMode.new())
	modes.append(HelmMode.new())
	for mode in modes:
		add_child(mode)
	modes[mode_index].activate(ship)

	_build_ui()
	_say("Chart the island ahead. Sail right round it within sight of the shore.", 10.0)


func _physics_process(delta: float) -> void:
	modes[mode_index].steer(ship, delta)
	ship.sea_state = weather.sea_state
	charting.sight_range = Charting.CLEAR_SIGHT_RANGE * weather.visibility

	var safe := island.keep_off(ship.position)
	if not safe.is_equal_approx(ship.position):
		ship.run_aground(safe)
		_say("She touches! Shoal water. Bear away from the shore.", 5.0)


func _process(delta: float) -> void:
	_ocean.position = Vector3(ship.position.x, 0.0, ship.position.z)
	_apply_weather_look()

	var mode := modes[mode_index]
	var lines := PackedStringArray([
		"Heading %03d° (%s)    %.1f knots" % [
			roundi(ship.heading_deg) % 360, Compass.point_name(ship.heading_deg), ship.speed * 1.944],
		"Wind from %s, %s" % [Compass.point_name(wind.from_deg), _wind_word(wind.strength)],
		"Weather: %s" % weather.state_name(),
		_point_of_sail(),
		_sail_line(),
		_warning_line(),
		"",
		"[%s]  %s" % [mode.mode_name(), mode.status(ship)],
		"",
		mode.help(),
		"W / S  make / reduce sail",
		"Tab  change control mode      M  chart      Mouse  look      Esc  free mouse",
	])
	_hud.text = "\n".join(lines)

	notice_time -= delta
	_notice_label.text = notice if notice_time > 0.0 else ""

	var view := get_viewport().get_visible_rect().size
	var side := minf(view.x, view.y) - 80.0 if chart_large else 280.0
	chart_view.size = Vector2(side, side)
	if chart_large:
		chart_view.position = (view - chart_view.size) * 0.5
	else:
		chart_view.position = view - chart_view.size - Vector2(16.0, 16.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.look(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		match key:
			KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_TAB:
				mode_index = (mode_index + 1) % modes.size()
				modes[mode_index].activate(ship)
				_say("Control mode: %s" % modes[mode_index].mode_name(), 3.0)
			KEY_M:
				chart_large = not chart_large
			KEY_W:
				if not ship.set_sail(ship.sail + 1) and ship.sail_limit < Ship.MAX_SAIL:
					_say("No more sail until the hands have bent a new one.", 4.0)
			KEY_S:
				ship.set_sail(ship.sail - 1)
			_:
				modes[mode_index].handle_key(ship, key)


func _on_chart_completed() -> void:
	chart_large = true
	_say("The survey is complete. A fair chart of the island, sir.  (M to put it away)", 20.0)


func _on_weather_changed(state: Weather.State) -> void:
	match state:
		Weather.State.BUILDING:
			_say("A squall is making up to windward. Shorten sail while you can.", 8.0)
		Weather.State.SQUALL:
			_say("The squall is on us! Mind the wind shift.", 6.0)
		Weather.State.CLEARING:
			_say("It is blowing over.", 5.0)
		Weather.State.MIST:
			_say("Mist is closing in. You must stand closer in to fix the coast.", 8.0)
		Weather.State.FAIR:
			_say("Fair weather again.", 5.0)


func _on_sail_carried_away() -> void:
	_say("A sail has blown out of its bolt-ropes! She is down to topsails.", 8.0)


func _on_sail_repaired() -> void:
	_say("New canvas is bent on. You may make sail again.", 5.0)


func _sail_line() -> String:
	var text := "Sail ordered: %s" % Ship.SAIL_NAMES[ship.sail]
	var wanted := Ship.SAIL_AREA[ship.sail]
	if ship.canvas < wanted - 0.01:
		text += "  (hands making sail...)"
	elif ship.canvas > wanted + 0.01:
		text += "  (hands shortening sail...)"
	return text


func _warning_line() -> String:
	if ship.is_over_pressed():
		return "!! She is over-pressed. Reduce sail before something carries away."
	if ship.trim() == Ship.Trim.ABACK:
		return "!! Sails aback. She is making sternway."
	if ship.leeway_deg >= 3.0:
		return "Leeway: sagging about %d° downwind of her heading" % roundi(ship.leeway_deg)
	return ""


func _apply_weather_look() -> void:
	var g := weather.gloom
	_sky_mat.sky_top_color = FAIR_SKY_TOP.lerp(FOUL_SKY_TOP, g)
	_sky_mat.sky_horizon_color = FAIR_HORIZON.lerp(FOUL_HORIZON, g)
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
	_sun.light_energy = lerpf(1.3, 0.3, g)
	_env.fog_light_color = _sky_mat.sky_horizon_color
	_env.fog_density = lerpf(0.0004, 0.006, clampf(1.0 - weather.visibility, 0.0, 1.0))
	_ocean_mat.set_shader_parameter("storm", g)


func _say(text: String, seconds: float) -> void:
	notice = text
	notice_time = seconds


func _point_of_sail() -> String:
	var a := ship.angle_off_wind()
	var tack := "starboard" if ship.relative_wind_deg() > 0.0 else "port"
	if ship.trim() == Ship.Trim.FURLED:
		return "Under bare poles"
	if a < Ship.NO_GO_DEG:
		return "Head to wind: sails shivering. Bear away, or carry her through the tack."
	if a < 80.0:
		return "Close-hauled on the %s tack" % tack
	if a < 110.0:
		return "Wind on the %s beam" % tack
	if a < 160.0:
		return "Wind on the %s quarter" % tack
	return "Running before the wind"


func _wind_word(strength: float) -> String:
	if strength < 4.0:
		return "light airs"
	if strength < 7.0:
		return "a gentle breeze"
	if strength < 10.0:
		return "a fresh breeze"
	if strength < 13.0:
		return "a strong breeze"
	return "blowing hard"


func _build_sky_and_sun() -> void:
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = FAIR_SKY_TOP
	_sky_mat.sky_horizon_color = FAIR_HORIZON
	_sky_mat.ground_bottom_color = Color(0.02, 0.08, 0.14)
	_sky_mat.ground_horizon_color = FAIR_HORIZON
	var sky := Sky.new()
	sky.sky_material = _sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_density = 0.0004
	_env.fog_light_color = FAIR_HORIZON

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-24.0, -125.0, 0.0)
	_sun.light_color = Color(1.0, 0.90, 0.74)
	_sun.light_energy = 1.3
	_sun.shadow_enabled = true
	add_child(_sun)


func _build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	_ocean_mat = ShaderMaterial.new()
	_ocean_mat.shader = OCEAN_SHADER
	_ocean = MeshInstance3D.new()
	_ocean.mesh = plane
	_ocean.material_override = _ocean_mat
	add_child(_ocean)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_hud = _label(16)
	_hud.position = Vector2(16.0, 12.0)
	layer.add_child(_hud)

	_notice_label = _label(22)
	_notice_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.position.y = 24.0
	layer.add_child(_notice_label)

	chart_view = ChartView.new()
	chart_view.charting = charting
	chart_view.ship = ship
	chart_view.wind = wind
	chart_view.centre = Vector2(island.position.x, island.position.z)
	layer.add_child(chart_view)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 5)
	return label
