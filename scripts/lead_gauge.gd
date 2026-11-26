class_name LeadGauge
extends Control
## Shows the swing of the lead so the player can time the release.

const BAR := Vector2(180.0, 12.0)

var lead: LeadLine


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR.x, 40.0)
	size = custom_minimum_size


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if lead == null:
		return
	var font := get_theme_default_font()
	var ready_now := lead.busy <= 0.0
	var ink := Color(0.96, 0.93, 0.84, 1.0 if ready_now else 0.4)
	var text := "Space  heave the lead" if ready_now else "Hauling in the line..."
	draw_string(font, Vector2(0.0, 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, ink)

	var top := 22.0
	draw_rect(Rect2(0.0, top, BAR.x, BAR.y), Color(0.0, 0.0, 0.0, 0.5))
	# The sweet spot: the top of the forward swing.
	draw_rect(Rect2(BAR.x * 0.9, top, BAR.x * 0.1, BAR.y), Color(0.45, 0.75, 0.40, 0.9))
	draw_rect(Rect2(0.0, top, BAR.x, BAR.y), ink, false, 1.0)
	if ready_now:
		var x := BAR.x * (lead.swing * 0.5 + 0.5)
		draw_rect(Rect2(x - 3.0, top - 3.0, 6.0, BAR.y + 6.0), ink)
