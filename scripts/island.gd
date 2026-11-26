class_name Island
extends Node3D
## One procedural island: a wobbly coastline with a hill in the middle.
## The coastline is kept as a ring of points so the chart can draw it and the
## ship can run aground on it.

const SAMPLES := 180        ## coastline points, one every 2 degrees
const RINGS := 18
const BASE_RADIUS := 300.0
const RADIUS_SWING := 110.0
const PEAK_HEIGHT := 150.0
const PALMS := 70
const LANDMARK_EVERY := 15  ## one landmark every 15 coast points (30 degrees)
const TREES := 900
const SURF_SHADER := preload("res://shaders/surf.gdshader")
## The island is a stand-in for Tahiti: the shape is made up, not the real
## coastline. Point Venus is real (the north point, beside Matavai Bay). The
## other names are invented in the plain style surveyors used. Clockwise from east.
const LANDMARK_NAMES: Array[String] = [
	"East Cape", "Flat Point", "Stack Rock", "South Head", "Sandy Spit", "Table Bluff",
	"West Cape", "Pillar Point", "Gannet Rock", "Point Venus", "Saddle Point", "Red Bluff",
]

## What stands on each headland, in the same order as the names.
const LANDMARK_KINDS: Array[String] = [
	"rock", "palms", "rock", "bluff", "palms", "bluff",
	"rock", "rock", "rock", "palms", "rock", "bluff",
]

var coast := PackedVector2Array()      ## world-space (x, z) coastline points
var landmarks := PackedVector2Array()  ## world-space (x, z) of each landmark
## Set before build() to keep palms off a stretch of beach (an angle, radians).
var keep_clear_angle: float = INF

var _landmark_tops := PackedFloat32Array()
var _bark: ShaderMaterial
var _fronds: ShaderMaterial
var _radii := PackedFloat32Array()
var _heights := PackedFloat32Array()  # height of every mesh vertex, ring by ring


func build(noise_seed: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 0.01

	coast.resize(SAMPLES)
	_radii.resize(SAMPLES)
	_heights.resize((RINGS + 1) * SAMPLES)
	for i in SAMPLES:
		var a := TAU * i / SAMPLES
		var r := BASE_RADIUS + RADIUS_SWING * noise.get_noise_2d(cos(a) * 130.0, sin(a) * 130.0)
		_radii[i] = r
		coast[i] = Vector2(position.x + cos(a) * r, position.z + sin(a) * r)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in RINGS + 1:
		# t = 0 at the summit, 1 at the waterline, beyond 1 is the seabed.
		var t := 1.25 * ring / RINGS
		for i in SAMPLES:
			var a := TAU * i / SAMPLES
			var x := cos(a) * _radii[i] * t
			var z := sin(a) * _radii[i] * t
			var h := 0.0
			if t <= 1.0:
				var rough := 0.72 + 0.28 * noise.get_noise_2d(x * 2.0 + 900.0, z * 2.0)
				# Sharp ridges running down from the peak, as on a volcanic island.
				var ridge := 1.0 - 0.45 * absf(noise.get_noise_2d(x * 0.9, z * 0.9 + 400.0))
				h = PEAK_HEIGHT * pow(1.0 - t, 1.9) * rough * ridge
			else:
				h = -(t - 1.0) * 60.0
			st.set_color(_land_color(t + 0.05 * noise.get_noise_2d(x * 3.0, z * 3.0 - 700.0)))
			_heights[ring * SAMPLES + i] = h
			st.add_vertex(Vector3(x, h, z))
	for ring in RINGS:
		for i in SAMPLES:
			var j := (i + 1) % SAMPLES
			var inner_i := ring * SAMPLES + i
			var inner_j := ring * SAMPLES + j
			var outer_i := (ring + 1) * SAMPLES + i
			var outer_j := (ring + 1) * SAMPLES + j
			st.add_index(inner_i)
			st.add_index(outer_i)
			st.add_index(outer_j)
			st.add_index(inner_i)
			st.add_index(outer_j)
			st.add_index(inner_j)
	st.generate_normals()

	var mat := Paint.material(Color(1.0, 1.0, 1.0), 0.6, 0.85)

	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	add_child(inst)
	_bark = Paint.material(Color(0.40, 0.31, 0.22), 0.3, 0.85)
	_fronds = Paint.material(Color(0.14, 0.32, 0.12), 0.3, 0.8)
	_build_landmarks()
	_build_palms(noise_seed)
	_build_forest(noise_seed)
	_build_surf()


func landmark_name(index: int) -> String:
	return LANDMARK_NAMES[index % LANDMARK_NAMES.size()]


## Where to aim at a landmark: a point partway up it, in world space.
func landmark_aim_point(index: int) -> Vector3:
	var p := landmarks[index]
	return Vector3(p.x, _landmark_tops[index] * 0.6, p.y)


## Each headland has something a surveyor could pick out through a glass:
## a stack of rock, a bluff, or a clump of tall palms on a low point.
func _build_landmarks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1772
	landmarks.clear()
	_landmark_tops.clear()
	for i in range(0, SAMPLES, LANDMARK_EVERY):
		var k := i / LANDMARK_EVERY
		var kind: String = LANDMARK_KINDS[k % LANDMARK_KINDS.size()]
		var a := TAU * i / SAMPLES
		# Rocks stand in the water just off the point; the rest are on the shore.
		var r := _radii[i] * (1.03 if kind == "rock" else 0.95)
		var local := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var world := Vector2(position.x + local.x, position.z + local.z)
		if kind != "rock":
			local.y = surface_height(world)
		landmarks.append(world)

		var top := 10.0
		match kind:
			"rock":
				top = _rock_stack(local, rng, Color(0.33, 0.31, 0.29), rng.randf_range(9.0, 16.0))
			"bluff":
				var red := LANDMARK_NAMES[k].begins_with("Red")
				top = _bluff(local, a, rng,
						Color(0.50, 0.24, 0.16) if red else Color(0.45, 0.40, 0.32))
			_:
				top = _palm_clump(local, rng)
		_landmark_tops.append(top)


## A pile of rough boulders. Returns how high it stands above the sea.
func _rock_stack(at: Vector3, rng: RandomNumberGenerator, colour: Color, height: float) -> float:
	var stone := Paint.material(colour, 0.3, 0.8)
	for n in 4:
		var inst := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 7
		ball.rings = 4
		inst.mesh = ball
		inst.material_override = stone
		var tall := height * (1.0 if n == 0 else rng.randf_range(0.35, 0.7))
		var wide := height * rng.randf_range(0.28, 0.45)
		inst.scale = Vector3(wide, tall, wide * rng.randf_range(0.7, 1.2))
		inst.position = at + Vector3(rng.randf_range(-1.0, 1.0) * height * 0.4 * minf(n, 1.0),
				tall * 0.25, rng.randf_range(-1.0, 1.0) * height * 0.4 * minf(n, 1.0))
		inst.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU),
				rng.randf_range(-0.2, 0.2))
		add_child(inst)
	return height * 1.2


## A broken cliff face on the shore. Returns the height of its top.
func _bluff(at: Vector3, angle: float, rng: RandomNumberGenerator, colour: Color) -> float:
	var stone := Paint.material(colour, 0.6, 0.8)
	var height := rng.randf_range(14.0, 20.0)
	for n in 3:
		var inst := MeshInstance3D.new()
		var block := BoxMesh.new()
		block.size = Vector3(rng.randf_range(9.0, 14.0), height * (1.0 - 0.2 * n),
				rng.randf_range(7.0, 11.0))
		inst.mesh = block
		inst.material_override = stone
		inst.position = at + Vector3((n - 1) * 8.0 * -sin(angle), block.size.y * 0.3,
				(n - 1) * 8.0 * cos(angle))
		inst.rotation = Vector3(rng.randf_range(-0.08, 0.08), -angle + rng.randf_range(-0.3, 0.3),
				rng.randf_range(-0.08, 0.08))
		add_child(inst)
	return at.y + height * 0.8


## Three or four tall palms close together. Returns the height of the crowns.
func _palm_clump(at: Vector3, rng: RandomNumberGenerator) -> float:
	var tallest := 0.0
	for n in 4:
		var height := rng.randf_range(13.0, 17.0)
		_palm(at + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0)), height, rng)
		tallest = maxf(tallest, height)
	return at.y + tallest


func _palm(foot: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var trunk := MeshInstance3D.new()
	var stem := CylinderMesh.new()
	stem.top_radius = 0.16
	stem.bottom_radius = 0.28
	stem.height = height
	stem.radial_segments = 6
	stem.rings = 1
	trunk.mesh = stem
	trunk.material_override = _bark
	trunk.position = foot + Vector3(0.0, height * 0.5 - 0.3, 0.0)
	trunk.rotation = Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
	add_child(trunk)
	# The crown: drooping fronds, as flattened cones set in a ring.
	for n in 6:
		var frond := MeshInstance3D.new()
		var leaf := CylinderMesh.new()
		leaf.top_radius = 0.02
		leaf.bottom_radius = 0.55
		leaf.height = 3.4
		leaf.radial_segments = 4
		leaf.rings = 1
		frond.mesh = leaf
		frond.material_override = _fronds
		var turn := TAU * n / 6.0 + rng.randf_range(-0.3, 0.3)
		frond.rotation = Vector3(rng.randf_range(1.75, 2.1), turn, 0.0)
		frond.scale = Vector3(1.0, 1.0, 0.25)
		frond.position = foot + Vector3(sin(turn) * 1.4, height - 0.5, cos(turn) * 1.4)
		add_child(frond)


## Forest on the slopes: many small tree crowns drawn as one batch.
func _build_forest(forest_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed + 7
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 1.7
	crown.radial_segments = 6
	crown.rings = 3
	var leaves := Paint.material(Color(1.0, 1.0, 1.0), 0.4, 0.8)
	crown.material = leaves

	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = crown
	batch.instance_count = TREES
	for n in TREES:
		var a := rng.randf_range(0.0, TAU)
		var t := rng.randf_range(0.22, 0.86)
		var r := coast_radius(a) * t
		var world := Vector2(position.x + cos(a) * r, position.z + sin(a) * r)
		var size := rng.randf_range(4.0, 8.0)
		var at := Vector3(cos(a) * r, surface_height(world) + size * 0.45, sin(a) * r)
		var shape := Basis().scaled(Vector3(size, size * rng.randf_range(0.8, 1.3), size))
		batch.set_instance_transform(n, Transform3D(shape, at))
		var green := rng.randf_range(0.0, 1.0)
		batch.set_instance_color(n, Color(0.10 + 0.10 * green, 0.26 + 0.14 * green, 0.10))
	var forest := MultiMeshInstance3D.new()
	forest.multimesh = batch
	add_child(forest)


## A band of breaking water all round the shore.
func _build_surf() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SAMPLES + 1:
		var k := i % SAMPLES
		var a := TAU * k / SAMPLES
		var along := float(i) / SAMPLES * 240.0
		st.set_uv(Vector2(along, 0.0))
		st.add_vertex(Vector3(cos(a) * _radii[k] * 0.985, 0.7, sin(a) * _radii[k] * 0.985))
		st.set_uv(Vector2(along, 1.0))
		st.add_vertex(Vector3(cos(a) * (_radii[k] + 26.0), 0.45, sin(a) * (_radii[k] + 26.0)))
	for i in SAMPLES:
		var p := i * 2
		st.add_index(p)
		st.add_index(p + 1)
		st.add_index(p + 3)
		st.add_index(p)
		st.add_index(p + 3)
		st.add_index(p + 2)
	st.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = SURF_SHADER
	var surf := MeshInstance3D.new()
	surf.mesh = st.commit()
	surf.material_override = mat
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surf)


## Height of the ground (metres above the sea) at a world (x, z) position.
func surface_height(world: Vector2) -> float:
	var offset := world - Vector2(position.x, position.z)
	var angle := wrapf(offset.angle(), 0.0, TAU)
	var t := offset.length() / coast_radius(angle)
	var ring_f := clampf(t / 1.25 * RINGS, 0.0, RINGS - 0.001)
	var ring := int(ring_f)
	var f := angle / TAU * SAMPLES
	var i := int(f) % SAMPLES
	var j := (i + 1) % SAMPLES
	var inner := lerpf(_heights[ring * SAMPLES + i], _heights[ring * SAMPLES + j], f - floorf(f))
	var outer := lerpf(_heights[(ring + 1) * SAMPLES + i], _heights[(ring + 1) * SAMPLES + j],
			f - floorf(f))
	return lerpf(inner, outer, ring_f - ring)


## Distance from the island's centre to the waterline along a world bearing
## given as an angle in the XZ plane (atan2(z, x)).
func coast_radius(angle: float) -> float:
	var f := wrapf(angle, 0.0, TAU) / TAU * SAMPLES
	var i := int(f) % SAMPLES
	var j := (i + 1) % SAMPLES
	return lerpf(_radii[i], _radii[j], f - floorf(f))


## Coconut palms along the shore.
func _build_palms(palm_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = palm_seed
	for k in PALMS:
		var a := rng.randf_range(0.0, TAU)
		if absf(wrapf(a - keep_clear_angle, -PI, PI)) < 0.2:
			continue
		var r := coast_radius(a) * rng.randf_range(0.86, 0.94)
		var world := Vector2(position.x + cos(a) * r, position.z + sin(a) * r)
		_palm(Vector3(cos(a) * r, surface_height(world), sin(a) * r),
				rng.randf_range(7.0, 11.0), rng)


func _land_color(t: float) -> Color:
	if t > 1.0:
		return Color(0.55, 0.60, 0.45)   # shallows
	if t > 0.9:
		return Color(0.20, 0.19, 0.18).lerp(Color(0.45, 0.40, 0.33), (t - 0.9) * 10.0)  # dark sand
	if t > 0.5:
		return Color(0.16, 0.34, 0.14)   # forest
	if t > 0.25:
		return Color(0.24, 0.38, 0.18)   # high slopes
	return Color(0.36, 0.35, 0.30)       # bare rock
