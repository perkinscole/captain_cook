class_name Spyglass
extends Control
## The view through a spyglass: a round window on the world, with the
## landmarks that are near enough to take a bearing on picked out by name.
## It only draws; the game decides when it is raised and what is aimed at.

var camera: Camera3D
var island: Island
var charting: Charting
var raised: bool = false
var aimed: int = -1       ## the landmark under the cross-hairs, or -1

var _open: float = 0.0    # 0 = lowered, 1 = at the eye


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_open = move_toward(_open, 1.0 if raised else 0.0, delta * 5.0)
	visible = _open > 0.01
	queue_redraw()


func _draw() -> void:
	var mid := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var far := size.length()
	var dark := Color(0.0, 0.0, 0.0, _open)

	# Everything outside the round window is blacked out, slice by slice.
	var slices := 64
	for i in slices:
		var a := Vector2.RIGHT.rotated(TAU * i / slices)
		var b := Vector2.RIGHT.rotated(TAU * (i + 1) / slices)
		draw_colored_polygon(PackedVector2Array([
			mid + a * radius, mid + b * radius, mid + b * far, mid + a * far]), dark)
	draw_arc(mid, radius, 0.0, TAU, 96, Color(0.72, 0.56, 0.24, _open), 6.0)
	draw_arc(mid, radius - 6.0, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.5 * _open), 8.0)
	if _open < 0.9 or camera == null:
		return

	var hair := Color(0.05, 0.04, 0.03, 0.7)
	draw_line(mid - Vector2(radius * 0.25, 0.0), mid - Vector2(12.0, 0.0), hair, 1.5)
	draw_line(mid + Vector2(12.0, 0.0), mid + Vector2(radius * 0.25, 0.0), hair, 1.5)
	draw_line(mid - Vector2(0.0, radius * 0.25), mid - Vector2(0.0, 12.0), hair, 1.5)
	draw_line(mid + Vector2(0.0, 12.0), mid + Vector2(0.0, radius * 0.25), hair, 1.5)

	var font := get_theme_default_font()
	for k in island.landmarks.size():
		if not charting.can_take_bearing(k):
			continue
		var point := island.landmark_aim_point(k)
		if camera.is_position_behind(point):
			continue
		var at := camera.unproject_position(point)
		if at.distance_to(mid) > radius - 30.0:
			continue
		var chosen := k == aimed
		var ink := Color(1.0, 0.93, 0.70) if chosen else Color(1.0, 1.0, 1.0, 0.75)
		var box := 26.0 if chosen else 16.0
		draw_rect(Rect2(at - Vector2(box, box), Vector2(box, box) * 2.0), ink, false,
				2.5 if chosen else 1.0)
		var label := island.landmark_name(k)
		if charting.is_fixed(k):
			label += "  (fixed)"
		draw_string_outline(font, at + Vector2(box + 6.0, 6.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, 6, Color(0.0, 0.0, 0.0))
		draw_string(font, at + Vector2(box + 6.0, 6.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, ink)
