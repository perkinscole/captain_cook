class_name Hud
extends Control
## Everything shown on screen while sailing: the compass and the state of
## the ship, the crew and stores, messages, the lesson in hand, the key
## prompt, what the hands call back, and the help sheet.
## It only reads from the game's systems; it never changes them.

const HELP := """A / D        order the course a point to port / starboard
W / S        make sail / shorten sail
Space        heave the lead (under 9 knots)
F               take a bearing on the stone pillar you are looking at
E               speak with the person you are looking at
Enter       anchor, when nearly stopped in Matavai Bay
M              open or close the chart table
C               crew and stores
R  /  K  /  G     rations  /  sour krout  /  extra grog
P               painted look on or off
H               this sheet
Esc           pause"""

var ship: Ship
var wind: Wind
var weather: Weather
var control: OrdersMode
var crew: Crew
var supplies: Supplies
var groundings: int = 0

var _status: Label
var _sail: Label
var _warning: Label
var _notice_panel: PanelContainer
var _notice: Label
var _notice_time: float = 0.0
var _lesson_panel: PanelContainer
var _lesson_title: Label
var _lesson: Label
var _prompt_panel: PanelContainer
var _prompt: Label
var _calls: VBoxContainer
var _call_times: Array[float] = []
var _day: Label
var _health: ProgressBar
var _morale: ProgressBar
var _stores: Label
var _crew_detail: Label
var _help_panel: PanelContainer
var _left: Control
var _right: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Top left: compass, then the state of the ship.
	var left := VBoxContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	_left = left
	var rose := CompassRose.new()
	rose.ship = ship
	rose.wind = wind
	rose.control = control
	rose.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(rose)
	var ship_panel := _panel(left)
	var ship_box := _column(ship_panel)
	_status = _text(ship_box, 18, 290.0)
	_sail = _text(ship_box, 18, 290.0)
	_warning = _text(ship_box, 18, 290.0)
	_warning.add_theme_color_override("font_color", UiTheme.RED)

	# Top right: the day, the people, the stores.
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(right)
	_right = right
	var crew_box := _column(_panel(right))
	_day = _text(crew_box, 20, 300.0)
	_health = _bar(crew_box, "Health", UiTheme.GREEN)
	_morale = _bar(crew_box, "Spirits", UiTheme.BRASS)
	_stores = _text(crew_box, 16, 300.0)
	_crew_detail = _text(crew_box, 16, 300.0)
	_crew_detail.visible = false

	# Top middle: messages, and under them the lesson in hand.
	var middle := VBoxContainer.new()
	middle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)
	middle.grow_horizontal = Control.GROW_DIRECTION_BOTH
	middle.add_theme_constant_override("separation", 10)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle)
	_notice_panel = _panel(middle)
	_notice = _text(_notice_panel, 21, 560.0)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_panel.visible = false
	_lesson_panel = _panel(middle)
	_lesson_panel.add_theme_stylebox_override("panel", UiTheme.night_box())
	var lesson_box := _column(_lesson_panel)
	_lesson_title = _text(lesson_box, 17, 560.0)
	_lesson_title.add_theme_color_override("font_color", UiTheme.BRASS)
	_lesson = _text(lesson_box, 20, 560.0)
	_lesson.add_theme_color_override("font_color", UiTheme.CREAM)
	_lesson_panel.visible = false

	# Bottom middle: what the key in reach will do.
	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_and_offsets_preset(
			Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_panel)
	_prompt = _text(_prompt_panel, 20, 0.0)
	_prompt_panel.visible = false

	# Bottom left, above the lead gauge: what the hands call back.
	_calls = VBoxContainer.new()
	_calls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	_calls.offset_bottom = -84.0
	_calls.offset_top = -84.0
	_calls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_calls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_calls)

	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_help_panel)
	var help_text := _text(_help_panel, 20, 0.0)
	help_text.text = HELP
	_help_panel.visible = false


## Shows a message at the top of the screen for a while.
func notify(text: String, seconds: float) -> void:
	_notice.text = text
	_notice_time = seconds
	_notice_panel.visible = true


## Adds a line called out by one of the hands. The last few stay on screen.
func callout(who: String, words: String) -> void:
	var line := Label.new()
	line.text = "%s:  \"%s\"" % [who, words]
	line.add_theme_font_size_override("font_size", 19)
	line.add_theme_color_override("font_color", UiTheme.CREAM)
	line.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	line.add_theme_constant_override("outline_size", 6)
	_calls.add_child(line)
	_call_times.append(7.0)
	if _calls.get_child_count() > 4:
		_calls.get_child(0).free()
		_call_times.remove_at(0)


## Shows what a key will do right now. An empty key hides the prompt.
func set_prompt(key: String, action: String) -> void:
	_prompt_panel.visible = key != ""
	_prompt.text = "[ %s ]   %s" % [key, action]


## Shows the lesson in hand. An empty text hides it.
func set_lesson(title: String, text: String) -> void:
	_lesson_panel.visible = text != ""
	_lesson_title.text = title
	_lesson.text = text


func toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible


func toggle_crew() -> bool:
	_crew_detail.visible = not _crew_detail.visible
	return _crew_detail.visible


## Hides the sailing read-outs while people are talking.
func set_quiet(quiet: bool) -> void:
	_left.visible = not quiet
	_right.visible = not quiet
	_calls.visible = not quiet
	if quiet:
		_help_panel.visible = false
		_prompt_panel.visible = false


func _process(delta: float) -> void:
	if ship == null:
		return
	_notice_time -= delta
	if _notice_time <= 0.0:
		_notice_panel.visible = false
	_notice_panel.modulate.a = clampf(_notice_time / 0.6, 0.0, 1.0)

	for i in range(_call_times.size() - 1, -1, -1):
		_call_times[i] -= delta
		var line := _calls.get_child(i) as Label
		line.modulate.a = clampf(_call_times[i] / 1.5, 0.0, 1.0)
		if _call_times[i] <= 0.0:
			line.free()
			_call_times.remove_at(i)

	_status.text = "%.1f knots,  steering %s\nWind %s,  %s\n%s" % [
		absf(ship.speed) * 1.944, Compass.point_name(ship.heading_deg),
		Compass.point_name(wind.from_deg), _wind_word(wind.strength), _point_of_sail()]

	var working := ""
	var wanted := Ship.SAIL_AREA[ship.sail]
	if ship.canvas < wanted - 0.01:
		working = "  (making sail)"
	elif ship.canvas > wanted + 0.01:
		working = "  (shortening)"
	_sail.text = "Sail %d of %d:  %s%s\nWeather:  %s" % [
		ship.sail, Ship.MAX_SAIL, Ship.SAIL_NAMES[ship.sail], working, weather.state_name()]

	_warning.text = _warning_text()
	_warning.visible = _warning.text != ""

	var total_health := 0.0
	for h in crew.hands:
		total_health += h.health
	_health.value = total_health / maxf(crew.hands.size(), 1.0)
	_morale.value = crew.average_morale()
	_day.text = "Day %d" % supplies.day()
	if crew.sick_count() > 0:
		_day.text += "     %d sick" % crew.sick_count()
	_stores.text = "Fresh food  %.1f days\nSalt provisions  %.1f days" % [
		supplies.greens + (supplies.krout if supplies.serving_krout else 0.0),
		supplies.provisions / Supplies.RATION_RATE[supplies.rations]]
	if _crew_detail.visible:
		_crew_detail.text = "\n" + supplies.report() + "\n\n" + crew.report()


func _warning_text() -> String:
	if ship.is_over_pressed():
		return "She is over-pressed! Shorten sail before something carries away."
	if ship.trim() == Ship.Trim.ABACK:
		return "Sails aback. She is going astern."
	if not supplies.has_fresh_food():
		return "No fresh food. Scurvy is coming."
	if ship.leeway_deg >= 3.0:
		return "Leeway: she sags %d° downwind of her heading." % roundi(ship.leeway_deg)
	return ""


func _point_of_sail() -> String:
	var a := ship.angle_off_wind()
	var tack := "starboard" if ship.relative_wind_deg() > 0.0 else "port"
	if ship.hove_to:
		return "Hove to"
	if ship.trim() == Ship.Trim.FURLED:
		return "Under bare poles"
	if a < Ship.NO_GO_DEG:
		return "Head to wind, sails shivering"
	if a < 80.0:
		return "Close-hauled, %s tack" % tack
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


func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _column(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box


## A label. A width above zero makes it wrap at that width.
func _text(parent: Control, font_size: int, width: float) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	if width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = width
	parent.add_child(label)
	return label


func _bar(parent: Control, title: String, colour: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var label := _text(row, 16, 0.0)
	label.text = title
	label.custom_minimum_size.x = 70.0
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar
