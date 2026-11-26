class_name Figure
extends Node3D
## A simple person built from rounded shapes, for telling the story through
## poses rather than animation. It holds a named pose, eases between poses, and
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
	"helm": {
		"torso": Vector3.ZERO, "head": Vector3.ZERO,
		"arm_l": Vector3(1.2, 0.0, 0.25), "arm_r": Vector3(1.2, 0.0, -0.25), "chart": false,
	},
	"climb": {
		"torso": Vector3.ZERO, "head": Vector3(0.3, 0.0, 0.0),
		"arm_l": Vector3(2.6, 0.0, 0.1), "arm_r": Vector3(2.1, 0.0, -0.1), "chart": false,
	},
	"haul": {
		"torso": Vector3(-0.45, 0.0, 0.0), "head": Vector3(-0.2, 0.0, 0.0),
		"arm_l": Vector3(1.9, 0.0, 0.2), "arm_r": Vector3(1.9, 0.0, -0.2), "chart": false,
	},
	"swing": {
		"torso": Vector3(-0.1, 0.0, 0.0), "head": Vector3.ZERO,
		"arm_l": Vector3(0.3, 0.0, 0.2), "arm_r": Vector3(1.0, 0.0, -0.9), "chart": false,
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
var hair_color := Color(0.75, 0.73, 0.68)  ## officers powder their hair
var neck_color := Color(0.92, 0.90, 0.84)  ## stock, neckerchief and waistcoat
var wears_hat: bool = true
var long_coat: bool = true    ## false = a seaman's short jacket
var idle_facing: float = 0.0  ## yaw (radians) when nobody is speaking to them
var idle_pose: String = "at_ease"  ## the pose they go back to
var lying: bool = false       ## laid in a hammock

var facing: float = 0.0  ## yaw (radians) the figure turns toward

var _sway: Node3D
var _parts: Dictionary = {}
var _chart: MeshInstance3D
var _tween: Tween
var _time: float = 0.0
var _glance: float = 0.0      # where the head is idly turned
var _glance_wait: float = 2.0


func _ready() -> void:
	var coat := _material(coat_color)
	var legs := _material(legs_color)
	var skin := _material(skin_color)
	var hair := _material(hair_color)
	var neck := _material(neck_color)
	var black := _material(Color(0.05, 0.05, 0.06))
	var paper := _material(Color(0.91, 0.85, 0.70))

	_sway = Node3D.new()
	add_child(_sway)
	for side: float in [-1.0, 1.0]:
		_box(_sway, Vector3(0.1, 0.07, 0.25), Vector3(side * 0.09, 0.035, -0.03), black)
		_capsule(_sway, 0.075, 0.82, Vector3(side * 0.09, 0.45, 0.0), legs)

	var torso := _joint(_sway, "torso", Vector3(0.0, 0.85, 0.0))
	var body := _cylinder(torso, 0.21, 0.17, 0.56, Vector3(0.0, 0.3, 0.0), coat)
	body.scale.z = 0.68
	if long_coat:
		var skirts := _cylinder(torso, 0.18, 0.27, 0.46, Vector3(0.0, -0.15, 0.0), coat)
		skirts.scale.z = 0.72
		_box(torso, Vector3(0.17, 0.42, 0.02), Vector3(0.0, 0.26, -0.137), neck)  # waistcoat
	_cylinder(torso, 0.075, 0.085, 0.07, Vector3(0.0, 0.6, 0.0), neck)  # stock or neckerchief

	var head := _joint(torso, "head", Vector3(0.0, 0.61, 0.0))
	var face := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.105
	ball.height = 0.25
	face.mesh = ball
	face.material_override = skin
	face.position = Vector3(0.0, 0.12, 0.0)
	head.add_child(face)
	_box(head, Vector3(0.03, 0.05, 0.04), Vector3(0.0, 0.11, -0.11), skin)  # nose
	var scalp := MeshInstance3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.112
	cap.height = 0.22
	scalp.mesh = cap
	scalp.material_override = hair
	scalp.position = Vector3(0.0, 0.15, 0.03)
	head.add_child(scalp)
	if wears_hat:
		# A cocked hat: three-cornered brim and a low crown.
		var brim := _cylinder(head, 0.27, 0.29, 0.045, Vector3(0.0, 0.235, 0.0), black)
		(brim.mesh as CylinderMesh).radial_segments = 3
		_cylinder(head, 0.1, 0.11, 0.09, Vector3(0.0, 0.28, 0.0), black)

	for side: float in [-1.0, 1.0]:
		var arm := _joint(torso, "arm_l" if side < 0.0 else "arm_r", Vector3(side * 0.27, 0.56, 0.0))
		_capsule(arm, 0.055, 0.6, Vector3(0.0, -0.27, 0.0), coat)
		var hand := MeshInstance3D.new()
		var fist := SphereMesh.new()
		fist.radius = 0.05
		fist.height = 0.1
		hand.mesh = fist
		hand.material_override = skin
		hand.position = Vector3(0.0, -0.6, 0.0)
		arm.add_child(hand)

	_chart = _box(_parts["arm_l"], Vector3(0.36, 0.015, 0.28), Vector3(0.12, -0.62, -0.06), paper)
	set_pose(idle_pose, 0.0)
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


## Back to whatever they were doing.
func rest() -> void:
	facing = idle_facing
	set_pose(idle_pose)


## Lays the figure flat on its back with its head aft, or stands it up again.
func lie_down(down: bool) -> void:
	lying = down
	rotation.x = PI * 0.5 if down else 0.0


## Where the figure's eyes are, in its parent's space.
func eye_position() -> Vector3:
	if lying:
		return position + Vector3(0.0, 0.2, EYE_HEIGHT * 0.9)
	return position + Vector3(0.0, EYE_HEIGHT, 0.0)


func _process(delta: float) -> void:
	_time += delta
	rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-2.5 * delta))
	_sway.position.y = 0.004 * sin(_time * 1.4)
	_sway.rotation.z = 0.012 * sin(_time * 0.6)

	# Left to themselves, people look about them now and then.
	var settled := _tween == null or not _tween.is_running()
	if settled and not lying and absf(wrapf(facing - idle_facing, -PI, PI)) < 0.01:
		_glance_wait -= delta
		if _glance_wait <= 0.0:
			_glance_wait = randf_range(2.5, 7.0)
			_glance = randf_range(-0.6, 0.6)
		var head := _parts["head"] as Node3D
		head.rotation.y = lerpf(head.rotation.y, _glance, 1.0 - exp(-2.0 * delta))


func _joint(parent: Node3D, part: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = pos
	parent.add_child(joint)
	_parts[part] = joint
	return joint


func _material(color: Color) -> ShaderMaterial:
	return Paint.material(color, 0.1)   # small strokes: people are small


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst


func _cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 1
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst
