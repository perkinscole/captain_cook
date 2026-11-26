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


## Turns a little way toward a point given in the ship's space. Call every
## frame to bring the view gently round to someone who is speaking.
func ease_toward(target: Vector3, weight: float) -> void:
	var d := target - position
	_yaw = lerp_angle(_yaw, atan2(-d.x, -d.z), weight)
	_pitch = lerp_angle(_pitch, atan2(d.y, Vector2(d.x, d.z).length()), weight)
	rotation = Vector3(_pitch, _yaw, 0.0)


## The yaw someone standing at `from` (ship's space) needs to face the camera.
func yaw_to_face_me(from: Vector3) -> float:
	var d := position - from
	return atan2(-d.x, -d.z)
