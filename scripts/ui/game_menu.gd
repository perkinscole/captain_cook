class_name GameMenu
extends Control
## The title page and the pause page. While either is up the game stands
## still and the mouse is free.

signal begin(with_lessons: bool)
signal painted_look_toggled

var _dim: ColorRect
var _title_page: Control
var _pause_page: Control
var _look_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.03, 0.04, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_title_page = _page()
	var title_box := _title_page.get_child(0) as VBoxContainer
	_heading(title_box, "Captain Cook Voyages", 58)
	_line(title_box, "A survey of one island, 1769", 24, true)
	_line(title_box, "You are a young officer in His Majesty's Bark Endeavour.\n"
			+ "Sail round the island, chart its coast, keep your people well,\n"
			+ "and bring Captain Cook a chart he can trust.", 20, false)
	_button(title_box, "Begin, with Mr Clerke to show you the ropes",
			func() -> void: _start(true))
	_button(title_box, "Begin without the lessons", func() -> void: _start(false))
	_button(title_box, "Quit", func() -> void: get_tree().quit())

	_pause_page = _page()
	var pause_box := _pause_page.get_child(0) as VBoxContainer
	_heading(pause_box, "Hove to", 46)
	_line(pause_box, Hud.HELP, 18, false).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button(pause_box, "Return to the deck", close)
	_look_button = _button(pause_box, "Painted look: on",
			func() -> void: painted_look_toggled.emit())
	_button(pause_box, "Quit", func() -> void: get_tree().quit())

	show_title()


func show_title() -> void:
	_open(_title_page)


func show_pause() -> void:
	_open(_pause_page)


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func set_painted_look(on: bool) -> void:
	_look_button.text = "Painted look: on" if on else "Painted look: off"


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _pause_page.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _open(page: Control) -> void:
	_title_page.visible = page == _title_page
	_pause_page.visible = page == _pause_page
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _start(with_lessons: bool) -> void:
	close()
	begin.emit(with_lessons)


func _page() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := UiTheme.paper_box(0.97)
	box.set_content_margin_all(34.0)
	panel.add_theme_stylebox_override("panel", box)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	return panel


func _heading(parent: Control, text: String, font_size: int) -> void:
	var label := _line(parent, text, font_size, false)
	label.add_theme_color_override("font_color", UiTheme.RED)


func _line(parent: Control, text: String, font_size: int, italic: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	if italic:
		label.add_theme_font_override("font", UiTheme.ITALIC)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	parent.add_child(button)
	return button
