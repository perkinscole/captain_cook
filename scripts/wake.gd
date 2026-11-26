class_name Wake
extends MeshInstance3D
## The white water the ship leaves behind her: a ribbon laid along her
## track that spreads and fades, and rises and falls with the waves.

const SHADER := preload("res://shaders/wake.gdshader")
const LIFE := 24.0           ## seconds before a stretch of wake has faded away
const STEP := 3.0            ## metres the ship moves between points
const START_WIDTH := 3.2     ## half the wake's width where it leaves the stern
const SPREAD := 1.3          ## metres wider on each side per second

var ship: Ship
var sea: Sea

var _points: Array[Dictionary] = []  # { at: Vector2, side: Vector2, born: float, strength: float }
var _time: float = 0.0
var _ribbon: ImmediateMesh


func _ready() -> void:
	_ribbon = ImmediateMesh.new()
	mesh = _ribbon
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if ship == null or sea == null:
		return
	_time += delta
	var fwd := ship.forward()
	# The wake begins just astern, so none of it lies inside the hull.
	var stern := Vector2(ship.position.x - fwd.x * 16.5, ship.position.z - fwd.z * 16.5)
	if _points.is_empty() or (_points[-1]["at"] as Vector2).distance_to(stern) > STEP:
		_points.append({
			"at": stern, "side": Vector2(-fwd.z, fwd.x), "born": _time,
			"strength": clampf(absf(ship.speed) / 5.0, 0.0, 1.0),
		})
	while not _points.is_empty() and _time - float(_points[0]["born"]) > LIFE:
		_points.remove_at(0)

	_ribbon.clear_surfaces()
	if _points.size() < 2:
		return
	_ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point in _points:
		var age: float = _time - float(point["born"])
		var at: Vector2 = point["at"]
		var side: Vector2 = point["side"]
		var half := START_WIDTH + SPREAD * age
		var fade: float = float(point["strength"]) * (1.0 - age / LIFE)
		for edge: float in [-1.0, 1.0]:
			var p := at + side * (half * edge)
			_ribbon.surface_set_color(Color(1.0, 1.0, 1.0, fade))
			_ribbon.surface_set_uv(Vector2(edge * 0.5 + 0.5, age * 4.0))
			_ribbon.surface_set_normal(Vector3.UP)
			_ribbon.surface_add_vertex(Vector3(p.x, sea.height_at(p.x, p.y) + 0.22, p.y))
	_ribbon.surface_end()
