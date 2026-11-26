class_name Player
extends Node
## You, walking the ship. Position is kept in the ship's own space, so you
## are carried along and rocked with her. There is no physics here: the
## ship's plan (ShipLayout) says where there is deck to stand on.

signal footfall

const WALK_SPEED := 2.3
const RUN_SPEED := 4.2
const EYE_HEIGHT := 1.65
const STOOPED := 1.5   ## below decks, where the beams are low
const STRIDE := 0.75   ## metres between footfalls

var camera: DeckCamera
var feet := Vector3(0.0, ShipLayout.QUARTERDECK_Y, 11.2)  ## where you stand, ship's space
var can_move: bool = true
var people: Array[Vector3] = []   ## where others stand, so you do not walk through them
var walked: float = 0.0           ## metres walked in all

var _stride: float = 0.0
var _bob: float = 0.0
var _eye: float = EYE_HEIGHT


func _physics_process(delta: float) -> void:
	var moving := false
	if can_move:
		var ahead := 0.0
		var across := 0.0
		if Input.is_physical_key_pressed(KEY_W):
			ahead += 1.0
		if Input.is_physical_key_pressed(KEY_S):
			ahead -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			across += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			across -= 1.0
		if ahead != 0.0 or across != 0.0:
			var yaw := camera.yaw()
			var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var right := Vector3(cos(yaw), 0.0, -sin(yaw))
			var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
			var step := (forward * ahead + right * across).normalized() * speed * delta
			# Try the whole step, then sliding along whatever is in the way.
			moving = _try(step) or _try(Vector3(step.x, 0.0, 0.0)) or _try(Vector3(0.0, 0.0, step.z))

	if moving:
		_stride += WALK_SPEED * delta
		if _stride >= STRIDE:
			_stride = 0.0
			footfall.emit()
	_bob = lerpf(_bob, 0.035 * sin(_stride / STRIDE * PI) if moving else 0.0, 0.3)
	_eye = lerpf(_eye, STOOPED if ShipLayout.is_below(feet) else EYE_HEIGHT, 0.1)
	camera.position = feet + Vector3(0.0, _eye + _bob, 0.0)


## Puts you somewhere at once, e.g. when you are called to the quarterdeck.
func place(spot: Vector3) -> void:
	feet = spot
	camera.position = feet + Vector3(0.0, EYE_HEIGHT, 0.0)


func _try(step: Vector3) -> bool:
	if step.length() < 0.0001:
		return false
	var to := feet + step
	var level := ShipLayout.floor_at(to.x, to.z, feet.y)
	if is_nan(level):
		return false
	to.y = level
	if ShipLayout.is_blocked(feet, to, people):
		return false
	walked += Vector2(step.x, step.z).length()
	feet = to
	return true
