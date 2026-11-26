class_name Birds
extends Node3D
## A few seabirds wheeling in the air, to make the place feel alive. Set
## `follow` to have them keep company with something that moves.

var count: int = 10
var spread := Vector2(40.0, 140.0)    ## nearest and furthest they circle, metres
var heights := Vector2(15.0, 45.0)
var follow: Node3D

var _birds: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.93, 0.93, 0.90)
	white.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in count:
		var body := Node3D.new()
		add_child(body)
		_part(body, Vector3(0.14, 0.12, 0.6), Vector3.ZERO, white)
		var left := Node3D.new()
		var right := Node3D.new()
		body.add_child(left)
		body.add_child(right)
		_part(left, Vector3(0.8, 0.03, 0.26), Vector3(-0.4, 0.0, 0.0), white)
		_part(right, Vector3(0.8, 0.03, 0.26), Vector3(0.4, 0.0, 0.0), white)
		_birds.append({
			"body": body, "left": left, "right": right,
			"radius": rng.randf_range(spread.x, spread.y),
			"height": rng.randf_range(heights.x, heights.y),
			"speed": rng.randf_range(0.08, 0.2) * (1.0 if rng.randf() < 0.5 else -1.0),
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
		# Face along the circle, banked a little into the turn.
		var going := signf(bird["speed"])
		body.rotation = Vector3(0.0, -a - (PI if going < 0.0 else 0.0), 0.25 * going)
		# Flap in bursts, glide in between.
		var burst := maxf(0.0, sin(_time * 0.7 + bird["phase"] * 3.0))
		var beat := 0.15 + 0.6 * burst * sin(_time * bird["flap"])
		(bird["left"] as Node3D).rotation.z = -beat
		(bird["right"] as Node3D).rotation.z = beat


func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
