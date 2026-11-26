class_name Canoes
extends Node3D
## The people of the island out on the water: outrigger canoes paddling
## along inside the reefs, fishing and carrying, and one under sail further
## out. They go about their own business and take no notice of the ship.

var island: Island
var sea: Sea

var _boats: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1769
	for n in 6:
		var sailing := n == 5
		var boat := _build_canoe(sailing, rng)
		add_child(boat)
		_boats.append({
			"boat": boat,
			"angle": rng.randf_range(0.0, TAU),
			"off": 235.0 if sailing else rng.randf_range(55.0, 105.0),
			"speed": (3.0 if sailing else rng.randf_range(1.0, 1.7)) * (1.0 if n % 2 == 0 else -1.0),
			"phase": rng.randf_range(0.0, TAU),
		})


func _process(delta: float) -> void:
	if island == null or sea == null:
		return
	_time += delta
	for entry in _boats:
		var boat: Node3D = entry["boat"]
		var a: float = entry["angle"]
		var reach: float = island.coast_radius(a) + float(entry["off"])
		a += float(entry["speed"]) / reach * delta
		entry["angle"] = a
		var x := island.position.x + cos(a) * reach
		var z := island.position.z + sin(a) * reach
		var going := signf(entry["speed"])
		var along := Vector2(-sin(a), cos(a)) * going
		boat.position = Vector3(x, sea.height_at(x, z) + 0.12, z)
		boat.rotation = Vector3(0.03 * sin(_time * 1.3 + float(entry["phase"])),
				atan2(-along.x, -along.y), 0.05 * sin(_time * 0.9 + float(entry["phase"])))
		# The paddles dip and swing, each a little after the one before.
		var k := 0
		for paddle: Node3D in boat.get_meta("paddles"):
			paddle.rotation.x = 0.55 * sin(_time * 3.2 + float(entry["phase"]) + k * 0.5)
			k += 1


## An outrigger canoe (the bow is toward -Z) with its float out to port.
func _build_canoe(sailing: bool, rng: RandomNumberGenerator) -> Node3D:
	var boat := Node3D.new()
	var wood := Paint.material(Color(0.34, 0.22, 0.13), 0.3, 0.8)
	var skin := Paint.skin(Color(0.58, 0.40, 0.28))
	var cloth := Paint.cloth(Color(0.88, 0.83, 0.70))
	var length := 4.6 if sailing else rng.randf_range(2.8, 3.6)
	_lump(boat, Vector3(0.33, 0.3, length), Vector3.ZERO, wood)
	_lump(boat, Vector3(0.1, 0.1, length * 0.62), Vector3(-1.5, -0.08, 0.0), wood)
	for end: float in [-1.0, 1.0]:
		_bar(boat, Vector3(1.5, 0.05, 0.07), Vector3(-0.75, 0.18, end * length * 0.3), wood)

	var paddles: Array[Node3D] = []
	var crew := 3 if sailing else (1 + rng.randi() % 2)
	for n in crew:
		var seat := lerpf(-length * 0.45, length * 0.45, (n + 0.5) / crew)
		_lump(boat, Vector3(0.17, 0.3, 0.13), Vector3(0.0, 0.52, seat), cloth if n % 2 == 0 else skin)
		_lump(boat, Vector3(0.1, 0.12, 0.1), Vector3(0.0, 0.96, seat), skin)
		_lump(boat, Vector3(0.1, 0.07, 0.1), Vector3(0.0, 1.03, seat + 0.01),
				Paint.cloth(Color(0.07, 0.06, 0.05)))   # hair
		if sailing:
			continue
		var paddle := Node3D.new()
		paddle.position = Vector3(0.28 * (1.0 if n % 2 == 0 else -1.0), 0.75, seat - 0.2)
		boat.add_child(paddle)
		_bar(paddle, Vector3(0.04, 1.1, 0.04), Vector3(0.0, -0.45, 0.0), wood)
		_bar(paddle, Vector3(0.03, 0.4, 0.16), Vector3(0.0, -1.0, 0.0), wood)
		paddles.append(paddle)
	boat.set_meta("paddles", paddles)

	if sailing:
		# A tall narrow sail of matting on a mast stepped forward.
		_bar(boat, Vector3(0.08, 6.0, 0.08), Vector3(0.0, 3.0, -1.2), wood)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for corner in [Vector3(0.0, 0.5, -1.1), Vector3(0.0, 6.0, -1.0), Vector3(0.0, 4.6, 1.3),
				Vector3(0.0, 0.5, -1.1), Vector3(0.0, 4.6, 1.3), Vector3(0.0, 0.7, 1.6)]:
			st.add_vertex(corner)
		st.generate_normals()
		var sail := MeshInstance3D.new()
		sail.mesh = st.commit()
		sail.material_override = Paint.material(Color(0.78, 0.68, 0.45), 0.4, 0.85)
		sail.rotation.y = 0.35
		boat.add_child(sail)
	return boat


func _lump(parent: Node3D, radii: Vector3, pos: Vector3, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.scale = radii
	parent.add_child(inst)


func _bar(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
