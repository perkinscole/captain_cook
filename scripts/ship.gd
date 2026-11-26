class_name Ship
extends Node3D
## Ship movement only. It knows the wind and is told a rudder angle and a
## sail order; it does not know who is steering (see ControlMode).
##
## Compass convention used everywhere: 0 = north = -Z, 90 = east = +X.

signal sail_carried_away
signal sail_repaired

## How the sails are behaving right now.
enum Trim { FURLED, DRAWING, SHIVERING, ABACK }

const MAX_SAIL := 4
const SAIL_NAMES: Array[String] = [
	"Bare poles", "Reefed topsails", "Topsails", "Plain sail", "All sail",
]
## Share of the full sail area each order spreads.
const SAIL_AREA: Array[float] = [0.0, 0.3, 0.5, 0.78, 1.0]

const HULL_SPEED := 12.0        ## m/s she approaches but never reaches
const NO_GO_DEG := 50.0         ## closer to the wind than this, sails only shiver
const ABACK_DEG := 35.0         ## closer than this, the wind is on the wrong side of them
const SAFE_LOAD := 12.5         ## wind strength x canvas she can carry safely
const STRAIN_SECONDS := 8.0     ## how long she can be over-pressed before something goes
const REPAIR_SECONDS := 60.0

var wind: Wind
var heading_deg: float = 0.0
var speed: float = 0.0        ## m/s through the water; negative = sternway
var sail: int = 2             ## the sail ORDERED, 0..MAX_SAIL
var canvas: float = 0.5       ## sail area actually set, 0..1. Follows the order.
var sail_limit: int = MAX_SAIL  ## lowered while a blown-out sail is replaced
var rudder: float = 0.0       ## -1 (hard a-port) .. +1 (hard a-starboard)
var sea_state: float = 0.0    ## 0 = easy swell, 1 = steep sea. Motion only.
var leeway_deg: float = 0.0   ## how far her real track sags downwind of her heading
var strain: float = 0.0       ## seconds spent over-pressed
var hove_to: bool = false     ## lying stopped with a topsail backed, e.g. to talk

var _time: float = 0.0
var _roll: float = 0.0
var _repair_left: float = 0.0


## How much of the wind a square-rigger can use at a given angle off the wind
## (0 = bow pointing straight into it, 180 = wind dead astern).
static func polar(angle_off_wind: float) -> float:
	if angle_off_wind < NO_GO_DEG:
		return 0.0
	if angle_off_wind < 70.0:
		return remap(angle_off_wind, NO_GO_DEG, 70.0, 0.0, 0.6)
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


func trim() -> Trim:
	if canvas < 0.02:
		return Trim.FURLED
	var a := angle_off_wind()
	if a < ABACK_DEG:
		return Trim.ABACK
	if a < NO_GO_DEG:
		return Trim.SHIVERING
	return Trim.DRAWING


func has_sternway() -> bool:
	return speed < -0.2


func is_over_pressed() -> bool:
	return wind.strength * canvas > SAFE_LOAD


## Orders a sail setting. Returns false if she cannot carry it just now.
func set_sail(level: int) -> bool:
	var wanted := clampi(level, 0, MAX_SAIL)
	sail = mini(wanted, sail_limit)
	return sail == wanted


func _physics_process(delta: float) -> void:
	_time += delta
	var a := angle_off_wind()
	var rel := relative_wind_deg()

	# The hands take time to make or shorten sail. Taking it in is quicker.
	var wanted_canvas := SAIL_AREA[sail]
	var rate := 0.12 if wanted_canvas > canvas else 0.2
	canvas = move_toward(canvas, wanted_canvas, rate * delta)

	# Drive from the sails. Aback, the wind pushes her slowly astern.
	var push := HULL_SPEED * (1.0 - exp(-wind.strength * canvas * 1.3 / 8.0))
	var target := push * polar(a)
	if trim() == Trim.ABACK:
		target = -0.18 * push
	var accel := 1.0
	if target < speed:
		# She carries her way through the wind's eye, which is what makes
		# tacking possible. Otherwise she slows fairly quickly.
		accel = 0.45 if a < NO_GO_DEG and speed > 0.0 else 1.0
	if hove_to:
		target = 0.0
		accel = 1.5
	speed = move_toward(speed, target, accel * delta)

	# The rudder needs water moving past it, and works backwards with sternway.
	var steer_sign := -1.0 if has_sternway() else 1.0
	var turn_rate := rudder * steer_sign * minf(1.5 + 2.6 * absf(speed), 15.0)
	# Head to wind with sail set, her bow is pushed off the wind.
	if a < NO_GO_DEG and canvas > 0.02:
		turn_rate -= signf(rel) * 1.5 * canvas
	if hove_to:
		turn_rate = 0.0
	heading_deg = wrapf(heading_deg + turn_rate * delta, 0.0, 360.0)

	# Leeway: the wind shoves her sideways, most when close-hauled.
	var fwd2 := Compass.to_vector(heading_deg)
	var wind_to := -Compass.to_vector(wind.from_deg)
	var sideways := wind_to - fwd2 * wind_to.dot(fwd2)  # length = sin(a)
	var closeness := clampf((130.0 - a) / 80.0, 0.0, 1.0)
	var drift := sideways * 0.05 * wind.strength * (0.3 + canvas) * closeness
	if hove_to:
		drift = Vector2.ZERO
	leeway_deg = rad_to_deg(atan2(drift.length(), maxf(absf(speed), 0.5)))

	var pos := position
	pos.x += (fwd2.x * speed + drift.x) * delta
	pos.z += (fwd2.y * speed + drift.y) * delta
	pos.y = (0.25 + 0.6 * sea_state) * sin(_time * 0.9)

	_update_strain(delta)

	var heel := signf(rel) * sin(deg_to_rad(a)) * wind.strength * canvas * 0.012
	var wallow := (0.012 + 0.03 * sea_state) * sin(_time * 0.7)
	_roll = lerpf(_roll, heel + wallow, 1.0 - exp(-2.0 * delta))
	var pitch := (0.012 + 0.035 * sea_state) * sin(_time * 1.1)

	position = pos
	rotation = Vector3(pitch, -deg_to_rad(heading_deg), _roll)


func _update_strain(delta: float) -> void:
	if is_over_pressed() and not hove_to:
		strain += delta
		if strain >= STRAIN_SECONDS:
			strain = 0.0
			sail_limit = 2
			sail = mini(sail, sail_limit)
			canvas = minf(canvas, SAIL_AREA[sail_limit])
			_repair_left = REPAIR_SECONDS
			sail_carried_away.emit()
	else:
		strain = maxf(0.0, strain - 2.0 * delta)

	if _repair_left > 0.0:
		_repair_left -= delta
		if _repair_left <= 0.0:
			sail_limit = MAX_SAIL
			sail_repaired.emit()


## Called when the keel touches. Stops her dead and puts her back in safe water.
func run_aground(safe_position: Vector3) -> void:
	speed = 0.0
	position.x = safe_position.x
	position.z = safe_position.z
