class_name LeadGauge
extends Control
## Shows the swing of the lead so the player can time the release. It only
## appears while the leadsman is swinging or hauling in.

const BAR := Vector2(220.0, 14.0)

var lead: LeadLine


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR.x, 44.0)
	size = custom_minimum_size


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if lead == null or lead.state == LeadLine.State.IDLE:
		return
	var font := get_theme_default_font()
	var swinging := lead.state == LeadLine.State.SWINGING
	var ink := UiTheme.CREAM
	var text := "Space   let go in the green!" if swinging else "Hauling in the line..."
	draw_string_outline(font, Vector2(0.0, 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, 6,
			Color(0.0, 0.0, 0.0))
	draw_string(font, Vector2(0.0, 16.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, ink)
	if not swinging:
		return

	var top := 26.0
	draw_rect(Rect2(0.0, top, BAR.x, BAR.y), Color(0.0, 0.0, 0.0, 0.55))
	# The sweet spot: the top of the forward swing.
	draw_rect(Rect2(BAR.x * 0.9, top, BAR.x * 0.1, BAR.y), Color(0.45, 0.75, 0.40, 0.95))
	draw_rect(Rect2(0.0, top, BAR.x, BAR.y), ink, false, 1.0)
	var x := BAR.x * (lead.swing * 0.5 + 0.5)
	draw_rect(Rect2(x - 3.0, top - 4.0, 6.0, BAR.y + 8.0), ink)
