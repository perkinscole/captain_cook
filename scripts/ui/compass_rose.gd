class_name CompassRose
extends Control
## A steering compass. The card turns so that the ship's heading is always
## at the top. It also shows the things a helmsman carries in his head:
##   - the blue arrow is the wind, pointing the way it blows;
##   - the red wedge is the part of the compass she cannot sail into;
##   - the brass pointer on the rim is the course that has been ordered.

const POINTS: Array[String] = ["N", "E", "S", "W"]

var ship: Ship
var wind: Wind
var control: OrdersMode


func _ready() -> void:
	custom_minimum_size = Vector2(176.0, 176.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if ship == null or wind == null:
		return
	var font := get_theme_default_font()
	var mid := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0

	draw_circle(mid, radius, Color(0.20, 0.14, 0.09))
	draw_circle(mid, radius - 7.0, UiTheme.PAPER)

	# The wedge she cannot sail into, either side of where the wind comes from.
	var wind_at := deg_to_rad(wind.from_deg - ship.heading_deg)
	var wedge := PackedVector2Array([mid])
	for i in 13:
		var a := wind_at + deg_to_rad(lerpf(-Ship.NO_GO_DEG, Ship.NO_GO_DEG, i / 12.0))
		wedge.append(mid + _dir(a) * (radius - 8.0))
	draw_colored_polygon(wedge, Color(UiTheme.RED.r, UiTheme.RED.g, UiTheme.RED.b, 0.28))

	# The card: 32 points, with the four cardinals lettered.
	var turn := -deg_to_rad(ship.heading_deg)
	for i in 32:
		var a := turn + TAU * i / 32.0
		var length := 14.0 if i % 8 == 0 else (9.0 if i % 4 == 0 else 5.0)
		draw_line(mid + _dir(a) * (radius - 8.0), mid + _dir(a) * (radius - 8.0 - length),
				UiTheme.INK, 2.0 if i % 8 == 0 else 1.0)
	for i in 4:
		var a := turn + TAU * i / 4.0
		var at := mid + _dir(a) * (radius - 34.0)
		var colour := UiTheme.RED if i == 0 else UiTheme.INK
		draw_string(font, at + Vector2(-7.0, 8.0), POINTS[i], HORIZONTAL_ALIGNMENT_CENTER,
				14.0, 22, colour)

	# The wind: an arrow flying across the card the way the wind blows.
	var blow := -_dir(wind_at)
	var cross := Vector2(-blow.y, blow.x)
	var blue := Color(0.16, 0.30, 0.46)
	var tail := mid - blow * (radius - 24.0)
	var tip := mid - blow * (radius - 62.0)
	draw_line(tail, tip, blue, 3.0)
	draw_colored_polygon(PackedVector2Array([
		tip + blow * 12.0, tip + cross * 7.0, tip - cross * 7.0]), blue)

	# The course ordered, and the lubber line: the ship's own head.
	if control != null:
		var want := deg_to_rad(control.ordered_deg - ship.heading_deg)
		var rim := mid + _dir(want) * (radius - 3.0)
		var side := Vector2(-_dir(want).y, _dir(want).x)
		draw_colored_polygon(PackedVector2Array([
			rim - _dir(want) * 13.0, rim + side * 7.0, rim - side * 7.0]), UiTheme.BRASS)
	draw_line(mid + Vector2(0.0, -radius), mid + Vector2(0.0, -radius + 20.0), UiTheme.INK, 3.0)

	var heading := "%03d°" % (roundi(ship.heading_deg) % 360)
	draw_string(font, mid + Vector2(-30.0, 8.0), heading, HORIZONTAL_ALIGNMENT_CENTER,
			60.0, 22, UiTheme.INK)


## Unit vector for an angle measured clockwise from the top of the card.
func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))
