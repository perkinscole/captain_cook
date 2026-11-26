class_name ChartView
extends Control
## Draws the chart: blank paper, the coast surveyed so far, landmarks and
## bearings, soundings, and the ship's track. North is up. Reads from the
## survey and never changes it.
##
## Coast sketched by eye is drawn in pencil. It turns to ink once the
## landmarks at both ends of it are fixed.

const WORLD_EXTENT := 1300.0  ## the chart covers +/- this many metres

const PAPER := Color(0.91, 0.85, 0.70, 0.95)
const INK := Color(0.16, 0.11, 0.07)
const PENCIL := Color(0.16, 0.11, 0.07, 0.45)
const FAINT := Color(0.16, 0.11, 0.07, 0.15)
const TRACK := Color(0.50, 0.20, 0.12, 0.7)
const SHOAL := Color(0.65, 0.15, 0.10)

var charting: Charting
var lead: LeadLine
var ship: Ship
var wind: Wind
var dot_guesses: bool = false  ## draw guessed coast as dots, not a firm line
var detailed: bool = false     ## the chart-table view: names and sounding figures
var anchorage := Vector2.ZERO  ## world (x, z) of a known anchorage, if any
var anchorage_name: String = ""
var centre := Vector2.ZERO     ## world (x, z) at the middle of the sheet


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _to_sheet(world: Vector2) -> Vector2:
	return size * 0.5 + (world - centre) * (size.x * 0.5 / WORLD_EXTENT)


func _draw() -> void:
	var font := get_theme_default_font()
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

	_draw_coast()
	_draw_landmarks(font)
	_draw_soundings(font)
	if anchorage_name != "":
		# The usual chart sign for an anchorage is a small anchor; a ringed
		# cross stands in for it here.
		var mark := _to_sheet(anchorage)
		draw_arc(mark, 5.0, 0.0, TAU, 16, TRACK, 1.5)
		draw_line(mark - Vector2(0.0, 5.0), mark + Vector2(0.0, 5.0), TRACK, 1.5)
		draw_line(mark - Vector2(5.0, 0.0), mark + Vector2(5.0, 0.0), TRACK, 1.5)
		draw_string(font, mark + Vector2(8.0, 4.0), anchorage_name,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TRACK)

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

	draw_string(font, Vector2(size.x * 0.5 - 4.0, 16.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, INK)
	var caption := "Coast sketched: %d%%" % roundi(charting.fraction() * 100.0)
	if charting.complete:
		caption = "Survey complete"
	caption += "    Fixed: %d of %d    Accuracy: %d%%" % [
		charting.fixed_count(), charting.mark_error.size(), roundi(charting.accuracy() * 100.0)]
	draw_string(font, Vector2(10.0, size.y - 10.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, INK)
	if detailed:
		draw_string(font, Vector2(10.0, size.y - 28.0),
				"Pencil: sketched by eye.  Ink: fixed by bearings.  Figures: depth in fathoms.",
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, PENCIL)


func _draw_coast() -> void:
	var n := charting.island.coast.size()
	for i in n:
		var j := (i + 1) % n
		if dot_guesses and (charting.guessed[i] == 1 or charting.guessed[j] == 1):
			if i % 2 == 0:
				draw_circle(_to_sheet(charting.plotted_coast(i)), 1.3, TRACK)
		elif charting.seen[i] == 1 and charting.seen[j] == 1:
			var from := _to_sheet(charting.plotted_coast(i))
			var to := _to_sheet(charting.plotted_coast(j))
			if charting.coast_is_fixed(i):
				draw_line(from, to, INK, 2.0)
			else:
				draw_line(from, to, PENCIL, 1.0)


func _draw_landmarks(font: Font) -> void:
	for k in charting.bearings.size():
		var taken := charting.bearings[k]
		if taken.is_empty():
			continue
		var mark := _to_sheet(charting.plotted_landmark(k))
		for from in taken:
			draw_line(_to_sheet(from), mark, FAINT, 1.0)
		if charting.is_fixed(k):
			draw_circle(mark, 3.5, INK)
		else:
			draw_arc(mark, 3.5, 0.0, TAU, 12, INK, 1.0)
		if detailed:
			draw_string(font, mark + Vector2(6.0, -4.0), charting.island.landmark_name(k),
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, INK)


func _draw_soundings(font: Font) -> void:
	if lead == null:
		return
	for s: Dictionary in lead.soundings:
		var at := _to_sheet(s["pos"])
		var fathoms: int = s["fathoms"]
		var ink := SHOAL if fathoms >= 0 and fathoms <= 3 else INK
		if not detailed:
			draw_circle(at, 1.5, ink)
		elif fathoms < 0:
			draw_string(font, at + Vector2(-4.0, 4.0), "-", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PENCIL)
		else:
			var figure := str(fathoms) if s["good"] else str(fathoms) + "?"
			draw_string(font, at + Vector2(-4.0, 4.0), figure, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, ink)
