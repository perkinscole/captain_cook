class_name Island
extends Node3D
## The island: a stand-in for Tahiti.
##
## Like Tahiti it is the stump of an old volcano that the rain has been
## wearing down ever since: a broken ring of peaks round a sunken crater,
## knife-edged ridges with deep valleys between them running down to the
## sea, waterfalls at their heads, and a narrow green plain round the shore
## where the people live among breadfruit and coconut palms. There are
## villages of thatched houses with canoes drawn up before them, and on the
## north point the fort the ship's company built for the observatory.
##
## The ground itself is not shaped here. It is made beforehand by
## tools/make_island.py, which raises a volcano and lets rivers cut it, and
## saved in terrain/ as a map of heights with maps of light and running
## water to go with it. This reads those, lays a mesh over the heights,
## and plants the island by rule: where a tree stands depends on how steep
## and how wet the ground under it is.
##
## The coastline is kept as a ring of points so the chart can draw it and
## the ship can run aground on it. The shape is invented, not surveyed.

const SAMPLES := 180        ## coastline points, one every 2 degrees
const BASE_RADIUS := 300.0
const TERRAIN := "res://terrain/island"
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const GROUND_STEP := 2.0    ## metres between the points of the ground mesh
## Where the mountains end and the coastal plain begins, as a share of the
## way from the middle to the shore.
const PLAIN_FROM := 0.84
const PALMS := 340
const GROVE_TREES := 260
const LANDMARK_EVERY := 15  ## one landmark every 15 coast points (30 degrees)
const TREES := 9000
const WATERFALL_SHADER := preload("res://shaders/waterfall.gdshader")
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
var _trunk_mesh: CylinderMesh
var _crown_mesh: ArrayMesh
var _bark: ShaderMaterial
var _fronds: ShaderMaterial
var _radii := PackedFloat32Array()
var _size := 0                      # the height map is _size by _size
var _span := 1024.0                 # and covers this many metres
var _heights := PackedFloat32Array()
var _masks := PackedByteArray()     # open sky, sunlight, running water, rock
var _waterfalls: Array = []


func build(tree_seed: int) -> void:
	if not _read_terrain():
		push_error("The island's ground is missing: run tools/make_island.py")
		return
	coast.resize(SAMPLES)
	for i in SAMPLES:
		var a := TAU * i / SAMPLES
		coast[i] = Vector2(position.x + cos(a) * _radii[i], position.z + sin(a) * _radii[i])
	_build_ground()

	_bark = Paint.material(Color(0.40, 0.31, 0.22), 0.3, 0.85)
	_fronds = Paint.material(Color(0.15, 0.36, 0.13), 0.3, 0.8)
	_trunk_mesh = CylinderMesh.new()
	_trunk_mesh.top_radius = 0.6
	_trunk_mesh.bottom_radius = 1.0
	_trunk_mesh.height = 1.0
	_trunk_mesh.radial_segments = 6
	_trunk_mesh.rings = 1
	_trunk_mesh.material = _bark
	_crown_mesh = _frond_crown()
	_build_landmarks()
	_build_palms(tree_seed)
	_build_forest(tree_seed)
	_build_surf()
	_build_waterfalls()
	_build_villages(tree_seed)
	_build_fort()


## Reads what tools/make_island.py wrote. Returns false if it is not there.
func _read_terrain() -> bool:
	var about: Variant = JSON.parse_string(FileAccess.get_file_as_string(TERRAIN + ".json"))
	if not about is Dictionary:
		return false
	_size = int(about["size"])
	_span = float(about["span"])
	_heights = FileAccess.get_file_as_bytes(TERRAIN + "_height.bin").to_float32_array()
	_masks = FileAccess.get_file_as_bytes(TERRAIN + "_masks.bin")
	if _heights.size() != _size * _size or _masks.size() != _size * _size * 4:
		return false
	_radii.resize(SAMPLES)
	var shore: Array = about["coast"]
	for i in SAMPLES:
		_radii[i] = float(shore[i % shore.size()])
	_waterfalls = about.get("waterfalls", [])
	return true


## Lays the ground: a mesh over the heights, and the painting of it.
func _build_ground() -> void:
	var across := int(_span / GROUND_STEP)
	var points := across + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(points * points)
	normals.resize(points * points)
	var half := _span * 0.5
	for row in points:
		var z := -half + row * GROUND_STEP
		for col in points:
			var x := -half + col * GROUND_STEP
			var k := row * points + col
			verts[k] = Vector3(x, _ground(x, z), z)
	for row in points:
		for col in points:
			var k := row * points + col
			var west := verts[k - 1].y if col > 0 else verts[k].y
			var east := verts[k + 1].y if col < across else verts[k].y
			var north := verts[k - points].y if row > 0 else verts[k].y
			var south := verts[k + points].y if row < across else verts[k].y
			normals[k] = Vector3(west - east, 2.0 * GROUND_STEP, north - south).normalized()
	# Only the land and the shallows round it are drawn; the deep is the sea's.
	var indices := PackedInt32Array()
	for row in across:
		for col in across:
			var k := row * points + col
			if maxf(maxf(verts[k].y, verts[k + 1].y),
					maxf(verts[k + points].y, verts[k + points + 1].y)) < -14.0:
				continue
			indices.append_array(PackedInt32Array(
					[k, k + 1, k + points + 1, k, k + points + 1, k + points]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("heights", ImageTexture.create_from_image(Image.create_from_data(
			_size, _size, false, Image.FORMAT_RF, _heights.to_byte_array())))
	mat.set_shader_parameter("masks", ImageTexture.create_from_image(Image.create_from_data(
			_size, _size, false, Image.FORMAT_RGBA8, _masks)))
	mat.set_shader_parameter("span", _span)
	mat.set_shader_parameter("texel", _span / _size)
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = mat
	add_child(ground)


## Height of the ground at a spot measured from the island's own middle.
func _ground(x: float, z: float) -> float:
	var fx := clampf((x + _span * 0.5) / _span * _size - 0.5, 0.0, _size - 1.001)
	var fz := clampf((z + _span * 0.5) / _span * _size - 0.5, 0.0, _size - 1.001)
	var col := int(fx)
	var row := int(fz)
	var k := row * _size + col
	var top := lerpf(_heights[k], _heights[k + 1], fx - col)
	var bottom := lerpf(_heights[k + _size], _heights[k + _size + 1], fx - col)
	return lerpf(top, bottom, fz - row)


## How steep the ground is there: rise over run (1 is forty-five degrees).
func _steepness(x: float, z: float) -> float:
	return Vector2(_ground(x + 1.5, z) - _ground(x - 1.5, z),
			_ground(x, z + 1.5) - _ground(x, z - 1.5)).length() / 3.0


## One of the maps that go with the heights, 0..1 (0 open sky, 1 sunlight,
## 2 running water, 3 hardness of the rock).
func _mask(x: float, z: float, which: int) -> float:
	var col := clampi(int((x + _span * 0.5) / _span * _size), 0, _size - 1)
	var row := clampi(int((z + _span * 0.5) / _span * _size), 0, _size - 1)
	return _masks[(row * _size + col) * 4 + which] / 255.0


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
	var lean := Basis.from_euler(Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(0.0, TAU),
			rng.randf_range(-0.14, 0.14)))
	var trunk := MeshInstance3D.new()
	trunk.mesh = _trunk_mesh
	trunk.transform = _trunk_transform(foot, height, lean)
	add_child(trunk)
	var crown := MeshInstance3D.new()
	crown.mesh = _crown_mesh
	crown.transform = Transform3D(lean, foot + lean.y * height)
	add_child(crown)


## Where a trunk of a given height stands, leaning as `lean` says.
func _trunk_transform(foot: Vector3, height: float, lean: Basis) -> Transform3D:
	return Transform3D(lean * Basis.from_scale(Vector3(0.26, height, 0.26)),
			foot + lean.y * height * 0.5)


## The head of a coconut palm: a ring of long fronds that arch up and droop.
func _frond_crown() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var out: Array[float] = [0.1, 1.3, 2.5, 3.3]
	var up: Array[float] = [0.25, 0.65, 0.15, -0.9]
	var wide: Array[float] = [0.26, 0.42, 0.3, 0.03]
	for k in 9:
		var a := TAU * k / 9.0
		var along := Vector3(cos(a), 0.0, sin(a))
		var across := Vector3(-sin(a), 0.0, cos(a))
		for n in out.size() - 1:
			var a0 := along * out[n] + Vector3.UP * up[n]
			var a1 := along * out[n + 1] + Vector3.UP * up[n + 1]
			var corners: Array[Vector3] = [
				a0 - across * wide[n], a0 + across * wide[n],
				a1 + across * wide[n + 1], a1 - across * wide[n + 1]]
			for index: int in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(corners[index])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _fronds)
	return mesh


## Forest on the mountain sides and breadfruit groves on the plain. Each
## tree is a clump of foliage, darker underneath; the grove trees stand on
## trunks. All of them are drawn in batches.
func _build_forest(forest_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed + 7
	var foliage := _clump_mesh()
	var leaves := Paint.material(Color(1.0, 1.0, 1.0), 0.4, 0.8)
	leaves.set_shader_parameter("shade_below", 0.55)
	leaves.set_shader_parameter("variation", 0.22)
	foliage.surface_set_material(0, leaves)

	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.use_colors = true
	crowns.mesh = foliage
	crowns.instance_count = TREES + GROVE_TREES
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = _trunk_mesh
	trunks.instance_count = GROVE_TREES
	for n in TREES + GROVE_TREES:
		var grove := n >= TREES
		var a := 0.0
		var r := 0.0
		var ground := 0.0
		# Try spots until one suits: groves on the plain, forest wherever the
		# ground is not too steep, thickest in the wet valleys and thinning
		# on the open ridges and toward the summits.
		for attempt in 12:
			a = rng.randf_range(0.0, TAU)
			var t := rng.randf_range(PLAIN_FROM + 0.01, 0.95) if grove \
					else sqrt(rng.randf_range(0.0, PLAIN_FROM * PLAIN_FROM))
			# Keep the landing beach open.
			if grove and absf(wrapf(a - keep_clear_angle, -PI, PI)) < 0.14:
				a += 0.3
			r = coast_radius(a) * t
			var x := cos(a) * r
			var z := sin(a) * r
			ground = _ground(x, z)
			if grove:
				break
			var liking := 1.15 - 0.55 * _mask(x, z, 0) + 0.6 * _mask(x, z, 2) - ground / 260.0
			if _steepness(x, z) < 1.25 and rng.randf() < liking:
				break
		# Trees are smaller the higher they stand, as they are, and it makes
		# the mountains look their size.
		var high := clampf(ground / 150.0, 0.0, 1.0)
		var size := rng.randf_range(2.6, 3.8) if grove \
				else rng.randf_range(1.9, 3.4) * lerpf(1.0, 0.45, high)
		var lift := rng.randf_range(3.5, 5.0) if grove else size * 0.35
		var shape := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)) \
				* Basis.from_scale(Vector3(size, size * rng.randf_range(0.75, 1.15), size))
		crowns.set_instance_transform(n, Transform3D(shape,
				Vector3(cos(a) * r, ground + lift, sin(a) * r)))
		var green := rng.randf_range(0.0, 1.0)
		var leaf := Color(0.05 + 0.07 * green, 0.14 + 0.11 * green, 0.045 + 0.02 * green) \
				.lerp(Color(0.20, 0.31, 0.11), 0.5 * high * green)
		if grove:
			leaf = Color(0.13 + 0.10 * green, 0.32 + 0.14 * green, 0.09)
			trunks.set_instance_transform(n - TREES, Transform3D(
					Basis.from_scale(Vector3(0.34, lift, 0.34)),
					Vector3(cos(a) * r, ground + lift * 0.5, sin(a) * r)))
		crowns.set_instance_color(n, leaf)
	for batch: MultiMesh in [crowns, trunks]:
		var stand := MultiMeshInstance3D.new()
		stand.multimesh = batch
		add_child(stand)


## The head of a tree: several rounded masses of leaves run together, so
## that no tree is a ball.
func _clump_mesh() -> ArrayMesh:
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var masses: Array[Vector4] = [
		Vector4(0.0, 0.0, 0.0, 0.85), Vector4(0.7, 0.2, 0.2, 0.62), Vector4(-0.62, 0.12, -0.38, 0.66),
		Vector4(0.1, 0.5, -0.55, 0.55), Vector4(-0.2, 0.52, 0.5, 0.58), Vector4(0.35, -0.1, -0.6, 0.5),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mass in masses:
		st.append_from(ball, 0, Transform3D(
				Basis.from_scale(Vector3(mass.w, mass.w * 0.8, mass.w)), Vector3(mass.x, mass.y, mass.z)))
	return st.commit()


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
	return _ground(world.x - position.x, world.y - position.z)


## Distance from the island's centre to the waterline along a world bearing
## given as an angle in the XZ plane (atan2(z, x)).
func coast_radius(angle: float) -> float:
	var f := wrapf(angle, 0.0, TAU) / TAU * SAMPLES
	var i := int(f) % SAMPLES
	var j := (i + 1) % SAMPLES
	return lerpf(_radii[i], _radii[j], f - floorf(f))


## Coconut palms all round the shore and across the plain, drawn as two
## batches: the trunks and the crowns.
func _build_palms(palm_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = palm_seed
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = _trunk_mesh
	trunks.instance_count = PALMS
	var crowns := MultiMesh.new()
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	crowns.mesh = _crown_mesh
	crowns.instance_count = PALMS
	for k in PALMS:
		var a := rng.randf_range(0.0, TAU)
		# Keep the landing beach open.
		if absf(wrapf(a - keep_clear_angle, -PI, PI)) < 0.14:
			a += 0.3
		var r := coast_radius(a) * rng.randf_range(0.84, 0.975)
		var world := Vector2(position.x + cos(a) * r, position.z + sin(a) * r)
		var foot := Vector3(cos(a) * r, surface_height(world) - 0.2, sin(a) * r)
		var height := rng.randf_range(8.0, 14.0)
		# Palms by the water lean out over it, toward the light.
		var out := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.0, 0.22)
		var lean := Basis.from_euler(Vector3(out.z + rng.randf_range(-0.08, 0.08),
				rng.randf_range(0.0, TAU), -out.x + rng.randf_range(-0.08, 0.08)))
		trunks.set_instance_transform(k, _trunk_transform(foot, height, lean))
		crowns.set_instance_transform(k, Transform3D(lean, foot + lean.y * height))
	for batch: MultiMesh in [trunks, crowns]:
		var grove := MultiMeshInstance3D.new()
		grove.multimesh = batch
		add_child(grove)


## A few waterfalls, in the deepest valleys.
func _build_waterfalls() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WATERFALL_SHADER
	for path: Array in _waterfalls:
		if path.size() < 3:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var fallen := 0.0
		var last := Vector3.ZERO
		for n in path.size():
			var here: Array = path[n]
			var mid := Vector3(here[0], float(here[1]) + 0.8, here[2])
			var onward: Array = path[mini(n + 1, path.size() - 1)]
			var back: Array = path[maxi(n - 1, 0)]
			var run := Vector3(float(onward[0]) - float(back[0]), 0.0,
					float(onward[2]) - float(back[2]))
			var across := Vector3(-run.z, 0.0, run.x).normalized() * 1.3
			if n > 0:
				fallen += mid.distance_to(last)
			last = mid
			st.set_uv(Vector2(0.0, fallen))
			st.add_vertex(mid - across)
			st.set_uv(Vector2(1.0, fallen))
			st.add_vertex(mid + across)
		for n in path.size() - 1:
			var p := n * 2
			for index: int in [0, 1, 3, 0, 3, 2]:
				st.add_index(p + index)
		st.generate_normals()
		var fall := MeshInstance3D.new()
		fall.mesh = st.commit()
		fall.material_override = mat
		fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fall)


## Villages on the plain: long thatched houses, open at the sides, with
## canoes drawn up on the beach before them and smoke from the cooking fires.
func _build_villages(village_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = village_seed + 31
	var thatch := Paint.material(Color(0.52, 0.45, 0.28), 0.35, 0.9)
	thatch.set_shader_parameter("shade_below", 0.3)
	var wood := Paint.material(Color(0.36, 0.24, 0.14), 0.3, 0.85)
	var near_landing := keep_clear_angle if keep_clear_angle < 100.0 else 4.5
	var sites: Array[float] = [near_landing + 0.42, near_landing - 0.5, 0.7, 2.5, 3.6]
	for site in sites:
		for n in 5:
			var a := site + rng.randf_range(-0.07, 0.07)
			var r := coast_radius(a) * rng.randf_range(0.86, 0.94)
			var world := Vector2(position.x + cos(a) * r, position.z + sin(a) * r)
			var foot := Vector3(cos(a) * r, surface_height(world), sin(a) * r)
			var house := Node3D.new()
			house.position = foot
			house.rotation.y = rng.randf_range(0.0, PI)
			add_child(house)
			# A long house: a steep thatched roof coming low over open sides,
			# held up on posts, with a rounded end.
			var long := rng.randf_range(6.0, 9.0)
			var roof := MeshInstance3D.new()
			var pitch := PrismMesh.new()
			pitch.size = Vector3(4.6, 2.3, long)
			roof.mesh = pitch
			roof.material_override = thatch
			roof.position = Vector3(0.0, 2.75, 0.0)
			house.add_child(roof)
			_lump(house, Vector3(2.2, 1.15, 1.4), Vector3(0.0, 2.2, long * 0.5), thatch)
			for post_x: float in [-1.8, 1.8]:
				for k in 4:
					_post(house, Vector3(post_x, 0.8, lerpf(-long * 0.45, long * 0.45, k / 3.0)),
							1.6, 0.08, wood)
			for post_z: float in [-0.3, 0.3]:
				_post(house, Vector3(0.0, 1.3, post_z * long), 2.6, 0.1, wood)
		# Canoes hauled up above the tide: a slim hull and an outrigger float.
		for n in 3:
			var a := site + (n - 1) * 0.035
			var r := coast_radius(a) * 0.985
			var world := Vector2(position.x + cos(a) * r, position.z + sin(a) * r)
			var canoe := Node3D.new()
			canoe.position = Vector3(cos(a) * r, surface_height(world) + 0.3, sin(a) * r)
			canoe.rotation.y = -a + rng.randf_range(-0.3, 0.3)
			add_child(canoe)
			_lump(canoe, Vector3(3.6, 0.3, 0.32), Vector3.ZERO, wood)
			_lump(canoe, Vector3(2.2, 0.1, 0.1), Vector3(0.0, -0.1, 1.5), wood)
			for boom: float in [-1.0, 1.0]:
				_post(canoe, Vector3(boom, 0.15, 0.75), 0.06, 0.05, wood).scale = Vector3(1.0, 1.0, 30.0)
		# Smoke from a cooking fire.
		var r_fire := coast_radius(site) * 0.9
		var smoke := CPUParticles3D.new()
		var puff_mat := StandardMaterial3D.new()
		puff_mat.albedo_color = Color(0.85, 0.85, 0.88, 0.3)
		puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		puff_mat.billboard_keep_scale = true
		puff_mat.albedo_texture = Paint.soft_dot()
		var puff := QuadMesh.new()
		puff.size = Vector2(5.0, 5.0)
		puff.material = puff_mat
		smoke.mesh = puff
		smoke.amount = 16
		smoke.lifetime = 14.0
		smoke.preprocess = 14.0
		smoke.direction = Vector3(0.3, 1.0, 0.1)
		smoke.spread = 12.0
		smoke.initial_velocity_min = 1.6
		smoke.initial_velocity_max = 2.6
		smoke.gravity = Vector3(0.25, 0.0, 0.1)
		smoke.scale_amount_min = 0.5
		smoke.scale_amount_max = 1.6
		var fire := Vector2(cos(site), sin(site)) * r_fire
		smoke.position = Vector3(fire.x,
				surface_height(Vector2(position.x, position.z) + fire) + 2.0, fire.y)
		add_child(smoke)


## Fort Venus, on the north point: the camp the ship's company built to
## guard the observatory for the transit. A ring of palisade, tents, and a flag.
func _build_fort() -> void:
	var a := TAU * 0.752
	var r := coast_radius(a) * 0.88
	var world := Vector2(position.x + cos(a) * r, position.z + sin(a) * r)
	var fort := Node3D.new()
	fort.position = Vector3(cos(a) * r, surface_height(world), sin(a) * r)
	add_child(fort)
	var timber := Paint.material(Color(0.42, 0.32, 0.20), 0.3, 0.85)
	var canvas := Paint.material(Color(0.86, 0.82, 0.70), 0.3, 0.8)
	for k in 30:
		var b := TAU * k / 30.0
		if k % 30 < 2:
			continue   # the gate
		_post(fort, Vector3(cos(b) * 10.0, 1.1, sin(b) * 10.0), 2.2, 0.16, timber)
	for k in 3:
		var tent := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(3.0, 2.2, 4.0)
		tent.mesh = prism
		tent.material_override = canvas
		tent.position = Vector3(-4.0 + 4.0 * k, 1.1, 1.5 * (k % 2))
		tent.rotation.y = 0.3 * k
		fort.add_child(tent)
	_post(fort, Vector3(0.0, 4.5, -5.0), 9.0, 0.07, timber)
	var flag := MeshInstance3D.new()
	var cloth := BoxMesh.new()
	cloth.size = Vector3(2.4, 1.4, 0.03)
	flag.mesh = cloth
	flag.material_override = Paint.material(Color(0.72, 0.10, 0.09), 0.3, 0.8)
	flag.position = Vector3(1.25, 8.2, -5.0)
	fort.add_child(flag)


## A rounded lump, given by its half-size along each axis.
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
	parent.add_child(inst)
	return inst


## An upright post, centred at `pos`.
func _post(parent: Node3D, pos: Vector3, height: float, radius: float,
		mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst
