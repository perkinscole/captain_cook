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
const LANDMARK_HEIGHT := 30.0
## The island is a stand-in for Tahiti: the shape is made up, not the real
## coastline. Point Venus is real (the north point, beside Matavai Bay). The
## other names are invented in the plain style surveyors used. Clockwise from east.
const LANDMARK_NAMES: Array[String] = [
	"East Cape", "Flat Point", "Stack Rock", "South Head", "Sandy Spit", "Table Bluff",
	"West Cape", "Pillar Point", "Gannet Rock", "Point Venus", "Saddle Point", "Red Bluff",
]

var coast := PackedVector2Array()      ## world-space (x, z) coastline points
var landmarks := PackedVector2Array()  ## world-space (x, z) of each landmark
## Set before build() to keep palms off a stretch of beach (an angle, radians).
var keep_clear_angle: float = INF

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

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	add_child(inst)
	_build_landmarks()
	_build_palms(noise_seed)


func landmark_name(index: int) -> String:
	return LANDMARK_NAMES[index % LANDMARK_NAMES.size()]


## Where to aim at a landmark: a point partway up it, in world space.
func landmark_aim_point(index: int) -> Vector3:
	var p := landmarks[index]
	return Vector3(p.x, LANDMARK_HEIGHT * 0.6, p.y)


## Placeholder landmarks: a pale stone pillar with a dark cap on each headland.
func _build_landmarks() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.86, 0.83, 0.74)
	stone.roughness = 1.0
	var cap := StandardMaterial3D.new()
	cap.albedo_color = Color(0.25, 0.10, 0.08)
	cap.roughness = 1.0

	landmarks.clear()
	for i in range(0, SAMPLES, LANDMARK_EVERY):
		var a := TAU * i / SAMPLES
		var r := _radii[i] - 14.0
		var local := Vector3(cos(a) * r, 0.0, sin(a) * r)
		landmarks.append(Vector2(position.x + local.x, position.z + local.z))

		var pillar := MeshInstance3D.new()
		var shaft := CylinderMesh.new()
		shaft.top_radius = 3.0
		shaft.bottom_radius = 5.0
		shaft.height = LANDMARK_HEIGHT
		pillar.mesh = shaft
		pillar.material_override = stone
		pillar.position = local + Vector3(0.0, LANDMARK_HEIGHT * 0.5, 0.0)
		add_child(pillar)

		var top := MeshInstance3D.new()
		var block := CylinderMesh.new()
		block.top_radius = 3.4
		block.bottom_radius = 3.4
		block.height = 4.0
		top.mesh = block
		top.material_override = cap
		top.position = local + Vector3(0.0, LANDMARK_HEIGHT + 2.0, 0.0)
		add_child(top)


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


## Coconut palms along the shore: a trunk and a dark crown each.
func _build_palms(palm_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = palm_seed
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.40, 0.31, 0.22)
	bark.roughness = 1.0
	var fronds := StandardMaterial3D.new()
	fronds.albedo_color = Color(0.13, 0.30, 0.12)
	fronds.roughness = 1.0
	for k in PALMS:
		var a := rng.randf_range(0.0, TAU)
		if absf(wrapf(a - keep_clear_angle, -PI, PI)) < 0.2:
			continue
		var r := coast_radius(a) * rng.randf_range(0.86, 0.94)
		var world := Vector2(position.x + cos(a) * r, position.z + sin(a) * r)
		var height := rng.randf_range(7.0, 11.0)
		var foot := Vector3(cos(a) * r, surface_height(world), sin(a) * r)

		var trunk := MeshInstance3D.new()
		var stem := CylinderMesh.new()
		stem.top_radius = 0.16
		stem.bottom_radius = 0.28
		stem.height = height
		stem.radial_segments = 6
		stem.rings = 1
		trunk.mesh = stem
		trunk.material_override = bark
		trunk.position = foot + Vector3(0.0, height * 0.5 - 0.3, 0.0)
		trunk.rotation = Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
		add_child(trunk)

		var crown := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 2.4
		ball.height = 2.2
		ball.radial_segments = 8
		ball.rings = 4
		crown.mesh = ball
		crown.material_override = fronds
		crown.position = foot + Vector3(0.0, height, 0.0)
		add_child(crown)


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
