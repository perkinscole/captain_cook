class_name DeckCamera
extends Camera3D
## First-person view from the quarterdeck. Mouse to look around.

const SENSITIVITY := 0.0025

var _yaw: float = 0.0
var _pitch: float = 0.0


func look(relative: Vector2) -> void:
	_yaw = wrapf(_yaw - relative.x * SENSITIVITY, -PI, PI)
	_pitch = clampf(_pitch - relative.y * SENSITIVITY, -1.2, 1.3)
	rotation = Vector3(_pitch, _yaw, 0.0)
