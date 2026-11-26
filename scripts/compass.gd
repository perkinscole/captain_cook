class_name Compass
extends RefCounted
## Small helpers for compass bearings (0 = north = -Z, 90 = east = +X).

const POINTS: Array[String] = [
	"N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
	"S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
]


static func point_name(deg: float) -> String:
	return POINTS[roundi(wrapf(deg, 0.0, 360.0) / 22.5) % 16]


## Compass bearing (0..360) of a direction given as Vector2(x, z).
static func from_vector(v: Vector2) -> float:
	return wrapf(rad_to_deg(atan2(v.x, -v.y)), 0.0, 360.0)


## Unit vector on the XZ plane pointing along a bearing, as Vector2(x, z).
static func to_vector(deg: float) -> Vector2:
	var r := deg_to_rad(deg)
	return Vector2(sin(r), -cos(r))
