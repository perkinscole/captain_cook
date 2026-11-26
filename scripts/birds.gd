class_name Birds
extends Node3D
## Seabirds wheeling in the air, to make the place feel alive. Each has a
## body, a head, a tail and two swept wings that beat in bursts between
## glides. Set `follow` to have them keep company with something that moves.

var count: int = 10
var spread := Vector2(40.0, 140.0)    ## nearest and furthest they circle, metres
var heights := Vector2(15.0, 45.0)
var tint := Color(0.93, 0.93, 0.90)   ## white for gulls and terns, black for frigatebirds
var size: float = 1.0                 ## wingspan, as a multiple of a gull's
var pace: float = 1.0                 ## how fast they circle
var follow: Node3D

var _birds: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var feathers := Paint.material(tint, 0.2)
	var wing_mesh := _wing()
	for i in count:
		var body := Node3D.new()
		body.scale = Vector3(size, size, size)
		add_child(body)
		_lump(body, Vector3(0.09, 0.08, 0.3), Vector3.ZERO, feathers)
		_lump(body, Vector3(0.06, 0.06, 0.08), Vector3(0.0, 0.03, -0.3), feathers)     # head
		_lump(body, Vector3(0.015, 0.015, 0.07), Vector3(0.0, 0.02, -0.4),
				Paint.material(Color(0.85, 0.6, 0.15), 0.2))                           # beak
		_lump(body, Vector3(0.07, 0.012, 0.14), Vector3(0.0, 0.0, 0.36), feathers)    # tail
		var left := Node3D.new()
		var right := Node3D.new()
		body.add_child(left)
		body.add_child(right)
		var right_wing := MeshInstance3D.new()
		right_wing.mesh = wing_mesh
		right_wing.material_override = feathers
		right_wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		right.add_child(right_wing)
		var left_wing := right_wing.duplicate() as MeshInstance3D
		left_wing.scale.x = -1.0
		left.add_child(left_wing)
		_birds.append({
			"body": body, "left": left, "right": right,
			"radius": rng.randf_range(spread.x, spread.y),
			"height": rng.randf_range(heights.x, heights.y),
			"speed": rng.randf_range(0.08, 0.2) * pace * (1.0 if rng.randf() < 0.5 else -1.0),
			"phase": rng.randf_range(0.0, TAU),
			"flap": rng.randf_range(5.0, 8.0),
		})


func _process(delta: float) -> void:
	_time += delta
	var middle := follow.global_position if follow != null else global_position
	for bird in _birds:
		var a: float = bird["phase"] + _time * bird["speed"]
		var r: float = bird["radius"] * (1.0 + 0.15 * sin(_time * 0.21 + bird["phase"]))
		var body: Node3D = bird["body"]
		body.global_position = Vector3(middle.x + cos(a) * r,
				bird["height"] + 3.0 * sin(_time * 0.4 + bird["phase"]), middle.z + sin(a) * r)
		# Face along the circle, banked into the turn.
		var going := signf(bird["speed"])
		body.rotation = Vector3(0.0, -a - (PI if going < 0.0 else 0.0), 0.3 * going)
		# Flap in bursts, glide in between with the wings held a little raised.
		var burst := maxf(0.0, sin(_time * 0.7 + bird["phase"] * 3.0))
		var beat := 0.18 + 0.65 * burst * sin(_time * bird["flap"])
		(bird["left"] as Node3D).rotation.z = -beat
		(bird["right"] as Node3D).rotation.z = beat


## One wing: broad at the shoulder, swept back to a point.
func _wing() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoulder_front := Vector3(0.05, 0.0, -0.14)
	var shoulder_back := Vector3(0.05, 0.0, 0.12)
	var elbow_front := Vector3(0.55, 0.0, -0.1)
	var elbow_back := Vector3(0.5, 0.0, 0.14)
	var tip := Vector3(1.15, 0.0, 0.22)
	for corner in [shoulder_front, elbow_front, elbow_back, shoulder_front, elbow_back,
			shoulder_back, elbow_front, tip, elbow_back]:
		st.add_vertex(corner)
	st.generate_normals()
	return st.commit()


func _lump(parent: Node3D, radii: Vector3, pos: Vector3, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.scale = radii
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
