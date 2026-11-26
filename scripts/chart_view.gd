class_name ChartView
extends Control
## Draws the chart: blank paper, the coast surveyed so far, the ship's track.
## North is up. Reads from a Charting node and never changes it.

const WORLD_EXTENT := 1300.0  ## the chart covers +/- this many metres

const PAPER := Color(0.91, 0.85, 0.70, 0.95)
const INK := Color(0.16, 0.11, 0.07)
const FAINT := Color(0.16, 0.11, 0.07, 0.15)
const TRACK := Color(0.50, 0.20, 0.12, 0.7)

var charting: Charting
var ship: Ship
var wind: Wind
var dot_guesses: bool = false  ## draw guessed coast as dots, not a firm line
var centre := Vector2.ZERO  ## world (x, z) at the middle of the sheet


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _to_sheet(world: Vector2) -> Vector2:
	return size * 0.5 + (world - centre) * (size.x * 0.5 / WORLD_EXTENT)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	for i in range(1, 8):
		var f := size.x * i / 8.0
		draw_line(Vector2(f, 0.0), Vector2(f, size.y), FAINT, 1.0)
		draw_line(Vector2(0.0, f), Vector2(size.x, f), FAINT, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), INK, false, 2.0)

	if charting == null or ship == null:
		return

	if charting.track.size() >= 2:
		var pts := PackedVector2Array()
		for p in charting.track:
			pts.append(_to_sheet(p))
		draw_polyline(pts, TRACK, 1.0)

	var coast := charting.island.coast
	var n := coast.size()
	for i in n:
		var j := (i + 1) % n
		if dot_guesses and (charting.guessed[i] == 1 or charting.guessed[j] == 1):
			if i % 2 == 0:
				draw_circle(_to_sheet(coast[i]), 1.3, TRACK)
		elif charting.seen[i] == 1 and charting.seen[j] == 1:
			draw_line(_to_sheet(coast[i]), _to_sheet(coast[j]), INK, 2.0)

	# The ship: a small arrowhead pointing along her heading.
	var at := _to_sheet(Vector2(ship.position.x, ship.position.z))
	var fwd := Compass.to_vector(ship.heading_deg)
	var side := Vector2(-fwd.y, fwd.x)
	draw_colored_polygon(PackedVector2Array([
		at + fwd * 9.0, at - fwd * 5.0 + side * 5.0, at - fwd * 5.0 - side * 5.0,
	]), INK)

	# Wind arrow in the top-left corner, pointing the way the wind blows.
	if wind != null:
		var origin := Vector2(34.0, 34.0)
		var blow := -Compass.to_vector(wind.from_deg)
		var cross := Vector2(-blow.y, blow.x)
		var tip := origin + blow * 18.0
		draw_line(origin - blow * 18.0, tip, TRACK, 2.0)
		draw_line(tip, tip - blow * 8.0 + cross * 5.0, TRACK, 2.0)
		draw_line(tip, tip - blow * 8.0 - cross * 5.0, TRACK, 2.0)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(size.x * 0.5 - 4.0, 16.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, INK)
	var caption := "Coast surveyed: %d%%" % roundi(charting.fraction() * 100.0)
	if charting.complete:
		caption = "Survey complete"
	draw_string(font, Vector2(10.0, size.y - 10.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, INK)
