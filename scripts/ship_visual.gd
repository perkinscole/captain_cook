class_name ShipVisual
extends Node3D
## The ship you can see, built in code: a rounded hull, a planked deck,
## three masts with yards, bellied sails and rigging. Child of a Ship.
## It shows how much canvas is set, braces the yards to the wind, fills the
## sails the right way (or the wrong way when she is taken aback), and
## flies a pennant that streams downwind.
##
## Endeavour was a Whitby collier: bluff-bowed, flat-bottomed and broad.
## This is a stand-in with that general shape, not a model of her.

const DECK_SHADER := preload("res://shaders/deck.gdshader")

const LENGTH := 31.0
const BOW_Z := -16.0
const HALF_BEAM := 4.0
const DECK_Y := 3.15
const RAIL_Y := 4.2
const KEEL_Y := -1.6
const STATIONS := 28
const SECTION_POINTS := 11

const MAST_Z: Array[float] = [-9.0, 0.0, 8.0]        # fore, main, mizzen
const MAST_HEIGHT: Array[float] = [26.0, 30.0, 22.0]
const TOP_AT := 0.46   # the platform partway up each mast, as a share of its height
# Tiers are listed in the order they are set: topsails, then courses, then topgallants.
const YARD_AT: Array[float] = [0.76, 0.44, 0.95]
const SAIL_DROP: Array[float] = [0.28, 0.28, 0.18]
const YARD_WIDTH: Array[float] = [10.5, 13.0, 7.5]
const FOOT_WIDTH: Array[float] = [12.5, 13.0, 10.0]
# Canvas (0..1) above which each tier is set. Topsails are reefed below 0.5.
const TIER_SET_ABOVE: Array[float] = [0.04, 0.6, 0.88]

var ship: Ship

var _yards: Array[Node3D] = []
var _sails: Array[MeshInstance3D] = []
var _sail_tier: Array[int] = []
var _fore_and_aft: Array[MeshInstance3D] = []
var _driver: Node3D
var _pennant: Node3D
var _time: float = 0.0
var _fill: float = 1.0

var _wood: StandardMaterial3D
var _dark: StandardMaterial3D
var _rope: StandardMaterial3D
var _canvas: StandardMaterial3D


func _ready() -> void:
	_wood = _material(Color(0.36, 0.25, 0.15))
	_dark = _material(Color(0.13, 0.10, 0.08))
	_rope = _material(Color(0.20, 0.16, 0.11))
	_canvas = _material(Color(1.0, 1.0, 1.0))
	_canvas.vertex_color_use_as_albedo = true

	_build_hull()
	_build_deck_fittings()
	for m in MAST_Z.size():
		_build_mast(m)
	_build_head_rig()


func _process(delta: float) -> void:
	if ship == null:
		return
	_time += delta
	var trim := ship.trim()
	var shiver := 0.07 if trim == Ship.Trim.SHIVERING or trim == Ship.Trim.ABACK else 0.0
	# Sails belly away from the wind. Taken aback, they press against the mast.
	var wanted_fill := 1.0
	if trim == Ship.Trim.ABACK:
		wanted_fill = -0.7
	elif trim == Ship.Trim.SHIVERING:
		wanted_fill = 0.25
	_fill = lerpf(_fill, wanted_fill, 1.0 - exp(-2.0 * delta))
	# Never quite flat: a sail with no depth at all cannot be drawn.
	var depth := _fill if absf(_fill) > 0.15 else (0.15 if _fill >= 0.0 else -0.15)

	for i in _sails.size():
		var sail := _sails[i]
		var tier := _sail_tier[i]
		sail.visible = ship.canvas > TIER_SET_ABOVE[tier]
		sail.rotation.y = shiver * sin(_time * 17.0 + float(i) * 1.3)
		sail.scale.z = depth
		if tier == 0:
			sail.scale.y = clampf(ship.canvas / 0.5, 0.25, 1.0)
	for sail in _fore_and_aft:
		sail.visible = ship.canvas > 0.04

	# Square before the wind, braced up sharp when close-hauled.
	var rel := ship.relative_wind_deg()
	var brace := signf(rel) * clampf((180.0 - absf(rel)) * 0.5, 0.0, 60.0)
	for yards in _yards:
		yards.rotation.y = lerp_angle(yards.rotation.y, deg_to_rad(brace), 0.05)
	_driver.rotation.y = lerp_angle(_driver.rotation.y, deg_to_rad(-signf(rel) * 18.0), 0.05)
	_pennant.rotation.y = -deg_to_rad(rel) + 0.12 * sin(_time * 6.0)
	_pennant.rotation.x = 0.06 * sin(_time * 9.0)


## Half the width of the hull at a point along it (0 = bow, 1 = stern).
func _half_breadth(u: float) -> float:
	var bow := pow(clampf(u / 0.16, 0.0, 1.0), 0.45)
	var stern := 1.0 - 0.22 * pow(clampf((u - 0.78) / 0.22, 0.0, 1.0), 2.0)
	return HALF_BEAM * bow * stern


func _build_hull() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Outer skin: a row of cross-sections from bow to stern, joined up.
	for i in STATIONS:
		var u := float(i) / (STATIONS - 1)
		var z := BOW_Z + u * LENGTH
		var b := _half_breadth(u)
		for j in SECTION_POINTS:
			var a := PI * j / (SECTION_POINTS - 1)
			var c := cos(a)
			var x := -b * signf(c) * pow(absf(c), 0.6)
			var y := RAIL_Y - (RAIL_Y - KEEL_Y) * pow(sin(a), 0.7)
			st.set_color(_hull_color(y))
			st.add_vertex(Vector3(x, y, z))
	for i in STATIONS - 1:
		for j in SECTION_POINTS - 1:
			var p := i * SECTION_POINTS + j
			_quad(st, p, p + SECTION_POINTS, p + SECTION_POINTS + 1, p + 1)
	# The flat stern.
	var last := (STATIONS - 1) * SECTION_POINTS
	var hub := STATIONS * SECTION_POINTS
	st.set_color(_hull_color(2.0))
	st.add_vertex(Vector3(0.0, 2.0, BOW_Z + LENGTH))
	for j in SECTION_POINTS - 1:
		st.add_index(hub)
		st.add_index(last + j)
		st.add_index(last + j + 1)
	st.generate_normals()
	var skin := _material(Color(1.0, 1.0, 1.0))
	skin.vertex_color_use_as_albedo = true
	_add(self, st.commit(), Vector3.ZERO, skin)

	# Inside of the bulwarks and the rail on top of them.
	var inner := SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STATIONS:
		var u := float(i) / (STATIONS - 1)
		var z := BOW_Z + u * LENGTH
		var b := _half_breadth(u)
		var b_in := maxf(b - 0.22, 0.0)
		for side: float in [-1.0, 1.0]:
			inner.add_vertex(Vector3(side * b_in, DECK_Y, z))
			inner.add_vertex(Vector3(side * b_in, RAIL_Y, z))
			inner.add_vertex(Vector3(side * b, RAIL_Y, z))
	for i in STATIONS - 1:
		for side in 2:
			var p := i * 6 + side * 3
			_quad(inner, p, p + 6, p + 7, p + 1)
			_quad(inner, p + 1, p + 7, p + 8, p + 2)
	inner.generate_normals()
	_add(self, inner.commit(), Vector3.ZERO, _wood)

	# The deck, planked by a shader.
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STATIONS:
		var u := float(i) / (STATIONS - 1)
		var z := BOW_Z + u * LENGTH
		var b_in := maxf(_half_breadth(u) - 0.22, 0.0)
		deck.add_vertex(Vector3(-b_in, DECK_Y, z))
		deck.add_vertex(Vector3(b_in, DECK_Y, z))
	for i in STATIONS - 1:
		var p := i * 2
		_quad(deck, p, p + 2, p + 3, p + 1)
	deck.generate_normals()
	var planks := ShaderMaterial.new()
	planks.shader = DECK_SHADER
	var deck_inst := _add(self, deck.commit(), Vector3.ZERO, planks)
	deck_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _hull_color(y: float) -> Color:
	if y > 3.3:
		return Color(0.60, 0.43, 0.20)   # varnished upper works
	if y > 2.6:
		return Color(0.10, 0.08, 0.07)   # the black wale
	if y > 0.3:
		return Color(0.30, 0.21, 0.13)   # tarred sides
	return Color(0.72, 0.69, 0.60)       # pale bottom, payed against worm


func _build_deck_fittings() -> void:
	var brass := _material(Color(0.75, 0.58, 0.22))
	brass.metallic = 0.7
	brass.roughness = 0.4

	# The wheel, just aft of where you stand, and the binnacle before it.
	_box(self, Vector3(0.16, 1.05, 0.34), Vector3(0.0, DECK_Y + 0.52, 12.95), _wood)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.44
	rim.outer_radius = 0.52
	var wheel := _add(self, rim, Vector3(0.0, DECK_Y + 1.1, 12.72), _wood)
	wheel.rotation.x = PI * 0.5
	for k in 4:
		var spoke := _box(self, Vector3(1.3, 0.05, 0.05), Vector3(0.0, DECK_Y + 1.1, 12.72), _wood)
		spoke.rotation.z = PI * k / 4.0
	_box(self, Vector3(0.55, 0.95, 0.45), Vector3(0.0, DECK_Y + 0.47, 12.2), _wood)
	_box(self, Vector3(0.3, 0.06, 0.3), Vector3(0.0, DECK_Y + 0.97, 12.2), brass)

	# Hatches with gratings, the capstan, and the bell forward.
	_box(self, Vector3(2.4, 0.26, 3.2), Vector3(0.0, DECK_Y + 0.13, -4.8), _dark)
	_box(self, Vector3(1.8, 0.26, 2.0), Vector3(0.0, DECK_Y + 0.13, 4.9), _dark)
	_cylinder(self, 0.42, 0.55, 1.0, Vector3(0.0, DECK_Y + 0.5, 2.2), _wood)
	_cylinder(self, 0.72, 0.72, 0.2, Vector3(0.0, DECK_Y + 1.1, 2.2), _wood)
	_box(self, Vector3(0.14, 1.5, 0.14), Vector3(-0.5, DECK_Y + 0.75, -12.0), _wood)
	_box(self, Vector3(0.14, 1.5, 0.14), Vector3(0.5, DECK_Y + 0.75, -12.0), _wood)
	_box(self, Vector3(1.3, 0.14, 0.2), Vector3(0.0, DECK_Y + 1.55, -12.0), _wood)
	_cylinder(self, 0.1, 0.2, 0.3, Vector3(0.0, DECK_Y + 1.3, -12.0), brass)

	# The stern lantern. It glows when the weather darkens.
	_box(self, Vector3(0.1, 1.2, 0.1), Vector3(0.0, RAIL_Y + 0.6, 14.8), _dark)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.75, 0.35)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.62, 0.25)
	glass.emission_energy_multiplier = 2.5
	_box(self, Vector3(0.34, 0.45, 0.34), Vector3(0.0, RAIL_Y + 1.4, 14.8), glass)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.68, 0.35)
	glow.light_energy = 1.4
	glow.omni_range = 11.0
	glow.position = Vector3(0.0, RAIL_Y + 1.4, 14.4)
	add_child(glow)


func _build_mast(m: int) -> void:
	var z := MAST_Z[m]
	var h := MAST_HEIGHT[m]
	var size := h / 30.0
	var top_y := DECK_Y + h * TOP_AT

	_cylinder(self, 0.3, 0.4, h * 0.5, Vector3(0.0, DECK_Y + h * 0.25, z), _wood)
	_cylinder(self, 1.25 * size, 1.25 * size, 0.14, Vector3(0.0, top_y, z), _wood)
	_cylinder(self, 0.17, 0.25, h * 0.36, Vector3(0.0, DECK_Y + h * 0.62, z - 0.25), _wood)
	_cylinder(self, 0.08, 0.15, h * 0.22, Vector3(0.0, DECK_Y + h * 0.89, z - 0.1), _wood)

	# Shrouds: the ropes that hold the mast up from either side.
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var foot_z := z + 0.5 + 0.9 * k
			var foot_u := (foot_z - BOW_Z) / LENGTH
			_line(Vector3(side * 0.9 * size, top_y, z),
					Vector3(side * (_half_breadth(foot_u) + 0.05), RAIL_Y, foot_z), 0.035)
		_line(Vector3(side * 0.2, DECK_Y + h * 0.78, z - 0.25),
				Vector3(side * 1.15 * size, top_y + 0.1, z + 0.2), 0.025)
	# A stay running forward and down from the top.
	var stay_foot := Vector3(0.0, DECK_Y + 1.0, z - 8.4) if m > 0 else Vector3(0.0, 5.0, -19.5)
	_line(Vector3(0.0, top_y, z - 0.3), stay_foot, 0.04)

	var yards := Node3D.new()
	yards.position = Vector3(0.0, DECK_Y, z)
	add_child(yards)
	_yards.append(yards)
	for t in YARD_AT.size():
		if m == 2 and t == 1:
			continue  # the mizzen carries no course, only a bare yard
		var yard_y := h * YARD_AT[t]
		var yard := _cylinder(yards, 0.09 * size, 0.09 * size, YARD_WIDTH[t] * size + 1.2,
				Vector3(0.0, yard_y, -0.45), _wood)
		yard.rotation.z = PI * 0.5
		var sail := _add(yards, _square_sail(YARD_WIDTH[t] * size, FOOT_WIDTH[t] * size,
				h * SAIL_DROP[t]), Vector3(0.0, yard_y - 0.1, -0.5), _canvas)
		_sails.append(sail)
		_sail_tier.append(t)

	if m == 2:
		# The driver: a fore-and-aft sail set abaft the mizzen, over your head.
		_driver = Node3D.new()
		_driver.position = Vector3(0.0, 0.0, z + 0.4)
		add_child(_driver)
		var driver := _add(_driver, _flat_sail(PackedVector3Array([
			Vector3(0.0, 6.7, 0.0), Vector3(0.0, 7.0, 6.2),
			Vector3(0.0, 15.0, 4.6), Vector3(0.0, 12.8, 0.0),
		])), Vector3.ZERO, _canvas)
		_fore_and_aft.append(driver)
		_line(Vector3(0.0, 12.8, z + 0.4), Vector3(0.0, 15.2, z + 5.2), 0.07, _wood)


func _build_head_rig() -> void:
	# Bowsprit, a jib set on it, and the pennant at the main masthead.
	_line(Vector3(0.0, 4.4, -15.0), Vector3(0.0, 6.4, -25.0), 0.24, _wood)
	var fore_top := DECK_Y + MAST_HEIGHT[0] * 0.78
	_line(Vector3(0.0, fore_top, MAST_Z[0] - 0.25), Vector3(0.0, 6.3, -24.6), 0.035)
	var jib := _add(self, _flat_sail(PackedVector3Array([
		Vector3(0.0, 6.0, -23.0), Vector3(0.0, fore_top - 2.5, -10.8),
		Vector3(0.0, 5.6, -12.0), Vector3(0.0, 5.8, -17.5),
	])), Vector3.ZERO, _canvas)
	_fore_and_aft.append(jib)

	_pennant = Node3D.new()
	_pennant.position = Vector3(0.0, DECK_Y + MAST_HEIGHT[1] + 0.3, MAST_Z[1] - 0.1)
	add_child(_pennant)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.75, 0.12, 0.10))
	st.add_vertex(Vector3(0.0, 0.3, 0.0))
	st.add_vertex(Vector3(0.0, -0.3, 0.0))
	st.add_vertex(Vector3(0.0, 0.0, 6.5))
	st.generate_normals()
	_add(_pennant, st.commit(), Vector3.ZERO, _canvas)


## A square sail hanging from its yard (the origin is the middle of the
## yard), bellied forward, with panels of slightly different cloth.
func _square_sail(head: float, foot: float, drop: float) -> ArrayMesh:
	var across := 9
	var down := 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in down:
		var v := float(r) / (down - 1)
		for c in across:
			var u := float(c) / (across - 1)
			var width := lerpf(head, foot, v)
			var belly := 0.09 * width * sin(PI * u) * (0.3 + 0.7 * sin(PI * v))
			var roach := 0.05 * drop * sin(PI * u) * v
			var shade := 0.90 if c % 2 == 0 else 0.97
			st.set_color(Color(0.88 * shade, 0.82 * shade, 0.68 * shade))
			st.add_vertex(Vector3((u - 0.5) * width, -drop * v + roach, -belly))
	for r in down - 1:
		for c in across - 1:
			var p := r * across + c
			_quad(st, p, p + across, p + across + 1, p + 1)
	st.generate_normals()
	return st.commit()


## A fore-and-aft sail given by its four corners.
func _flat_sail(corners: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(0.84, 0.78, 0.64))
	for corner in corners:
		st.add_vertex(corner)
	_quad(st, 0, 1, 2, 3)
	st.generate_normals()
	return st.commit()


func _quad(st: SurfaceTool, a: int, b: int, c: int, d: int) -> void:
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)
	st.add_index(a)
	st.add_index(c)
	st.add_index(d)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, mat)


func _cylinder(parent: Node3D, top: float, bottom: float, height: float, pos: Vector3,
		mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	return _add(parent, mesh, pos, mat)


## A rope or spar from one point to another.
func _line(from: Vector3, to: Vector3, radius: float, mat: Material = null) -> void:
	var span := to - from
	var inst := _cylinder(self, radius, radius, span.length(), (from + to) * 0.5,
			mat if mat != null else _rope)
	inst.basis = Basis(Quaternion(Vector3.UP, span.normalized()))
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
