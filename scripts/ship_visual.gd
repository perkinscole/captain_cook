class_name ShipVisual
extends Node3D
## Placeholder ship made of boxes and cylinders. Child of a Ship.
## Shows the sail setting and braces the yards to the wind.

const MAST_Z: Array[float] = [-9.0, 0.0, 8.0]        # fore, main, mizzen
const MAST_HEIGHT: Array[float] = [26.0, 30.0, 22.0]
# Tiers are listed in the order they are set: topsails, then courses, then topgallants.
const TIER_HEIGHT: Array[float] = [0.55, 0.28, 0.80]  # fraction of mast height
const TIER_WIDTH: Array[float] = [11.0, 13.0, 8.0]

var ship: Ship

var _yards: Array[Node3D] = []
var _tiers: Array[Array] = [[], [], []]


func _ready() -> void:
	var wood := _material(Color(0.33, 0.22, 0.13))
	var deck := _material(Color(0.62, 0.52, 0.36))
	var canvas := _material(Color(0.90, 0.86, 0.74))

	_box(self, Vector3(8.0, 4.0, 30.0), Vector3(0.0, 1.0, 0.0), wood)       # hull
	_box(self, Vector3(7.6, 0.2, 29.6), Vector3(0.0, 3.05, 0.0), deck)      # deck
	_box(self, Vector3(8.0, 1.0, 0.3), Vector3(0.0, 3.6, 14.85), wood)      # taffrail
	_box(self, Vector3(0.3, 1.0, 30.0), Vector3(-3.85, 3.6, 0.0), wood)     # port rail
	_box(self, Vector3(0.3, 1.0, 30.0), Vector3(3.85, 3.6, 0.0), wood)      # starboard rail
	_box(self, Vector3(0.5, 0.5, 9.0), Vector3(0.0, 4.6, -18.5), wood)      # bowsprit

	for m in MAST_Z.size():
		var mast := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 0.4
		cyl.height = MAST_HEIGHT[m]
		mast.mesh = cyl
		mast.material_override = wood
		mast.position = Vector3(0.0, 3.0 + MAST_HEIGHT[m] * 0.5, MAST_Z[m])
		add_child(mast)

		var yards := Node3D.new()
		yards.position = Vector3(0.0, 3.0, MAST_Z[m])
		add_child(yards)
		_yards.append(yards)

		for t in TIER_HEIGHT.size():
			var scale_w := MAST_HEIGHT[m] / 30.0
			var y := MAST_HEIGHT[m] * TIER_HEIGHT[t]
			var sail_mesh := _box(yards, Vector3(TIER_WIDTH[t] * scale_w, 6.0, 0.15),
					Vector3(0.0, y, -0.5), canvas)
			_box(yards, Vector3(TIER_WIDTH[t] * scale_w + 1.0, 0.25, 0.25),
					Vector3(0.0, y + 3.1, -0.5), wood)  # the yard itself
			_tiers[t].append(sail_mesh)


func _process(_delta: float) -> void:
	if ship == null:
		return
	for t in _tiers.size():
		for sail_mesh: MeshInstance3D in _tiers[t]:
			sail_mesh.visible = ship.sail > t

	# Square before the wind, braced up sharp when close-hauled.
	var rel := ship.relative_wind_deg()
	var brace := signf(rel) * clampf((180.0 - absf(rel)) * 0.5, 0.0, 60.0)
	for yards in _yards:
		yards.rotation.y = lerp_angle(yards.rotation.y, deg_to_rad(brace), 0.05)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst
