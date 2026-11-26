class_name OrdersMode
extends ControlMode
## You call a course; the helmsman brings her round to it.
##
## He is a seaman, and will not put her head into the wind and stop her:
##   - If the course you order is too close to the wind for her to sail, he
##     steers as close to it as she will go ("full and by") and holds that.
##   - If the course lies on the other side of the wind, he tacks through
##     the wind when she has speed enough to carry her round, and otherwise
##     wears her round the long way, with the wind behind.

const POINT_DEG := 11.25  # one point of the compass
const FULL_AND_BY := Ship.NO_GO_DEG + 12.0 ## degrees off the wind he holds her when close-hauled
const TACK_SPEED := 2.8                    ## m/s she needs to carry her through the wind

var ordered_deg: float = 0.0
var helm_skill: float = 1.0  ## how quickly the helmsman answers, 0..1
var pinched: bool = false    ## the ordered course is too close to the wind to sail
var tacking: bool = false    ## he is taking her through the wind
var wearing: bool = false    ## he is taking her round the long way


func mode_name() -> String:
	return "Giving orders"


func help() -> String:
	return "Left / Right  order course one point to port / starboard"


func status(_ship: Ship) -> String:
	return "Course ordered: %03d° (%s)" % [roundi(ordered_deg) % 360, Compass.point_name(ordered_deg)]


func activate(ship: Ship) -> void:
	ordered_deg = wrapf(snappedf(ship.heading_deg, POINT_DEG), 0.0, 360.0)


func handle_key(_ship: Ship, keycode: Key) -> bool:
	if keycode == KEY_LEFT:
		ordered_deg = wrapf(ordered_deg - POINT_DEG, 0.0, 360.0)
		return true
	if keycode == KEY_RIGHT:
		ordered_deg = wrapf(ordered_deg + POINT_DEG, 0.0, 360.0)
		return true
	return false


## Puts her about: orders the same close-hauled course on the other tack.
func go_about(ship: Ship) -> void:
	var side := signf(wrapf(ship.heading_deg - ship.wind.from_deg, -180.0, 180.0))
	if side == 0.0:
		side = 1.0
	ordered_deg = wrapf(ship.wind.from_deg - side * (FULL_AND_BY + 3.0), 0.0, 360.0)


func steer(ship: Ship, delta: float) -> void:
	var wind_from := ship.wind.from_deg
	# Her head, and the course ordered, each measured from the wind's eye.
	var head_off := wrapf(ship.heading_deg - wind_from, -180.0, 180.0)
	var want_off := wrapf(ordered_deg - wind_from, -180.0, 180.0)
	# Which side of the wind she is on. Dead head to wind, call it the side
	# the order lies on, so that she always has somewhere to fall off to.
	var head_side := signf(head_off) if absf(head_off) > 1.0 else signf(want_off)
	if head_side == 0.0:
		head_side = 1.0

	# Too close to the wind: hold her full and by on the tack she is on.
	pinched = absf(want_off) < FULL_AND_BY
	if pinched:
		want_off = head_side * FULL_AND_BY

	# Does the shortest way round to it pass through the wind's eye?
	var crosses := head_side != signf(want_off) and absf(head_off) + absf(want_off) < 180.0
	if not crosses:
		tacking = false
		wearing = false
	elif not tacking and not wearing:
		tacking = ship.speed >= TACK_SPEED
		wearing = not tacking
	elif tacking and ship.speed < 0.3 and absf(head_off) > 20.0:
		# She has missed stays: lost her way before coming round. Wear instead.
		tacking = false
		wearing = true

	var error := wrapf(wind_from + want_off - ship.heading_deg, -180.0, 180.0)
	var wanted := clampf(error / 12.0, -1.0, 1.0)
	if wearing:
		wanted = head_side   # turn away from the wind and keep turning
	if ship.has_sternway():
		wanted = -wanted  # the helmsman knows to reverse the wheel going astern
	ship.rudder = move_toward(ship.rudder, wanted * helm_skill, 2.0 * helm_skill * delta)
