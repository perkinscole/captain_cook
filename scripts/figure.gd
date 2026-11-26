class_name Figure
extends Node3D
## A person, built from rounded shapes with jointed limbs, for telling the
## story through poses and simple movement rather than recorded animation.
## It holds a named pose and eases between poses, walks with a swing of the
## arms and legs, breathes, shifts its weight and glances about.
## Faces -Z; origin at the feet.

## Rotations (radians) for each joint, plus whether the chart is in hand.
## A joint left out of a pose hangs straight. For arms and thighs, +x
## swings the limb forward; z carries an arm across the body. A forearm
## bends forward with +x, a shin bends back with -x.
const POSES := {
	"at_ease": {
		"arm_l": Vector3(-0.35, 0.0, 0.2), "arm_r": Vector3(-0.35, 0.0, -0.2),
		"fore_l": Vector3(0.25, 0.0, 0.0), "fore_r": Vector3(0.25, 0.0, 0.0), "chart": false,
	},
	"regard": {
		"head": Vector3(0.05, 0.0, 0.0),
		"arm_l": Vector3(0.25, 0.0, 0.1), "fore_l": Vector3(1.0, 0.0, 0.0),
		"arm_r": Vector3(-0.35, 0.0, -0.2), "chart": true,
	},
	"reading": {
		"torso": Vector3(-0.06, 0.0, 0.0), "head": Vector3(-0.5, 0.0, 0.0),
		"arm_l": Vector3(0.55, 0.0, 0.2), "fore_l": Vector3(1.2, 0.0, 0.0),
		"arm_r": Vector3(0.55, 0.0, -0.2), "fore_r": Vector3(1.2, 0.0, 0.0), "chart": true,
	},
	"pointing": {
		"torso": Vector3(-0.06, 0.0, 0.0), "head": Vector3(-0.4, 0.0, 0.0),
		"arm_l": Vector3(0.55, 0.0, 0.2), "fore_l": Vector3(1.2, 0.0, 0.0),
		"arm_r": Vector3(0.9, 0.0, -0.45), "fore_r": Vector3(0.5, 0.0, 0.0), "chart": true,
	},
	"offer": {
		"arm_l": Vector3(0.9, 0.0, 0.0), "fore_l": Vector3(0.6, 0.0, 0.0),
		"arm_r": Vector3(-0.35, 0.0, -0.2), "chart": true,
	},
	"helm": {
		"arm_l": Vector3(0.85, 0.0, 0.3), "fore_l": Vector3(0.6, 0.0, 0.0),
		"arm_r": Vector3(0.85, 0.0, -0.3), "fore_r": Vector3(0.6, 0.0, 0.0), "chart": false,
	},
	"climb": {
		"head": Vector3(0.3, 0.0, 0.0),
		"arm_l": Vector3(2.5, 0.0, 0.1), "fore_l": Vector3(0.4, 0.0, 0.0),
		"arm_r": Vector3(1.9, 0.0, -0.1), "fore_r": Vector3(0.9, 0.0, 0.0),
		"thigh_l": Vector3(0.9, 0.0, 0.0), "shin_l": Vector3(-1.1, 0.0, 0.0), "chart": false,
	},
	"haul": {
		"torso": Vector3(-0.45, 0.0, 0.0), "head": Vector3(-0.2, 0.0, 0.0),
		"arm_l": Vector3(1.6, 0.0, 0.2), "fore_l": Vector3(0.5, 0.0, 0.0),
		"arm_r": Vector3(1.6, 0.0, -0.2), "fore_r": Vector3(0.5, 0.0, 0.0), "chart": false,
	},
	"lean": {
		"torso": Vector3(-0.32, 0.0, 0.0), "head": Vector3(0.2, 0.0, 0.0),
		"arm_l": Vector3(0.8, 0.0, 0.3), "fore_l": Vector3(1.3, 0.0, 0.0),
		"arm_r": Vector3(0.8, 0.0, -0.3), "fore_r": Vector3(1.3, 0.0, 0.0),
		"thigh_r": Vector3(-0.25, 0.0, 0.0), "shin_r": Vector3(-0.3, 0.0, 0.0), "chart": false,
	},
	"swing": {
		"torso": Vector3(-0.1, 0.0, 0.0),
		"arm_l": Vector3(0.3, 0.0, 0.2), "arm_r": Vector3(1.0, 0.0, -0.9), "chart": false,
	},
}
const EYE_HEIGHT := 1.62
const HIP_HEIGHT := 0.92

## Set these before adding the figure to the scene.
var coat_color := Color(0.09, 0.12, 0.25)
var legs_color := Color(0.85, 0.82, 0.72)
var skin_color := Color(0.80, 0.62, 0.50)
var hair_color := Color(0.75, 0.73, 0.68)  ## officers powder their hair
var neck_color := Color(0.92, 0.90, 0.84)  ## stock, neckerchief and waistcoat
var wears_hat: bool = true    ## a cocked hat, as officers and marines wear
var wears_cap: bool = false   ## a seaman's knitted cap
var cap_color := Color(0.45, 0.14, 0.12)
var long_coat: bool = true    ## false = a seaman's short jacket
var cross_belts: bool = false ## the white belts of a marine
var idle_facing: float = 0.0  ## yaw (radians) when nobody is speaking to them
var idle_pose: String = "at_ease"  ## the pose they go back to
var lying: bool = false       ## laid in a hammock

var facing: float = 0.0  ## yaw (radians) the figure turns toward
var walking: bool = false  ## set while the figure is being moved along the deck

var _sway: Node3D
var _parts: Dictionary = {}
var _chart: MeshInstance3D
var _tween: Tween
var _time: float = 0.0
var _gait: float = 0.0
var _stride: float = 0.0      # 0 = standing, 1 = in full stride
var _glance: float = 0.0      # where the head is idly turned
var _glance_wait: float = 2.0
var _quirk: float = 0.0       # so that no two people breathe in step


func _ready() -> void:
	_quirk = randf_range(0.0, TAU)
	var coat := _material(coat_color)
	var legs := _material(legs_color)
	var skin := Paint.skin(skin_color)
	var hair := _material(hair_color)
	var neck := _material(neck_color)
	var black := _material(Color(0.05, 0.05, 0.06))
	var paper := _material(Color(0.91, 0.85, 0.70))

	_sway = Node3D.new()
	add_child(_sway)
	var hips := Node3D.new()
	hips.position = Vector3(0.0, HIP_HEIGHT, 0.0)
	_sway.add_child(hips)

	# Legs: thigh, knee, shin, and a shoe with a little heel.
	for side: float in [-1.0, 1.0]:
		var name_end := "_l" if side < 0.0 else "_r"
		var thigh := _joint(hips, "thigh" + name_end, Vector3(side * 0.09, 0.0, 0.0))
		_capsule(thigh, 0.075, 0.5, Vector3(0.0, -0.22, 0.0), legs)
		var shin := _joint(thigh, "shin" + name_end, Vector3(0.0, -0.44, 0.0))
		_capsule(shin, 0.055, 0.5, Vector3(0.0, -0.22, 0.0), _material(Color(0.88, 0.86, 0.80)))
		_capsule(shin, 0.05, 0.25, Vector3(0.0, -0.45, -0.05), black).rotation.x = PI * 0.5

	# Body: chest, shoulders, and the coat.
	var torso := _joint(hips, "torso", Vector3.ZERO)
	var chest := _cylinder(torso, 0.2, 0.16, 0.5, Vector3(0.0, 0.3, 0.0), coat)
	chest.scale.z = 0.66
	_ball(torso, Vector3(0.21, 0.14, 0.15), Vector3(0.0, 0.03, 0.0), legs if not long_coat else coat)
	for side: float in [-1.0, 1.0]:
		_ball(torso, Vector3(0.09, 0.08, 0.09), Vector3(side * 0.2, 0.52, 0.0), coat)
	if long_coat:
		var skirts := _cylinder(torso, 0.17, 0.27, 0.5, Vector3(0.0, -0.18, 0.0), coat)
		skirts.scale.z = 0.72
		_box(torso, Vector3(0.16, 0.42, 0.02), Vector3(0.0, 0.27, -0.134), neck)  # waistcoat
		for k in 4:
			_ball(torso, Vector3(0.014, 0.014, 0.01), Vector3(0.0, 0.42 - 0.1 * k, -0.146),
					_material(Color(0.75, 0.6, 0.25)))  # buttons
	if cross_belts:
		for side: float in [-1.0, 1.0]:
			var belt := _box(torso, Vector3(0.05, 0.62, 0.3), Vector3(0.0, 0.3, 0.0),
					_material(Color(0.92, 0.9, 0.85)))
			belt.rotation.z = side * 0.55
	_cylinder(torso, 0.06, 0.075, 0.1, Vector3(0.0, 0.58, 0.0), neck)  # stock or neckerchief

	# Head: face, nose, eyes, hair tied back in a queue, and a hat or cap.
	var head := _joint(torso, "head", Vector3(0.0, 0.62, 0.0))
	_ball(head, Vector3(0.1, 0.125, 0.105), Vector3(0.0, 0.12, 0.0), skin)
	_ball(head, Vector3(0.018, 0.032, 0.03), Vector3(0.0, 0.108, -0.1), skin)     # nose
	_ball(head, Vector3(0.07, 0.03, 0.03), Vector3(0.0, 0.168, -0.082), skin)     # brow
	_ball(head, Vector3(0.05, 0.04, 0.04), Vector3(0.0, 0.03, -0.07), skin)       # chin
	var lips := Paint.skin(skin_color.darkened(0.3).lerp(Color(0.5, 0.2, 0.18), 0.4))
	_ball(head, Vector3(0.028, 0.007, 0.01), Vector3(0.0, 0.066, -0.097), lips)   # mouth
	for side: float in [-1.0, 1.0]:
		# Small eyes set under the brow, with a brow line above each.
		_ball(head, Vector3(0.012, 0.009, 0.008), Vector3(side * 0.036, 0.142, -0.094),
				Paint.skin(Color(0.9, 0.88, 0.84)))
		_ball(head, Vector3(0.006, 0.007, 0.006), Vector3(side * 0.036, 0.142, -0.1),
				Paint.skin(Color(0.08, 0.06, 0.05)))
		_ball(head, Vector3(0.022, 0.005, 0.008), Vector3(side * 0.037, 0.162, -0.097),
				Paint.skin(hair_color.darkened(0.3)))
		_ball(head, Vector3(0.015, 0.03, 0.02), Vector3(side * 0.1, 0.12, 0.0), skin)  # ears
	# Hair sits on the crown and the back of the head, clear of the face.
	_ball(head, Vector3(0.104, 0.095, 0.1), Vector3(0.0, 0.178, 0.035), hair)
	_capsule(head, 0.022, 0.2, Vector3(0.0, 0.04, 0.115), hair)                   # queue
	_ball(head, Vector3(0.03, 0.02, 0.03), Vector3(0.0, 0.12, 0.112), black)      # its ribbon
	if wears_hat:
		# A cocked hat: a three-cornered brim turned up round a low crown.
		var brim := _cylinder(head, 0.25, 0.27, 0.05, Vector3(0.0, 0.245, 0.0), black)
		(brim.mesh as CylinderMesh).radial_segments = 3
		brim.rotation.y = PI
		_cylinder(head, 0.095, 0.105, 0.1, Vector3(0.0, 0.285, 0.0), black)
	elif wears_cap:
		# A knitted cap, worn on the back of the head above the brow.
		_ball(head, Vector3(0.107, 0.07, 0.108), Vector3(0.0, 0.232, 0.02), _material(cap_color))

	# Arms: upper arm, elbow, forearm and hand.
	for side: float in [-1.0, 1.0]:
		var name_end := "_l" if side < 0.0 else "_r"
		var arm := _joint(torso, "arm" + name_end, Vector3(side * 0.245, 0.5, 0.0))
		_capsule(arm, 0.052, 0.34, Vector3(0.0, -0.15, 0.0), coat)
		var fore := _joint(arm, "fore" + name_end, Vector3(0.0, -0.3, 0.0))
		_capsule(fore, 0.044, 0.3, Vector3(0.0, -0.13, 0.0), coat)
		_ball(fore, Vector3(0.042, 0.055, 0.03), Vector3(0.0, -0.3, 0.0), skin)

	_chart = _box(_parts["fore_l"], Vector3(0.36, 0.015, 0.28), Vector3(0.1, -0.33, -0.08), paper)
	set_pose(idle_pose, 0.0)
	facing = idle_facing
	rotation.y = facing


## Eases into a named pose. Unknown names are ignored.
func set_pose(pose: String, seconds: float = 0.9) -> void:
	if not POSES.has(pose):
		return
	var target: Dictionary = POSES[pose]
	_chart.visible = target.get("chart", false)
	if _tween != null:
		_tween.kill()
		_tween = null
	if seconds <= 0.0:
		for part: String in _parts:
			(_parts[part] as Node3D).rotation = target.get(part, Vector3.ZERO)
		return
	_tween = create_tween().set_parallel(true)
	for part: String in _parts:
		_tween.tween_property(_parts[part], "rotation", target.get(part, Vector3.ZERO), seconds) \
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
	rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-3.5 * delta))

	# Walking: the legs swing from the hip and bend at the knee, and the
	# arms swing the other way. It eases in and out as they start and stop.
	_stride = move_toward(_stride, 1.0 if walking else 0.0, delta * 3.0)
	if _stride > 0.001:
		_gait += delta * 6.2
		for side: float in [-1.0, 1.0]:
			var end := "_l" if side < 0.0 else "_r"
			var swing := sin(_gait) * side
			var knee := maxf(0.0, sin(_gait - side * 1.3) * side)
			var arm := _part("arm" + end)
			var fore := _part("fore" + end)
			_part("thigh" + end).rotation.x = 0.5 * swing * _stride
			_part("shin" + end).rotation.x = -0.85 * knee * _stride
			arm.rotation.x = lerpf(arm.rotation.x, -0.4 * swing, _stride)
			fore.rotation.x = lerpf(fore.rotation.x, 0.35, _stride)
		_sway.position.y = 0.025 * absf(cos(_gait)) * _stride
		_sway.rotation.z = 0.03 * sin(_gait) * _stride
		return

	# Standing: breathing, and a slow shift of weight from foot to foot.
	_sway.position.y = 0.004 * sin(_time * 1.4 + _quirk)
	_sway.rotation.z = 0.02 * sin(_time * 0.31 + _quirk)
	var torso := _part("torso")
	torso.rotation.z = lerpf(torso.rotation.z, -0.02 * sin(_time * 0.31 + _quirk), 0.1)

	# Left to themselves, people look about them now and then.
	var settled := _tween == null or not _tween.is_running()
	if settled and not lying and absf(wrapf(facing - idle_facing, -PI, PI)) < 0.01:
		_glance_wait -= delta
		if _glance_wait <= 0.0:
			_glance_wait = randf_range(2.5, 7.0)
			_glance = randf_range(-0.7, 0.7)
		var head := _part("head")
		head.rotation.y = lerpf(head.rotation.y, _glance, 1.0 - exp(-2.0 * delta))


func _part(part: String) -> Node3D:
	return _parts[part] as Node3D


func _joint(parent: Node3D, part: String, pos: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = pos
	parent.add_child(joint)
	_parts[part] = joint
	return joint


func _material(color: Color) -> ShaderMaterial:
	return Paint.cloth(color)


## A rounded lump, given by its half-size along each axis.
func _ball(parent: Node3D, radii: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.scale = radii
	parent.add_child(inst)
	return inst


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
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
	mesh.radial_segments = 16
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
