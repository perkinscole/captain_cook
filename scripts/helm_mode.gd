class_name HelmMode
extends ControlMode
## You hold the wheel. Let go and it comes back amidships.


func mode_name() -> String:
	return "At the wheel"


func help() -> String:
	return "A / D  hold to put the wheel over to port / starboard"


func status(ship: Ship) -> String:
	var text := "Wheel amidships"
	if absf(ship.rudder) >= 0.05:
		var side := "starboard" if ship.rudder > 0.0 else "port"
		text = "Wheel %d%% to %s" % [roundi(absf(ship.rudder) * 100.0), side]
	if ship.has_sternway():
		text += "   (going astern: the wheel works backwards)"
	return text


func steer(ship: Ship, delta: float) -> void:
	var wanted := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		wanted -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		wanted += 1.0
	ship.rudder = move_toward(ship.rudder, wanted, 1.5 * delta)
