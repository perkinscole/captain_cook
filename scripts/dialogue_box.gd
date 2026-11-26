class_name DialogueBox
extends ColorRect
## Shows the current line of a Dialogue at the foot of the screen, writing it
## out a few letters at a time, then any choices.

const LETTERS_PER_SECOND := 45.0

var dialogue: Dialogue

var _name_label: Label
var _text_label: Label
var _choices_label: Label
var _hint_label: Label
var _shown: float = 0.0


func _ready() -> void:
	color = Color(0.05, 0.04, 0.03, 0.82)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	_name_label = _label(box, 18, Color(0.93, 0.78, 0.45))
	_text_label = _label(box, 21, Color(0.96, 0.93, 0.84))
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choices_label = _label(box, 19, Color(0.80, 0.88, 0.95))
	_hint_label = _label(box, 14, Color(0.70, 0.66, 0.58))


## Call when the dialogue moves to a new line.
func refresh() -> void:
	_shown = 0.0


func is_fully_shown() -> bool:
	return dialogue == null or _shown >= dialogue.text.length()


func show_all() -> void:
	if dialogue != null:
		_shown = dialogue.text.length()


func _process(delta: float) -> void:
	visible = dialogue != null and dialogue.active
	if not visible:
		return

	var view := get_viewport().get_visible_rect().size
	size = Vector2(minf(view.x - 80.0, 900.0), 230.0)
	position = Vector2((view.x - size.x) * 0.5, view.y - size.y - 24.0)

	_shown += LETTERS_PER_SECOND * delta
	_name_label.text = dialogue.who
	_name_label.visible = dialogue.who != ""
	_text_label.text = dialogue.text
	_text_label.visible_characters = -1 if is_fully_shown() else int(_shown)

	var done := is_fully_shown()
	if done and not dialogue.choices.is_empty():
		var lines := PackedStringArray()
		for i in dialogue.choices.size():
			var choice: Dictionary = dialogue.choices[i]
			lines.append("%d.  %s" % [i + 1, choice.get("text", "")])
		_choices_label.text = "\n".join(lines)
		_hint_label.text = "Press the number of your answer"
	else:
		_choices_label.text = ""
		_hint_label.text = "Space  continue" if done else ""
	_choices_label.visible = _choices_label.text != ""


func _label(parent: Control, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	parent.add_child(label)
	return label
