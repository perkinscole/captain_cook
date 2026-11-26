class_name Sea
extends Node3D
## The surface of the sea. Eight trains of waves: two long swells that come
## from far away and never change, and six wind waves that run before the
## local wind and grow as it blows harder. The shader draws them; the same
## sums are done here so the ship can ride them.
##
## One mesh covers the sea out to the horizon. Its points are close together
## near the ship and far apart in the distance.

const SHADER := preload("res://shaders/ocean.gdshader")
const REACH := 7000.0        ## how far the mesh runs from the ship, in metres
const GRID := 300            ## squares along each side of the mesh
const FINE := 0.0214         ## sets how close together the points are near the ship
const CHOP := 0.8            ## how sharp the crests are (0 = smooth, 1 = sharpest)
const WAVE_COUNT := 8
const GRAVITY := 9.81
# Swells: direction they travel (x, z), wavelength, height.
const SWELLS: Array[Vector4] = [
	Vector4(0.80, 0.60, 140.0, 0.24),
	Vector4(0.28, 0.96, 85.0, 0.13),
]
# Wind waves: degrees off the wind, wavelength, share of the wind-sea height.
const WIND_WAVES: Array[Vector3] = [
	Vector3(-34.0, 58.0, 0.30), Vector3(-17.0, 41.0, 0.22), Vector3(-5.0, 29.0, 0.16),
	Vector3(9.0, 19.0, 0.11), Vector3(23.0, 13.0, 0.07), Vector3(41.0, 9.0, 0.05),
]

var wind: Wind
var sea_state: float = 0.0   ## extra roughness from the weather, 0..1
var storm: float = 0.0       ## darkens the water
var sky_color := Color(0.62, 0.80, 0.95)
var time: float = 0.0

var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _anchor := Vector2.ZERO
var _next_anchor := Vector2.ZERO
var _wind_angle: float = 0.0     # smoothed direction the wind blows toward
var _wind_speed: float = 8.0     # smoothed
var _dir: Array[Vector2] = []
var _k: Array[float] = []
var _amp: Array[float] = []
var _phase: Array[float] = []


func _ready() -> void:
	for i in WAVE_COUNT:
		_dir.append(Vector2.RIGHT)
		_k.append(0.1)
		_amp.append(0.0)
		_phase.append(i * 1.7)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("chop", CHOP)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _build_mesh()
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	if wind != null:
		_wind_angle = (-Compass.to_vector(wind.from_deg)).angle()
		_wind_speed = wind.strength
	_update_waves(0.0)


func _process(delta: float) -> void:
	time += delta
	_update_waves(delta)
	_mat.set_shader_parameter("sea_time", time)
	_mat.set_shader_parameter("storm", storm)
	_mat.set_shader_parameter("sky_color", sky_color)


## Keeps the mesh centred on the ship.
func follow(centre: Vector3) -> void:
	_next_anchor = Vector2(centre.x, centre.z)


## Tells the sea where the ship is, so that it is not drawn inside her.
func set_hull(at: Vector3, heading_deg: float) -> void:
	var h := deg_to_rad(heading_deg)
	_mat.set_shader_parameter("hull", Vector4(at.x, at.z, sin(h), cos(h)))
	_mat.set_shader_parameter("has_hull", true)


## Height of the water (metres above the calm level) at a world position.
func height_at(x: float, z: float) -> float:
	# The waves push water sideways as well as up, so first find which bit
	# of water has been pushed to this spot, then ask how high it is.
	var p := Vector2(x, z)
	var q := p
	for step in 2:
		q = p - _sideways(q)
	var h := 0.0
	for i in WAVE_COUNT:
		h += _amp[i] * sin(_k[i] * _dir[i].dot(q - _anchor) + _phase[i])
	return h


## Paints the depth of water round the island into a picture the shader can
## read, so that shoals and reefs show pale and the shore has white water.
func set_depth_map(seabed: Seabed, centre: Vector2, size: float = 1800.0) -> void:
	var n := 256
	var image := Image.create_empty(n, n, false, Image.FORMAT_RF)
	for y in n:
		for x in n:
			var p := centre + (Vector2(x + 0.5, y + 0.5) / n - Vector2(0.5, 0.5)) * size
			image.set_pixel(x, y, Color(seabed.depth_at(p), 0.0, 0.0))
	_mat.set_shader_parameter("depth_map", ImageTexture.create_from_image(image))
	_mat.set_shader_parameter("has_depth_map", true)
	_mat.set_shader_parameter("map_centre", centre)
	_mat.set_shader_parameter("map_size", size)


func _sideways(q: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for i in WAVE_COUNT:
		push += _dir[i] * (CHOP * _amp[i] * cos(_k[i] * _dir[i].dot(q - _anchor) + _phase[i]))
	return push


func _update_waves(delta: float) -> void:
	var moved := _next_anchor - _anchor
	_anchor = _next_anchor
	_mesh.position = Vector3(_anchor.x, 0.0, _anchor.y)

	# The sea answers the wind slowly: it takes time to build and to turn.
	if wind != null:
		var toward := (-Compass.to_vector(wind.from_deg)).angle()
		_wind_angle = lerp_angle(_wind_angle, toward, 1.0 - exp(-delta / 20.0))
		_wind_speed = lerpf(_wind_speed, wind.strength, 1.0 - exp(-delta / 8.0))
	var force := _wind_speed / 8.0
	var wind_sea := clampf(force * force * 0.55, 0.12, 2.4) + 0.4 * sea_state
	var stretch := clampf(force, 0.7, 1.6)

	var packed_a := PackedFloat32Array()
	var packed_b := PackedFloat32Array()
	for i in WAVE_COUNT:
		var length := 1.0
		if i < SWELLS.size():
			var swell := SWELLS[i]
			_dir[i] = Vector2(swell.x, swell.y).normalized()
			length = swell.z
			_amp[i] = swell.w * (1.0 + 0.8 * sea_state)
		else:
			var w := WIND_WAVES[i - SWELLS.size()]
			_dir[i] = Vector2.RIGHT.rotated(_wind_angle + deg_to_rad(w.x))
			length = w.y * stretch
			_amp[i] = w.z * wind_sea
		_k[i] = TAU / length
		# Each wave moves on at its own speed. Moving the anchor must not
		# move the waves, so the phase is shifted to make up for it.
		var omega := sqrt(GRAVITY * _k[i])
		_phase[i] = fposmod(_phase[i] + _k[i] * _dir[i].dot(moved) - omega * delta, TAU)
		packed_a.append_array([_dir[i].x, _dir[i].y, _k[i], _amp[i]])
		packed_b.append_array([_phase[i], 0.0, 0.0, 0.0])
	_mat.set_shader_parameter("wave_a", packed_a)
	_mat.set_shader_parameter("wave_b", packed_b)
	_mat.set_shader_parameter("anchor", _anchor)


## A square sheet whose points bunch together in the middle. Each point also
## carries (in its UV) how far it is from its neighbours.
func _build_mesh() -> ArrayMesh:
	var line := PackedFloat32Array()
	var gap := PackedFloat32Array()
	for i in GRID + 1:
		var u := 2.0 * i / GRID - 1.0
		line.append(REACH * (FINE * u + (1.0 - FINE) * pow(u, 5.0)))
		gap.append(REACH * (FINE + 5.0 * (1.0 - FINE) * pow(u, 4.0)) * 2.0 / GRID)

	var points := PackedVector3Array()
	var spacing := PackedVector2Array()
	var indices := PackedInt32Array()
	points.resize((GRID + 1) * (GRID + 1))
	spacing.resize(points.size())
	indices.resize(GRID * GRID * 6)
	for row in GRID + 1:
		for col in GRID + 1:
			var at := row * (GRID + 1) + col
			points[at] = Vector3(line[col], 0.0, line[row])
			spacing[at] = Vector2(gap[col], gap[row])
	var next := 0
	for row in GRID:
		for col in GRID:
			var p := row * (GRID + 1) + col
			indices[next] = p
			indices[next + 1] = p + 1
			indices[next + 2] = p + GRID + 2
			indices[next + 3] = p
			indices[next + 4] = p + GRID + 2
			indices[next + 5] = p + GRID + 1
			next += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = spacing
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-REACH, -20.0, -REACH), Vector3(REACH * 2.0, 40.0, REACH * 2.0))
	return mesh
