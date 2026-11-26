class_name Ship
extends Node3D
## Ship movement only. It knows the wind and is told a rudder angle and a
## sail setting; it does not know who is steering (see ControlMode).
##
## Compass convention used everywhere: 0 = north = -Z, 90 = east = +X.

const MAX_SAIL := 3
const SAIL_NAMES: Array[String] = ["Bare poles", "Topsails", "Plain sail", "All sail"]

var wind: Wind
var heading_deg: float = 0.0
var speed: float = 0.0      ## metres per second through the water
var sail: int = 1           ## 0..MAX_SAIL
var rudder: float = 0.0     ## -1 (hard a-port) .. +1 (hard a-starboard)

var _time: float = 0.0
var _roll: float = 0.0


## How much of the wind a square-rigger can use at a given angle off the wind
## (0 = bow pointing straight into it, 180 = wind dead astern).
static func polar(angle_off_wind: float) -> float:
	if angle_off_wind < 50.0:
		return 0.0  # in irons: she will not sail this close
	if angle_off_wind < 70.0:
		return remap(angle_off_wind, 50.0, 70.0, 0.0, 0.6)
	if angle_off_wind < 120.0:
		return remap(angle_off_wind, 70.0, 120.0, 0.6, 1.0)
	if angle_off_wind <= 150.0:
		return 1.0
	return remap(angle_off_wind, 150.0, 180.0, 1.0, 0.85)


## Wind direction relative to the bow: positive = from starboard, -180..180.
func relative_wind_deg() -> float:
	return wrapf(wind.from_deg - heading_deg, -180.0, 180.0)


func angle_off_wind() -> float:
	return absf(relative_wind_deg())


func forward() -> Vector3:
	var h := deg_to_rad(heading_deg)
	return Vector3(sin(h), 0.0, -cos(h))


func set_sail(level: int) -> void:
	sail = clampi(level, 0, MAX_SAIL)


func _physics_process(delta: float) -> void:
	_time += delta

	var target := wind.strength * polar(angle_off_wind()) * (float(sail) / MAX_SAIL) * 1.3
	var accel := 0.8 if target > speed else 1.2
	speed = move_toward(speed, target, accel * delta)

	# The rudder needs water moving past it, but keep a little turn at rest so
	# the player can always get out of irons.
	var turn_rate := rudder * (5.0 + 2.0 * speed)  # degrees per second
	heading_deg = wrapf(heading_deg + turn_rate * delta, 0.0, 360.0)

	var pos := position + forward() * speed * delta
	pos.y = 0.25 * sin(_time * 0.9)

	var heel := 0.0
	if sail > 0:
		heel = signf(relative_wind_deg()) * sin(deg_to_rad(angle_off_wind())) \
				* wind.strength * 0.006 * (float(sail) / MAX_SAIL)
	_roll = lerpf(_roll, heel + 0.012 * sin(_time * 0.7), 1.0 - exp(-2.0 * delta))

	position = pos
	rotation = Vector3(0.012 * sin(_time * 1.1), -deg_to_rad(heading_deg), _roll)


## Called when the keel touches. Stops her dead and puts her back in safe water.
func run_aground(safe_position: Vector3) -> void:
	speed = 0.0
	position.x = safe_position.x
	position.z = safe_position.z
