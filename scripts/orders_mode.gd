class_name OrdersMode
extends ControlMode
## You call a course; the helmsman brings her round to it.

const POINT_DEG := 11.25  # one point of the compass

var ordered_deg: float = 0.0
var helm_skill: float = 1.0  ## how quickly the helmsman answers, 0..1


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


func steer(ship: Ship, delta: float) -> void:
	var error := wrapf(ordered_deg - ship.heading_deg, -180.0, 180.0)
	var wanted := clampf(error / 12.0, -1.0, 1.0)
	if ship.has_sternway():
		wanted = -wanted  # the helmsman knows to reverse the wheel going astern
	ship.rudder = move_toward(ship.rudder, wanted * helm_skill, 2.0 * helm_skill * delta)
