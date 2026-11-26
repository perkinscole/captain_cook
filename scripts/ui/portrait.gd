class_name Portrait
extends Control
## A small drawn portrait of one of the hands. The face shows how they are:
## the mouth and brows follow their spirits, and they turn pale and
## heavy-eyed as their health fails.

var hand: Hand


func _ready() -> void:
	custom_minimum_size = Vector2(150.0, 150.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if hand == null:
		return
	var ink := UiTheme.INK
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.78, 0.71, 0.56))

	var face_size := Vector2(33.0, 41.0) * (0.86 if hand.boy else 1.0)
	var mid := Vector2(size.x * 0.5, size.y * 0.5 - 6.0 + (8.0 if hand.boy else 0.0))
	var sickly := clampf((70.0 - hand.health) / 40.0, 0.0, 1.0)
	var skin := hand.skin.lerp(Color(0.76, 0.79, 0.64), sickly * 0.6)

	# Shoulders, neckerchief and neck.
	var base := mid.y + face_size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid.x - 62.0, size.y), Vector2(mid.x - 40.0, base + 4.0),
		Vector2(mid.x + 40.0, base + 4.0), Vector2(mid.x + 62.0, size.y)]), hand.jacket)
	draw_rect(Rect2(mid.x - 10.0, base - 12.0, 20.0, 22.0), skin.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([
		Vector2(mid.x - 17.0, base + 4.0), Vector2(mid.x + 17.0, base + 4.0),
		Vector2(mid.x, base + 30.0)]), hand.kerchief)

	# Head, hair, and a beard for those who wear one.
	draw_colored_polygon(_ellipse(mid, face_size, 0.0, TAU), skin)
	draw_colored_polygon(_ellipse(mid - Vector2(0.0, 5.0), face_size + Vector2(3.0, 3.0),
			PI * 1.12, PI * 1.88), hand.hair)
	if hand.beard:
		draw_colored_polygon(_ellipse(mid + Vector2(0.0, 8.0), face_size * Vector2(0.92, 0.86),
				PI * 0.08, PI * 0.92), hand.hair)

	# Eyes: bright when well, heavy-lidded when ill.
	var eye_y := mid.y - 5.0
	for side: float in [-1.0, 1.0]:
		var eye := Vector2(mid.x + side * 12.0, eye_y)
		if sickly > 0.6:
			draw_line(eye - Vector2(4.0, 0.0), eye + Vector2(4.0, 0.0), ink, 2.0)
		else:
			draw_circle(eye, 2.8, ink)
		# Brows: lifted when cheerful, drawn down toward the nose when sullen.
		var tilt := remap(clampf(hand.morale, 20.0, 80.0), 20.0, 80.0, 4.0, -2.0)
		draw_line(eye + Vector2(-side * 6.0, -8.0 + tilt), eye + Vector2(side * 6.0, -8.0 - tilt),
				ink, 2.0)

	# Mouth: a smile, a straight line, or a frown.
	var mouth := Vector2(mid.x, mid.y + 17.0)
	if hand.morale >= 75.0:
		draw_arc(mouth - Vector2(0.0, 7.0), 11.0, PI * 0.2, PI * 0.8, 10, ink, 2.0)
	elif hand.morale >= 50.0:
		draw_line(mouth - Vector2(8.0, 0.0), mouth + Vector2(8.0, 0.0), ink, 2.0)
	elif hand.morale >= 30.0:
		draw_arc(mouth + Vector2(0.0, 9.0), 11.0, PI * 1.28, PI * 1.72, 10, ink, 2.0)
	else:
		draw_arc(mouth + Vector2(0.0, 7.0), 11.0, PI * 1.15, PI * 1.85, 10, ink, 2.5)

	draw_rect(Rect2(Vector2.ZERO, size), ink, false, 2.0)


## Points round part of an ellipse, from one angle to another.
func _ellipse(mid: Vector2, radii: Vector2, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 25:
		var a := lerpf(from, to, i / 24.0)
		points.append(mid + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points
