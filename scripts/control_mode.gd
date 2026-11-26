class_name ControlMode
extends Node
## Base class for a way of steering the ship. The game uses OrdersMode
## (you call a course, the helmsman steers). The first prototype also tried
## holding the wheel directly; giving orders was chosen.
## A mode only ever sets ship.rudder, so another can be swapped in.


func mode_name() -> String:
	return ""


func help() -> String:
	return ""


## Shown on the HUD next to the heading.
func status(_ship: Ship) -> String:
	return ""


func activate(_ship: Ship) -> void:
	pass


## One-shot key presses (physical keycodes). Return true if the key was used.
func handle_key(_ship: Ship, _keycode: Key) -> bool:
	return false


## Called every physics frame while this mode is active.
func steer(_ship: Ship, _delta: float) -> void:
	pass
