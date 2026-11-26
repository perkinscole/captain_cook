class_name Seabed
extends Node
## How deep the water is. The bottom shelves away from the island's shore,
## and a ring of coral reefs rises close to the surface offshore. Nothing
## here is shown to the player directly: they find it with the lead line.

const SHIP_DRAUGHT := 4.0   ## metres of water she needs to float
const SHELF_SLOPE := 0.12   ## metres deeper per metre from the beach
const MAX_DEPTH := 60.0
const REEF_COUNT := 7

var island: Island
var reefs: Array[Vector3] = []   ## each reef as (x, z, radius)
var _tops: Array[float] = []     ## depth of water over the middle of each reef


func build(reef_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = reef_seed
	reefs.clear()
	_tops.clear()
	for k in REEF_COUNT:
		var angle := TAU * k / REEF_COUNT + rng.randf_range(-0.3, 0.3)
		var off_shore := rng.randf_range(110.0, 260.0)
		var reach := island.coast_radius(angle) + off_shore
		reefs.append(Vector3(
				island.position.x + cos(angle) * reach,
				island.position.z + sin(angle) * reach,
				rng.randf_range(45.0, 80.0)))
		_tops.append(rng.randf_range(1.0, 2.5))


## Removes any reef that would foul a stretch of water, e.g. an anchorage.
func clear_around(p: Vector2, radius: float) -> void:
	for i in range(reefs.size() - 1, -1, -1):
		var reef := reefs[i]
		if p.distance_to(Vector2(reef.x, reef.y)) < radius + reef.z:
			reefs.remove_at(i)
			_tops.remove_at(i)


## Depth of water in metres at a world (x, z) position. 0 on dry land.
func depth_at(p: Vector2) -> float:
	var offset := p - Vector2(island.position.x, island.position.z)
	var from_shore := offset.length() - island.coast_radius(offset.angle())
	var depth := clampf(from_shore * SHELF_SLOPE, 0.0, MAX_DEPTH)
	for i in reefs.size():
		var reef := reefs[i]
		var d := p.distance_to(Vector2(reef.x, reef.y))
		if d < reef.z:
			var t := d / reef.z
			depth = minf(depth, lerpf(_tops[i], depth, t * t))
	return depth


## Unit vector pointing toward deeper water from a position.
func deeper_direction(p: Vector2) -> Vector2:
	var step := 25.0
	var gradient := Vector2(
			depth_at(p + Vector2(step, 0.0)) - depth_at(p - Vector2(step, 0.0)),
			depth_at(p + Vector2(0.0, step)) - depth_at(p - Vector2(0.0, step)))
	if gradient.length() < 0.001:
		return (p - Vector2(island.position.x, island.position.z)).normalized()
	return gradient.normalized()
