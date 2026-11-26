class_name Figure
extends Node3D
## A placeholder person made of boxes, for testing story told through poses
## rather than animation. It holds a named pose, eases between poses, and
## breathes a little so it does not look frozen. Faces -Z; origin at the feet.

## Rotations (radians) for each jointed part, plus whether the chart is in hand.
## For arms, +x swings the arm forward and up; z tucks it across the body.
const POSES := {
	"at_ease": {
		"torso": Vector3.ZERO, "head": Vector3.ZERO,
		"arm_l": Vector3(-0.4, 0.0, 0.25), "arm_r": Vector3(-0.4, 0.0, -0.25), "chart": false,
	},
	"regard": {
		"torso": Vector3.ZERO, "head": Vector3(0.05, 0.0, 0.0),
		"arm_l": Vector3(0.35, 0.0, 0.1), "arm_r": Vector3(-0.4, 0.0, -0.25), "chart": true,
	},
	"reading": {
		"torso": Vector3(-0.06, 0.0, 0.0), "head": Vector3(-0.5, 0.0, 0.0),
		"arm_l": Vector3(1.0, 0.0, 0.2), "arm_r": Vector3(1.0, 0.0, -0.2), "chart": true,
	},
	"pointing": {
		"torso": Vector3(-0.06, 0.0, 0.0), "head": Vector3(-0.4, 0.0, 0.0),
		"arm_l": Vector3(1.0, 0.0, 0.2), "arm_r": Vector3(1.25, 0.0, -0.45), "chart": true,
	},
	"offer": {
		"torso": Vector3.ZERO, "head": Vector3.ZERO,
		"arm_l": Vector3(1.3, 0.0, 0.0), "arm_r": Vector3(-0.4, 0.0, -0.25), "chart": true,
	},
}
const EYE_HEIGHT := 1.62

## Set these before adding the figure to the scene.
var coat_color := Color(0.09, 0.12, 0.25)
var legs_color := Color(0.85, 0.82, 0.72)
var skin_color := Color(0.80, 0.62, 0.50)
var wears_hat: bool = true
var idle_facing: float = 0.0  ## yaw (radians) when nobody is speaking to them

var facing: float = 0.0  ## yaw (radians) the figure turns toward

var _sway: Node3D
var _parts: Dictionary = {}
var _chart: MeshInstance3D
var _tween: Tween
var _time: float = 0.0


func _ready() -> void:
	var coat := _material(coat_color)
	var breeches := _material(legs_color)
	var skin := _material(skin_color)
	var black := _material(Color(0.05, 0.05, 0.06))
	var paper := _material(Color(0.91, 0.85, 0.70))

	_sway = Node3D.new()
	add_child(_sway)
	_box(_sway, Vector3(0.34, 0.85, 0.22), Vector3(0.0, 0.425, 0.0), breeches)

	var torso := _joint(_sway, "torso", Vector3(0.0, 0.85, 0.0))
	_box(torso, Vector3(0.46, 0.62, 0.26), Vector3(0.0, 0.33, 0.0), coat)
	_box(torso, Vector3(0.48, 0.34, 0.28), Vector3(0.0, -0.12, 0.0), coat)  # coat skirts

	var head := _joint(torso, "head", Vector3(0.0, 0.66, 0.0))
	var face := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.24
	face.mesh = ball
	face.material_override = skin
	face.position = Vector3(0.0, 0.12, 0.0)
	head.add_child(face)
	if wears_hat:
		_box(head, Vector3(0.44, 0.03, 0.40), Vector3(0.0, 0.23, 0.0), black)   # hat brim
		_box(head, Vector3(0.20, 0.09, 0.20), Vector3(0.0, 0.28, 0.0), black)   # hat crown

	var arm_l := _joint(torso, "arm_l", Vector3(-0.29, 0.58, 0.0))
	_box(arm_l, Vector3(0.11, 0.6, 0.11), Vector3(0.0, -0.3, 0.0), coat)
	var arm_r := _joint(torso, "arm_r", Vector3(0.29, 0.58, 0.0))
	_box(arm_r, Vector3(0.11, 0.6, 0.11), Vector3(0.0, -0.3, 0.0), coat)

	_chart = _box(arm_l, Vector3(0.36, 0.015, 0.28), Vector3(0.12, -0.62, -0.06), paper)
	set_pose("at_ease", 0.0)
	facing = idle_facing
	rotation.y = facing


## Eases into a named pose. Unknown names are ignored.
func set_pose(pose: String, seconds: float = 0.9) -> void:
	if not POSES.has(pose):
		return
	var target: Dictionary = POSES[pose]
	_chart.visible = target["chart"]
	if _tween != null:
		_tween.kill()
		_tween = null
	if seconds <= 0.0:
		for part: String in _parts:
			(_parts[part] as Node3D).rotation = target[part]
		return
	_tween = create_tween().set_parallel(true)
	for part: String in _parts:
		_tween.tween_property(_parts[part], "rotation", target[part], seconds) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Where the figure's eyes are, in its parent's space.
func eye_position() -> Vector3:
	return position + Vector3(0.0, EYE_HEIGHT, 0.0)


func _process(delta: float) -> void:
	_time += delta
	rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-2.5 * delta))
	_sway.position.y = 0.004 * sin(_time * 1.4)
	_sway.rotation.z = 0.012 * sin(_time * 0.6)


func _joint(parent: Node3D, part: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = pos
	parent.add_child(joint)
	_parts[part] = joint
	return joint


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst
