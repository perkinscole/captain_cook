class_name Charting
extends Node
## The survey itself: which stretches of coast have been seen from the ship,
## where the ship has been, and how well each landmark has been fixed.
## Knows nothing about how the chart is drawn.
##
## A running survey works like this. Coast you sail past is sketched in by
## eye, which is quick but puts it in slightly the wrong place. To pin it
## down you take compass bearings on a landmark from two different places:
## where the two lines cross is where the landmark really is. The closer the
## lines are to crossing at a right angle (a good "cut"), the better the fix.

signal completed

const CLEAR_SIGHT_RANGE := 450.0  ## metres at which a coast can be sketched on a clear day
const CLEAR_BEARING_RANGE := 750.0  ## landmarks stand tall and can be seen further off
const DONE_FRACTION := 0.95
const CHECK_INTERVAL := 0.25
const UNFIXED_ERROR := 45.0  ## metres a landmark sketched by eye may be out
const BEST_ERROR := 4.0      ## metres, with a perfect right-angle cut
const MIN_CUT_DEG := 25.0    ## bearings crossing at less than this are no fix

var ship: Ship
var island: Island

var seen := PackedByteArray()        ## one flag per island.coast point
var seen_count: int = 0
var guessed := PackedByteArray()     ## points never seen, joined up by guess at the end
var track := PackedVector2Array()    ## ship's path as world (x, z)
var complete: bool = false
var visibility: float = 1.0          ## 1 = clear; thick weather shortens every range

## Per landmark: where the ship was each time a bearing was taken on it.
var bearings: Array[PackedVector2Array] = []
## Per landmark: how many metres out it is plotted on the chart.
var mark_error := PackedFloat32Array()

var _mark_dir := PackedVector2Array()  # which way each landmark's error lies
var _timer: float = 0.0


func start() -> void:
	seen.resize(island.coast.size())
	seen.fill(0)
	guessed.resize(island.coast.size())
	guessed.fill(0)
	seen_count = 0
	track.clear()
	complete = false

	var rng := RandomNumberGenerator.new()
	rng.seed = 1771
	bearings.clear()
	mark_error.resize(island.landmarks.size())
	_mark_dir.resize(island.landmarks.size())
	for k in island.landmarks.size():
		bearings.append(PackedVector2Array())
		mark_error[k] = UNFIXED_ERROR
		_mark_dir[k] = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))


func fraction() -> float:
	if seen.is_empty():
		return 0.0
	return float(seen_count) / seen.size()


func is_fixed(landmark: int) -> bool:
	return mark_error[landmark] < UNFIXED_ERROR


func fixed_count() -> int:
	var n := 0
	for k in mark_error.size():
		if is_fixed(k):
			n += 1
	return n


## 0 = every landmark laid down by eye, 1 = every one fixed with a perfect cut.
func accuracy() -> float:
	if mark_error.is_empty():
		return 0.0
	var total := 0.0
	for k in mark_error.size():
		total += 1.0 - (mark_error[k] - BEST_ERROR) / (UNFIXED_ERROR - BEST_ERROR)
	return total / mark_error.size()


## Can a bearing be taken on this landmark from where the ship is now?
func can_take_bearing(landmark: int) -> bool:
	var here := Vector2(ship.position.x, ship.position.z)
	var mark := island.landmarks[landmark]
	var centre := Vector2(island.position.x, island.position.z)
	var to_ship := here - mark
	return to_ship.length() <= CLEAR_BEARING_RANGE * visibility and to_ship.dot(mark - centre) > 0.0


## Records a bearing on a landmark and returns what to tell the player.
func take_bearing(landmark: int) -> String:
	var here := Vector2(ship.position.x, ship.position.z)
	var mark := island.landmarks[landmark]
	var mark_name := island.landmark_name(landmark)

	var taken := bearings[landmark]
	var best_cut := 0.0
	for from in taken:
		var cut := absf(rad_to_deg((mark - from).angle_to(mark - here)))
		best_cut = maxf(best_cut, minf(cut, 180.0 - cut))
	taken.append(here)
	bearings[landmark] = taken

	if taken.size() == 1:
		return "Bearing taken on %s. Take another from further along the coast." % mark_name
	if best_cut < MIN_CUT_DEG:
		return "%s: the lines cross at only %d°. Too fine a cut. Sail further on and try again." % [
			mark_name, roundi(best_cut)]
	var error := BEST_ERROR + 30.0 * (1.0 - sin(deg_to_rad(best_cut)))
	if error >= mark_error[landmark]:
		return "%s: no better than the fix you have." % mark_name
	mark_error[landmark] = error
	var quality := "A fine cut" if best_cut >= 60.0 else "A fair cut"
	return "%s fixed. %s: the lines cross at %d°." % [mark_name, quality, roundi(best_cut)]


## Where a landmark is drawn on the chart: its true place plus its error.
func plotted_landmark(landmark: int) -> Vector2:
	return island.landmarks[landmark] + _mark_dir[landmark] * mark_error[landmark]


## Where a coast point is drawn: pulled out of place by the errors of the
## landmarks on either side of it.
func plotted_coast(i: int) -> Vector2:
	var k0 := i / Island.LANDMARK_EVERY
	var k1 := (k0 + 1) % island.landmarks.size()
	var t := float(i % Island.LANDMARK_EVERY) / Island.LANDMARK_EVERY
	var shift := (_mark_dir[k0] * mark_error[k0]).lerp(_mark_dir[k1] * mark_error[k1], t)
	return island.coast[i] + shift


## Is the stretch of coast at point i pinned between two fixed landmarks?
func coast_is_fixed(i: int) -> bool:
	var k0 := i / Island.LANDMARK_EVERY
	return is_fixed(k0) and is_fixed((k0 + 1) % island.landmarks.size())


## For testing: marks nearly all the coast as sketched, so that the survey
## completes at the next check.
func debug_sketch_all() -> void:
	seen_count = 0
	for i in seen.size():
		seen[i] = 0 if i % 30 == 7 else 1
		seen_count += seen[i]


func _physics_process(delta: float) -> void:
	if ship == null or island == null or seen.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL

	var here := Vector2(ship.position.x, ship.position.z)
	if track.is_empty() or track[track.size() - 1].distance_to(here) > 15.0:
		track.append(here)

	var centre := Vector2(island.position.x, island.position.z)
	var sight_range := CLEAR_SIGHT_RANGE * visibility
	for i in seen.size():
		if seen[i] == 1:
			continue
		var p := island.coast[i]
		var to_ship := here - p
		# In range, and on the side of the island that faces the ship.
		if to_ship.length() <= sight_range and to_ship.dot(p - centre) > 0.0:
			seen[i] = 1
			seen_count += 1

	if not complete and fraction() >= DONE_FRACTION:
		# The last few gaps are joined up in the fair copy. Remember which.
		for i in seen.size():
			if seen[i] == 0:
				guessed[i] = 1
		seen.fill(1)
		seen_count = seen.size()
		complete = true
		completed.emit()
