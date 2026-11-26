class_name SeaLife
extends Node3D
## Life in the water round the ship: a pod of dolphins that comes to play
## in the bow wave for a while and goes away again, and flying fish that
## break from the sea ahead of her and glide off to either side.
## Both only appear when she has way on.

const DOLPHINS := 5
const FISH := 9
const LEAP_SECONDS := 3.4
const FLIGHT_SECONDS := 2.4

var ship: Ship
var sea: Sea

var _dolphins: Array[Dictionary] = []
var _fish: Array[Dictionary] = []
var _time: float = 0.0
var _pod_here: bool = false
var _pod_timer: float = 25.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var grey := Paint.material(Color(0.30, 0.36, 0.42), 0.25, 0.4)
	var pale := Paint.material(Color(0.72, 0.74, 0.74), 0.25, 0.4)
	for i in DOLPHINS:
		var body := Node3D.new()
		body.visible = false
		add_child(body)
		_lump(body, Vector3(0.27, 0.29, 1.05), Vector3.ZERO, grey)
		_lump(body, Vector3(0.2, 0.16, 0.8), Vector3(0.0, -0.13, -0.05), pale)    # belly
		_lump(body, Vector3(0.09, 0.08, 0.3), Vector3(0.0, -0.03, -1.1), grey)    # beak
		var fin := _lump(body, Vector3(0.03, 0.2, 0.2), Vector3(0.0, 0.33, 0.1), grey)
		fin.rotation.x = -0.5
		_lump(body, Vector3(0.36, 0.03, 0.14), Vector3(0.0, 0.0, 1.15), grey)     # flukes
		for side: float in [-1.0, 1.0]:
			var flipper := _lump(body, Vector3(0.2, 0.025, 0.1), Vector3(side * 0.3, -0.15, -0.4), grey)
			flipper.rotation.z = side * -0.5
		_dolphins.append({
			"body": body, "side": (-1.0 if i % 2 == 0 else 1.0) * _rng.randf_range(5.5, 10.0),
			"ahead": _rng.randf_range(-2.0, 16.0), "offset": _rng.randf(),
		})

	var silver := Paint.material(Color(0.62, 0.72, 0.82), 0.1, 0.25)
	for i in FISH:
		var body := Node3D.new()
		body.visible = false
		add_child(body)
		_lump(body, Vector3(0.04, 0.045, 0.17), Vector3.ZERO, silver)
		for side: float in [-1.0, 1.0]:
			var fin := _lump(body, Vector3(0.17, 0.006, 0.05), Vector3(side * 0.17, 0.02, -0.03), silver)
			fin.rotation.y = side * -0.35
		_fish.append({"body": body, "wait": _rng.randf_range(4.0, 20.0), "t": -1.0,
				"from": Vector3.ZERO, "way": Vector3.FORWARD})


func _process(delta: float) -> void:
	if ship == null or sea == null:
		return
	_time += delta
	var under_way := ship.speed > 2.0
	var fwd := ship.forward()
	var right := Vector3(-fwd.z, 0.0, fwd.x)

	# The pod comes and goes.
	_pod_timer -= delta
	if _pod_timer <= 0.0:
		_pod_here = not _pod_here
		_pod_timer = _rng.randf_range(35.0, 60.0) if _pod_here else _rng.randf_range(50.0, 90.0)
	for dolphin in _dolphins:
		var body: Node3D = dolphin["body"]
		body.visible = _pod_here and under_way
		if not body.visible:
			continue
		# Each leaps in a low arc, then runs under water until the next.
		var beat := fposmod(_time / LEAP_SECONDS + float(dolphin["offset"]), 1.0)
		var along: float = 16.0 + float(dolphin["ahead"])
		var lift := -1.4
		var pitch := 0.0
		if beat < 0.42:
			var a := beat / 0.42
			lift = -0.35 + 1.5 * sin(PI * a)
			pitch = 0.75 * cos(PI * a)
			along += 2.5 * (a - 0.5)
		var at := ship.position + fwd * along + right * float(dolphin["side"])
		body.position = Vector3(at.x, sea.height_at(at.x, at.z) + lift, at.z)
		body.rotation = Vector3(pitch, -deg_to_rad(ship.heading_deg), 0.0)

	# Flying fish burst out ahead and glide away to one side.
	for fish in _fish:
		var body: Node3D = fish["body"]
		if float(fish["t"]) < 0.0:
			fish["wait"] = float(fish["wait"]) - delta
			if float(fish["wait"]) <= 0.0 and under_way:
				var side := -1.0 if _rng.randf() < 0.5 else 1.0
				fish["from"] = ship.position + fwd * _rng.randf_range(14.0, 40.0) \
						+ right * side * _rng.randf_range(5.0, 22.0)
				fish["way"] = (fwd + right * side * _rng.randf_range(0.3, 1.1)).normalized()
				fish["t"] = 0.0
				body.visible = true
			continue
		fish["t"] = float(fish["t"]) + delta
		var t := float(fish["t"])
		if t >= FLIGHT_SECONDS:
			fish["t"] = -1.0
			fish["wait"] = _rng.randf_range(3.0, 16.0)
			body.visible = false
			continue
		var way: Vector3 = fish["way"]
		var at: Vector3 = fish["from"] + way * (13.0 * t)
		var glide := sin(PI * t / FLIGHT_SECONDS)
		body.position = Vector3(at.x, sea.height_at(at.x, at.z) + 0.15 + 1.1 * pow(glide, 0.6), at.z)
		body.rotation = Vector3(0.25 * cos(PI * t / FLIGHT_SECONDS), atan2(-way.x, -way.z), 0.0)


func _lump(parent: Node3D, radii: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	inst.scale = radii
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst
