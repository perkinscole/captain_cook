class_name ControlMode
extends Node
## Base class for a way of steering the ship. The prototype compares two:
## giving orders (OrdersMode) and taking the wheel yourself (HelmMode).
## A mode only ever sets ship.rudder, so modes can be swapped freely.


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
