class_name UiTheme
extends RefCounted
## The look of the interface: an eighteenth-century typeface on paper, with
## brown ink. Everything on screen takes its fonts and panels from here.
##
## The typeface is IM Fell English, a digital revival of type cut in the
## 1600s and used by English printers in Cook's day. See fonts/OFL.txt.

const FONT := preload("res://fonts/IMFellEnglish-Regular.ttf")
const ITALIC := preload("res://fonts/IMFellEnglish-Italic.ttf")

const PAPER := Color(0.91, 0.85, 0.70)
const INK := Color(0.16, 0.11, 0.07)
const FADED := Color(0.16, 0.11, 0.07, 0.6)
const RED := Color(0.58, 0.14, 0.09)
const GREEN := Color(0.25, 0.42, 0.20)
const BRASS := Color(0.72, 0.56, 0.24)
const NIGHT := Color(0.06, 0.05, 0.04, 0.88)
const CREAM := Color(0.96, 0.93, 0.84)


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 19

	theme.set_color("font_color", "Label", INK)
	theme.set_stylebox("panel", "PanelContainer", paper_box())

	theme.set_stylebox("normal", "Button", _button_box(PAPER.darkened(0.08)))
	theme.set_stylebox("hover", "Button", _button_box(PAPER.lightened(0.25)))
	theme.set_stylebox("pressed", "Button", _button_box(BRASS))
	theme.set_stylebox("focus", "Button", _button_box(PAPER.lightened(0.25)))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_font_size("font_size", "Button", 24)

	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(0.16, 0.11, 0.07, 0.25)
	trough.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GREEN
	fill.set_corner_radius_all(3)
	theme.set_stylebox("background", "ProgressBar", trough)
	theme.set_stylebox("fill", "ProgressBar", fill)
	return theme


## A sheet of paper with an inked edge.
static func paper_box(alpha: float = 0.94) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, alpha)
	box.border_color = INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(14.0)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	box.shadow_size = 6
	return box


## A dark panel for words spoken over the picture.
static func night_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = NIGHT
	box.border_color = BRASS
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(18.0)
	return box


static func _button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.content_margin_left = 26.0
	box.content_margin_right = 26.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box
