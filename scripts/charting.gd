class_name Charting
extends Node
## The survey itself: which stretches of coast have been seen from the ship,
## and where the ship has been. Knows nothing about how the chart is drawn.

signal completed

const CLEAR_SIGHT_RANGE := 450.0  ## metres at which a coast can be fixed on a clear day
const DONE_FRACTION := 0.98
const CHECK_INTERVAL := 0.25

var ship: Ship
var island: Island

var seen := PackedByteArray()        ## one flag per island.coast point
var seen_count: int = 0
var track := PackedVector2Array()    ## ship's path as world (x, z)
var complete: bool = false
var sight_range: float = CLEAR_SIGHT_RANGE  ## shorter in thick weather

var _timer: float = 0.0


func start() -> void:
	seen.resize(island.coast.size())
	seen.fill(0)
	seen_count = 0
	track.clear()
	complete = false


func fraction() -> float:
	if seen.is_empty():
		return 0.0
	return float(seen_count) / seen.size()


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
		seen.fill(1)  # the last few gaps are joined up in the fair copy
		seen_count = seen.size()
		complete = true
		completed.emit()
