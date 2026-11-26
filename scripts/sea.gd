class_name Sea
extends Node3D
## The surface of the sea: a finely divided patch of water that follows the
## ship, with a flat sheet beyond it out to the horizon. The same four swells
## that the shader draws are worked out here, so the ship can ride them.

const SHADER := preload("res://shaders/ocean.gdshader")
const SIZE := 2400.0   ## width of the patch that has real waves
const CELL := 6.0      ## size of one square of the patch
const CALM_HEIGHT := 0.45
const STORM_HEIGHT := 1.9
const FAR_DROP := -2.6  ## the far sheet sits below the deepest trough
## Each swell: direction x, direction z, wavelength (m), share of the height.
const WAVES: Array[Vector4] = [
	Vector4(0.80, 0.60, 95.0, 0.50),
	Vector4(0.28, 0.96, 60.0, 0.30),
	Vector4(0.95, -0.31, 37.0, 0.20),
	Vector4(-0.45, 0.89, 24.0, 0.12),
]

var sea_state: float = 0.0   ## 0 = easy swell, 1 = steep sea
var storm: float = 0.0       ## darkens the water
var sky_color := Color(0.85, 0.72, 0.55)
var time: float = 0.0

var _near: MeshInstance3D
var _far: MeshInstance3D
var _near_mat: ShaderMaterial
var _far_mat: ShaderMaterial


func _ready() -> void:
	var patch := PlaneMesh.new()
	patch.size = Vector2(SIZE, SIZE)
	patch.subdivide_width = int(SIZE / CELL) - 1
	patch.subdivide_depth = int(SIZE / CELL) - 1
	_near_mat = _material()
	_near = MeshInstance3D.new()
	_near.mesh = patch
	_near.material_override = _near_mat
	_near.extra_cull_margin = 10.0
	_near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_near)

	var sheet := PlaneMesh.new()
	sheet.size = Vector2(16000.0, 16000.0)
	_far_mat = _material()
	_far_mat.set_shader_parameter("wave_scale", 0.0)
	_far = MeshInstance3D.new()
	_far.mesh = sheet
	_far.material_override = _far_mat
	_far.position.y = FAR_DROP
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_far)


func _process(delta: float) -> void:
	time += delta
	for mat: ShaderMaterial in [_near_mat, _far_mat]:
		mat.set_shader_parameter("sea_time", time)
		mat.set_shader_parameter("storm", storm)
		mat.set_shader_parameter("sky_color", sky_color)
	_near_mat.set_shader_parameter("wave_scale", wave_height())


func wave_height() -> float:
	return lerpf(CALM_HEIGHT, STORM_HEIGHT, clampf(sea_state, 0.0, 1.0))


## Keeps the patch of waves under the ship. It moves a whole square at a
## time so the waves do not appear to slide.
func follow(centre: Vector3) -> void:
	_near.position = Vector3(snappedf(centre.x, CELL), 0.0, snappedf(centre.z, CELL))
	_far.position = Vector3(centre.x, FAR_DROP, centre.z)


## Height of the water (metres above the calm level) at a world position.
func height_at(x: float, z: float) -> float:
	var h := 0.0
	for w in WAVES:
		var k := TAU / w.z
		h += w.w * sin((w.x * x + w.y * z) * k - sqrt(9.81 * k) * time)
	return h * wave_height()


func set_reefs(reefs: Array[Vector3]) -> void:
	var packed := PackedVector3Array()
	packed.resize(8)
	for i in mini(reefs.size(), 8):
		packed[i] = reefs[i]
	_near_mat.set_shader_parameter("reefs", packed)
	_far_mat.set_shader_parameter("reefs", packed)


func _material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var packed := PackedFloat32Array()
	for w in WAVES:
		packed.append_array([w.x, w.y, w.z, w.w])
	mat.set_shader_parameter("waves", packed)
	mat.set_shader_parameter("half_size", SIZE * 0.5)
	return mat
