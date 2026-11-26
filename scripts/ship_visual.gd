class_name ShipVisual
extends Node3D
## The ship you can see and walk about, built in code from ShipLayout.
##
## She is modelled on HM Bark Endeavour, a Whitby collier: bluff bows, a
## flat floor, a square stern with windows, a raised forecastle and
## quarterdeck with the great cabin beneath it, three masts, boats stowed
## over the waist and a handful of guns. It is a likeness built from simple
## shapes, not a measured model, and the proportions are stretched a little
## so that there is room to walk.
##
## It also shows the state of the ship: how much canvas is set, how the
## yards are braced, which way the sails fill, and where the wind is.

const DECK_SHADER := preload("res://shaders/deck.gdshader")
const SHELL_SHADER := preload("res://shaders/hull_shell.gdshader")
## How the modelled hull is stretched to wrap round this ship: metres per
## unit of the model along her length, height and beam, then how far up and
## aft its middle sits. The same numbers are in hull_shell.gdshader.
const SHELL_FIT := Vector3(16.6, 15.5, 14.6)
const SHELL_UP := 2.54
const SHELL_AFT := -0.5

const DECK_Y := ShipLayout.WAIST_Y   # the masts are measured from the waist
const STATIONS := 44
const SECTION_POINTS := 13

const MAST_Z: Array[float] = [-9.0, 0.0, 8.0]        # fore, main, mizzen
const MAST_HEIGHT: Array[float] = [26.0, 30.0, 22.0]
const TOP_AT := 0.46   # the platform partway up each mast, as a share of its height
# Tiers are listed in the order they are set: topsails, then courses, then topgallants.
const YARD_AT: Array[float] = [0.76, 0.44, 0.95]
const SAIL_DROP: Array[float] = [0.28, 0.28, 0.18]
const YARD_WIDTH: Array[float] = [10.5, 13.0, 7.5]
const FOOT_WIDTH: Array[float] = [12.5, 13.0, 10.0]
# The canvas (0..1) at which each tier starts to be let fall, and is fully set.
const TIER_FROM: Array[float] = [0.04, 0.5, 0.78]
const TIER_TO: Array[float] = [0.5, 0.78, 1.0]

var ship: Ship

var _yards: Array[Node3D] = []
var _sails: Array[MeshInstance3D] = []
var _sail_tier: Array[int] = []
var _furls: Array[MeshInstance3D] = []   # the rolled-up sail on each yard
# Where a man climbs to reach each mast's top: [mast][0 = port, 1 = starboard]
# is [foot of the shrouds, head of the shrouds], in the ship's space.
var _climbs: Array = [[], [], []]
var _fore_and_aft: Array[MeshInstance3D] = []
var _driver: Node3D
var _pennant: Node3D
var _ensign: Node3D
var _wheel: Node3D
var _shell: Node3D            # the modelled outer hull, if there is one
var _skin: MeshInstance3D     # the code-built outer hull
var _skin_both_sides: ShaderMaterial
var _skin_inside_only: ShaderMaterial
var _time: float = 0.0
var _fill: float = 1.0
var _rig: SurfaceTool

var _wood: ShaderMaterial
var _dark: ShaderMaterial
var _ochre: ShaderMaterial
var _red: ShaderMaterial
var _cream: ShaderMaterial
var _iron: ShaderMaterial
var _brass: ShaderMaterial
var _rope: ShaderMaterial
var _canvas: ShaderMaterial
var _planks: ShaderMaterial


func _ready() -> void:
	_wood = _material(Color(0.38, 0.26, 0.15))
	_dark = _material(Color(0.12, 0.09, 0.07))
	_ochre = _material(Color(0.66, 0.50, 0.22))
	_red = _material(Color(0.48, 0.14, 0.10))
	_cream = _material(Color(0.80, 0.76, 0.62))
	_iron = _material(Color(0.07, 0.07, 0.08))
	_iron.set_shader_parameter("roughness", 0.45)
	_brass = _material(Color(0.75, 0.58, 0.22))
	_brass.set_shader_parameter("metallic", 0.7)
	_brass.set_shader_parameter("roughness", 0.35)
	_rope = _material(Color(0.17, 0.13, 0.09))
	_canvas = _material(Color(1.0, 1.0, 1.0))
	_canvas.set_shader_parameter("stroke", 0.5)   # broad strokes for the sails
	_planks = ShaderMaterial.new()
	_planks.shader = DECK_SHADER

	_rig = SurfaceTool.new()
	_rig.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_hull()
	_build_shell()
	_build_decks()
	_build_stern()
	_build_ladders_and_rails()
	_build_quarterdeck()
	_build_waist()
	_build_forecastle()
	_build_great_cabin()
	_build_lower_deck()
	for m in MAST_Z.size():
		_build_mast(m)
	_build_head_rig()
	_build_flags()
	_rig.generate_normals()
	var rigging := _add(self, _rig.commit(), Vector3.ZERO, _rope)
	rigging.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
		# Each sail is let fall from its yard as the hands set it, and
		# gathered up again when they take it in.
		var let_fall := clampf(
				(ship.canvas - TIER_FROM[tier]) / (TIER_TO[tier] - TIER_FROM[tier]), 0.0, 1.0)
		sail.visible = let_fall > 0.02
		_furls[i].visible = let_fall <= 0.02
		sail.rotation.y = shiver * sin(_time * 17.0 + float(i) * 1.3)
		sail.scale.z = depth
		sail.scale.y = maxf(let_fall, 0.05)
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
	_ensign.rotation.y = -deg_to_rad(rel) + 0.2 * sin(_time * 4.0)
	_wheel.rotation.z = lerp_angle(_wheel.rotation.z, -ship.rudder * 2.5, 0.1)


# --- hull and decks --------------------------------------------------------

func _build_hull() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Outer skin: a row of cross-sections from bow to stern, joined up.
	for i in STATIONS:
		var z := ShipLayout.BOW_Z + ShipLayout.LENGTH * i / (STATIONS - 1)
		var b := ShipLayout.half_breadth(z)
		var top := ShipLayout.rail_y(z)
		for j in SECTION_POINTS:
			var a := PI * j / (SECTION_POINTS - 1)
			var c := cos(a)
			var x := -b * signf(c) * pow(absf(c), 0.5)   # wall-sided and flat-floored
			var y := top - (top - ShipLayout.KEEL_Y) * pow(sin(a), 0.75)
			st.set_color(_hull_color(y, top))
			st.add_vertex(Vector3(x, y, z))
	for i in STATIONS - 1:
		for j in SECTION_POINTS - 1:
			var p := i * SECTION_POINTS + j
			_quad(st, p, p + SECTION_POINTS, p + SECTION_POINTS + 1, p + 1)
	st.generate_normals()
	_skin_both_sides = _material(Color(1.0, 1.0, 1.0))
	# The same paint, but drawn only on the inside of the planking: used when
	# the modelled hull is wrapped round her, so that this one does not poke
	# out through it, while the lower deck still has walls.
	var inside := Shader.new()
	inside.code = Paint.SHADER.code.replace("render_mode cull_disabled;", "render_mode cull_front;")
	_skin_inside_only = ShaderMaterial.new()
	_skin_inside_only.shader = inside
	_skin_inside_only.set_shader_parameter("tint", Color(0.8, 0.7, 0.55))
	_skin = _add(self, st.commit(), Vector3.ZERO, _skin_both_sides)

	# Inside of the bulwarks (painted red, as was the custom) and the rail
	# on top of them. Aft, the same wall runs down to line the great cabin.
	var inner := SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lining := SurfaceTool.new()
	lining.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STATIONS:
		var z := ShipLayout.BOW_Z + ShipLayout.LENGTH * i / (STATIONS - 1)
		var b := ShipLayout.half_breadth(z)
		var b_in := maxf(b - 0.22, 0.0)
		var top := ShipLayout.rail_y(z)
		for side: float in [-1.0, 1.0]:
			inner.add_vertex(Vector3(side * b_in, ShipLayout.deck_top(z), z))
			inner.add_vertex(Vector3(side * b_in, top, z))
			cap.add_vertex(Vector3(side * b_in, top, z))
			cap.add_vertex(Vector3(side * (b + 0.06), top, z))
			lining.add_vertex(Vector3(side * b_in, ShipLayout.WAIST_Y, z))
			lining.add_vertex(Vector3(side * b_in, ShipLayout.QUARTERDECK_Y, z))
	for i in STATIONS - 1:
		for side in 2:
			var p := i * 4 + side * 2
			_quad(inner, p, p + 4, p + 5, p + 1)
			_quad(cap, p, p + 4, p + 5, p + 1)
			# Only the stretch under the quarterdeck is lined: the great cabin.
			var z_here := ShipLayout.BOW_Z + ShipLayout.LENGTH * i / (STATIONS - 1)
			if z_here >= ShipLayout.QUARTERDECK_BREAK_Z - 0.4:
				_quad(lining, p, p + 4, p + 5, p + 1)
	inner.generate_normals()
	cap.generate_normals()
	_add(self, inner.commit(), Vector3.ZERO, _red)
	_add(self, cap.commit(), Vector3.ZERO, _dark)
	lining.generate_normals()
	_add(self, lining.commit(), Vector3.ZERO, _cream)


## Wraps the modelled hull round the ship as an outer shell, if the model is
## there. It lies along its own X with the bow toward -X, so it is turned
## and stretched to lie along the ship.
func _build_shell() -> void:
	if not Models.has(Models.HULL):
		return
	var scene := load(Models.HULL) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	_shell = Node3D.new()
	_shell.transform = Transform3D(
			Basis(Vector3(0.0, 0.0, SHELL_FIT.x), Vector3(0.0, SHELL_FIT.y, 0.0),
					Vector3(-SHELL_FIT.z, 0.0, 0.0)),
			Vector3(0.0, SHELL_UP, SHELL_AFT))
	add_child(_shell)
	_shell.add_child(model)
	for part in Models.meshes_of(model):
		var picture := Models.picture_of(part)
		if picture == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = SHELL_SHADER
		mat.set_shader_parameter("picture", picture)
		mat.set_shader_parameter("fit_scale", SHELL_FIT)
		mat.set_shader_parameter("fit_up", SHELL_UP)
		mat.set_shader_parameter("fit_aft", SHELL_AFT)
		part.material_override = mat
	show_shell(true)


## Shows the modelled outer hull, or goes back to the code-built one.
func show_shell(on: bool) -> bool:
	if _shell == null:
		return false
	_shell.visible = on
	_skin.material_override = _skin_inside_only if on else _skin_both_sides
	return on


func has_shell() -> bool:
	return _shell != null


func shell_shown() -> bool:
	return _shell != null and _shell.visible


## Stands a modelled fitting on the ship: scaled so that it measures `size`
## metres along `axis` (0 = x, 1 = y, 2 = z of the model), turned by `turn`,
## with the middle of its base at `at`. Returns null if the model is missing,
## so that the caller can build the code version instead.
func _fitting(path: String, axis: int, size: float, at: Vector3, turn: Basis) -> Node3D:
	if not Models.has(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	var box := AABB()
	var first := true
	for part in Models.meshes_of(model):
		box = part.get_aabb() if first else box.merge(part.get_aabb())
		first = false
		var picture := Models.picture_of(part)
		if picture != null:
			var mat := Paint.textured(picture)
			mat.set_shader_parameter("variation", 0.1)
			mat.set_shader_parameter("relief", 0.8)
			part.material_override = mat
	if first or box.size[axis] <= 0.0:
		model.free()
		return null
	var scale_by := size / box.size[axis]
	# Put the middle of the model's base at the holder's origin, then turn
	# and place the holder.
	var holder := Node3D.new()
	holder.transform = Transform3D(turn, at)
	add_child(holder)
	model.scale = Vector3(scale_by, scale_by, scale_by)
	var middle := box.get_center()
	model.position = -Vector3(middle.x, box.position.y, middle.z) * scale_by
	holder.add_child(model)
	return holder


func _hull_color(y: float, top: float) -> Color:
	if y > top - 0.9:
		return Color(0.64, 0.47, 0.20)   # ochre upper works
	if y > 2.3 and y < 2.95:
		return Color(0.07, 0.06, 0.05)   # the black wale
	if y > 0.25:
		return Color(0.36, 0.24, 0.13)   # oiled sides
	return Color(0.76, 0.73, 0.64)       # pale bottom, payed against worm


func _build_decks() -> void:
	# The main deck runs her whole length: the waist in the open, and aft of
	# it the floor of the great cabin. The forecastle and quarterdeck sit above.
	# The main deck has a hatch cut in it for the ladder to the lower deck.
	var hatch_port := ShipLayout.COMPANION_X - ShipLayout.COMPANION_HALF_WIDTH
	var hatch_starboard := ShipLayout.COMPANION_X + ShipLayout.COMPANION_HALF_WIDTH
	var hatch_fore := minf(ShipLayout.COMPANION_FOOT_Z, ShipLayout.COMPANION_HEAD_Z)
	var hatch_aft := maxf(ShipLayout.COMPANION_FOOT_Z, ShipLayout.COMPANION_HEAD_Z)
	_deck(ShipLayout.BOW_Z + 0.6, hatch_fore, ShipLayout.WAIST_Y)
	_deck(hatch_fore, hatch_aft, ShipLayout.WAIST_Y, -99.0, hatch_port)
	_deck(hatch_fore, hatch_aft, ShipLayout.WAIST_Y, hatch_starboard, 99.0)
	_deck(hatch_aft, ShipLayout.STERN_Z, ShipLayout.WAIST_Y)
	_deck(ShipLayout.BOW_Z + 0.6, ShipLayout.FORECASTLE_BREAK_Z, ShipLayout.FORECASTLE_Y)
	_deck(ShipLayout.QUARTERDECK_BREAK_Z, ShipLayout.STERN_Z, ShipLayout.QUARTERDECK_Y)
	_deck(ShipLayout.LOWER_FORE_Z - 0.6, ShipLayout.LOWER_AFT_Z + 0.3, ShipLayout.LOWER_Y,
			-99.0, 99.0, 0.94)

	# The wall under the after end of the forecastle.
	var fb := ShipLayout.half_breadth(ShipLayout.FORECASTLE_BREAK_Z) - 0.22
	var f_mid := (ShipLayout.WAIST_Y + ShipLayout.FORECASTLE_Y) * 0.5
	_box(self, Vector3(fb * 2.0, ShipLayout.FORECASTLE_Y - ShipLayout.WAIST_Y, 0.12),
			Vector3(0.0, f_mid, ShipLayout.FORECASTLE_BREAK_Z), _ochre)

	# The bulkhead under the front of the quarterdeck, with the cabin door.
	var qb := ShipLayout.half_breadth(ShipLayout.QUARTERDECK_BREAK_Z) - 0.22
	var rise := ShipLayout.QUARTERDECK_Y - ShipLayout.WAIST_Y
	var q_mid := ShipLayout.WAIST_Y + rise * 0.5
	var door := ShipLayout.DOOR_HALF_WIDTH
	var panel := qb - door
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(panel, rise, 0.12),
				Vector3(side * (door + panel * 0.5), q_mid, ShipLayout.QUARTERDECK_BREAK_Z), _ochre)
		_box(self, Vector3(0.1, ShipLayout.DOOR_HEIGHT, 0.16), Vector3(side * door,
				ShipLayout.WAIST_Y + ShipLayout.DOOR_HEIGHT * 0.5, ShipLayout.QUARTERDECK_BREAK_Z), _dark)
	var lintel := rise - ShipLayout.DOOR_HEIGHT
	_box(self, Vector3(door * 2.0, lintel, 0.12), Vector3(0.0,
			ShipLayout.QUARTERDECK_Y - lintel * 0.5, ShipLayout.QUARTERDECK_BREAK_Z), _ochre)


## One stretch of planked deck, from side to side of the hull, or only
## between two lines either side of the middle. `narrow` allows for the
## hull being slimmer low down.
func _deck(from_z: float, to_z: float, y: float, port: float = -99.0, starboard: float = 99.0,
		narrow: float = 1.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	for i in steps + 1:
		var z := lerpf(from_z, to_z, float(i) / steps)
		var b_in := maxf(ShipLayout.half_breadth(z) * narrow - 0.22, 0.0)
		st.add_vertex(Vector3(clampf(port, -b_in, b_in), y, z))
		st.add_vertex(Vector3(clampf(starboard, -b_in, b_in), y, z))
	for i in steps:
		var p := i * 2
		_quad(st, p, p + 1, p + 3, p + 2)
	st.generate_normals()
	_add(self, st.commit(), Vector3.ZERO, _planks)


func _build_stern() -> void:
	var z := ShipLayout.STERN_Z
	var b := ShipLayout.half_breadth(z)
	var top := ShipLayout.rail_y(z)
	var sill := ShipLayout.WAIST_Y + 0.75    # bottom of the cabin windows
	var head := ShipLayout.WAIST_Y + 1.7     # top of them

	# Below the windows the stern is planked across.
	_box(self, Vector3(b * 2.0, sill - 1.8, 0.14), Vector3(0.0, (sill + 1.8) * 0.5, z), _wood)
	_box(self, Vector3(b * 1.75, 2.0, 0.14), Vector3(0.0, 0.8, z), _wood)
	_box(self, Vector3(b * 1.25, 1.6, 0.14), Vector3(0.0, -0.9, z), _wood)
	# The row of five windows of the great cabin, and the upper stern above.
	_box(self, Vector3(b * 2.0 + 0.2, 0.14, 0.24), Vector3(0.0, sill, z), _ochre)
	_box(self, Vector3(b * 2.0 + 0.2, 0.14, 0.24), Vector3(0.0, head, z), _ochre)
	for k in 6:
		var x := lerpf(-b + 0.1, b - 0.1, k / 5.0)
		_box(self, Vector3(0.14, head - sill, 0.2), Vector3(x, (sill + head) * 0.5, z), _ochre)
	for k in 5:
		var x := lerpf(-b + 0.1, b - 0.1, (k + 0.5) / 5.0)
		_box(self, Vector3(0.04, head - sill, 0.06), Vector3(x, (sill + head) * 0.5, z), _ochre)
		_box(self, Vector3(b * 0.4, 0.04, 0.06), Vector3(x, (sill + head) * 0.5, z), _ochre)
	_box(self, Vector3(b * 2.0, top - head, 0.14), Vector3(0.0, (top + head) * 0.5, z), _ochre)
	_box(self, Vector3(b * 2.0 + 0.3, 0.12, 0.3), Vector3(0.0, top, z), _dark)   # taffrail
	# The rudder head, and the great lantern on the taffrail.
	_box(self, Vector3(0.3, 4.6, 0.9), Vector3(0.0, 0.2, z + 0.5), _wood)
	# The modelled lantern hangs out over the stern from its bracket (the
	# bracket is on the model's +X side, so that side is turned forward).
	var quarter_turn := Basis(Vector3.UP, PI * 0.5)
	if _fitting(Models.LANTERN, 1, 1.5, Vector3(0.0, top + 0.05, z + 0.45), quarter_turn) == null:
		_box(self, Vector3(0.1, 1.1, 0.1), Vector3(0.0, top + 0.55, z), _iron)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(1.0, 0.75, 0.35)
		glass.emission_enabled = true
		glass.emission = Color(1.0, 0.62, 0.25)
		glass.emission_energy_multiplier = 2.5
		_cylinder(self, 0.16, 0.22, 0.5, Vector3(0.0, top + 1.3, z), glass, 6)
		_cylinder(self, 0.02, 0.2, 0.2, Vector3(0.0, top + 1.65, z), _iron, 6)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.68, 0.35)
	glow.light_energy = 1.4
	glow.omni_range = 11.0
	glow.position = Vector3(0.0, top + 1.3, z - 0.4)
	add_child(glow)


func _build_ladders_and_rails() -> void:
	var qz := ShipLayout.QUARTERDECK_BREAK_Z
	var fz := ShipLayout.FORECASTLE_BREAK_Z
	for side: float in [-1.0, 1.0]:
		_ladder(side * ShipLayout.QUARTERDECK_LADDER_X,
				ShipLayout.QUARTERDECK_LADDER_FOOT_Z, qz,
				ShipLayout.WAIST_Y, ShipLayout.QUARTERDECK_Y)
		_ladder(side * ShipLayout.FORECASTLE_LADDER_X,
				ShipLayout.FORECASTLE_LADDER_FOOT_Z, fz,
				ShipLayout.WAIST_Y, ShipLayout.FORECASTLE_Y)
	# Rails along the edge of each raised deck, with gaps at the ladder heads.
	var q_gap := ShipLayout.QUARTERDECK_LADDER_X
	var qb := ShipLayout.half_breadth(qz) - 0.3
	_breast_rail(-q_gap + 0.6, q_gap - 0.6, ShipLayout.QUARTERDECK_Y, qz + 0.08)
	_breast_rail(q_gap + 0.6, qb, ShipLayout.QUARTERDECK_Y, qz + 0.08)
	_breast_rail(-qb, -q_gap - 0.6, ShipLayout.QUARTERDECK_Y, qz + 0.08)
	var f_gap := ShipLayout.FORECASTLE_LADDER_X
	var fb := ShipLayout.half_breadth(fz) - 0.3
	_breast_rail(-f_gap + 0.6, f_gap - 0.6, ShipLayout.FORECASTLE_Y, fz - 0.08)
	_breast_rail(f_gap + 0.6, fb, ShipLayout.FORECASTLE_Y, fz - 0.08)
	_breast_rail(-fb, -f_gap - 0.6, ShipLayout.FORECASTLE_Y, fz - 0.08)


## A ladder of treads between two side pieces, from foot to head.
func _ladder(x: float, foot_z: float, head_z: float, foot_y: float, head_y: float) -> void:
	var treads := 7
	for k in treads:
		var t := (k + 1.0) / (treads + 1.0)
		_box(self, Vector3(0.95, 0.05, 0.24),
				Vector3(x, lerpf(foot_y, head_y, t), lerpf(foot_z, head_z, t)), _wood)
	for edge: float in [-1.0, 1.0]:
		_line(Vector3(x + edge * 0.5, foot_y, foot_z), Vector3(x + edge * 0.5, head_y, head_z),
				0.05, _wood)
		# A hand rope either side.
		_rope_between(Vector3(x + edge * 0.5, foot_y + 0.95, foot_z),
				Vector3(x + edge * 0.5, head_y + 0.95, head_z), 0.02)


## A waist-high rail on posts across the ship, from x = from to x = to.
func _breast_rail(from: float, to: float, deck_y: float, z: float) -> void:
	if to - from < 0.3:
		return
	_box(self, Vector3(to - from, 0.08, 0.1), Vector3((from + to) * 0.5, deck_y + 1.0, z), _dark)
	var posts := maxi(2, int((to - from) / 0.9) + 1)
	for k in posts:
		var x := lerpf(from, to, float(k) / (posts - 1))
		_box(self, Vector3(0.07, 1.0, 0.07), Vector3(x, deck_y + 0.5, z), _wood)


# --- the three decks --------------------------------------------------------

func _build_quarterdeck() -> void:
	var y := ShipLayout.QUARTERDECK_Y
	# The wheel, which turns with the rudder, and the binnacle before it.
	_wheel = Node3D.new()
	_wheel.position = Vector3(0.0, y + 1.1, 12.72)
	add_child(_wheel)
	# The modelled wheel stands on its own pedestal. It is one piece, so it
	# does not turn with the rudder as the code-built one does.
	if _fitting(Models.WHEEL, 1, 1.55, Vector3(0.0, y, 12.75), Basis.IDENTITY) == null:
		_box(self, Vector3(0.16, 1.05, 0.34), Vector3(0.0, y + 0.52, 12.95), _wood)
		var rim := TorusMesh.new()
		rim.inner_radius = 0.44
		rim.outer_radius = 0.52
		var hoop := _add(_wheel, rim, Vector3.ZERO, _wood)
		hoop.rotation.x = PI * 0.5
		for k in 4:
			var spoke := _box(_wheel, Vector3(1.3, 0.05, 0.05), Vector3.ZERO, _wood)
			spoke.rotation.z = PI * k / 4.0
	_box(self, Vector3(0.55, 0.95, 0.45), Vector3(0.0, y + 0.47, 12.2), _wood)
	_box(self, Vector3(0.3, 0.06, 0.3), Vector3(0.0, y + 0.97, 12.2), _brass)
	# The capstan, with its bars shipped.
	if _fitting(Models.CAPSTAN, 1, 1.25, Vector3(0.0, y, 6.0), Basis.IDENTITY) == null:
		_cylinder(self, 0.42, 0.55, 1.0, Vector3(0.0, y + 0.5, 6.0), _wood, 10)
		_cylinder(self, 0.7, 0.7, 0.22, Vector3(0.0, y + 1.1, 6.0), _wood, 10)
	for k in 4:
		var bar := _box(self, Vector3(3.2, 0.07, 0.07), Vector3(0.0, y + 1.12, 6.0), _wood)
		bar.rotation.y = PI * k / 4.0 + 0.3
	# Swivel guns on the rail, two a side.
	for side: float in [-1.0, 1.0]:
		for z: float in [9.6, 13.4]:
			var at := Vector3(side * (ShipLayout.half_breadth(z) - 0.1), ShipLayout.rail_y(z), z)
			_box(self, Vector3(0.06, 0.3, 0.06), at + Vector3(0.0, 0.15, 0.0), _iron)
			var barrel := _cylinder(self, 0.04, 0.06, 0.8, at + Vector3(side * 0.2, 0.34, 0.0),
					_iron, 6)
			barrel.rotation.z = -side * PI * 0.5


func _build_waist() -> void:
	var y := ShipLayout.WAIST_Y
	# Hatches with gratings, and the pumps abaft the mainmast.
	_box(self, Vector3(2.4, 0.22, 3.2), Vector3(0.0, y + 0.11, -4.8), _wood)
	_box(self, Vector3(2.1, 0.04, 2.9), Vector3(0.0, y + 0.23, -4.8), _dark)
	for side: float in [-1.0, 1.0]:
		_cylinder(self, 0.13, 0.15, 1.0, Vector3(side * 0.55, y + 0.5, 0.9), _wood, 8)
		var handle := _box(self, Vector3(0.05, 0.05, 1.1), Vector3(side * 0.55, y + 1.05, 1.2), _iron)
		handle.rotation.x = 0.35

	# Four-pounder guns on their carriages, run in and lashed.
	for side: float in [-1.0, 1.0]:
		for z: float in [-5.3, -2.6]:
			var at := Vector3(side * 3.2, y, z)
			_box(self, Vector3(1.0, 0.3, 0.6), at + Vector3(0.0, 0.32, 0.0), _red)
			var barrel := _cylinder(self, 0.09, 0.15, 1.6, at + Vector3(side * 0.15, 0.6, 0.0),
					_iron, 8)
			barrel.rotation.z = -side * PI * 0.5
			for wheel_x: float in [-0.32, 0.32]:
				for wheel_z: float in [-0.33, 0.33]:
					var truck := _cylinder(self, 0.16, 0.16, 0.08,
							at + Vector3(wheel_x, 0.16, wheel_z), _wood, 8)
					truck.rotation.x = PI * 0.5

	# The boats, stowed side by side on beams over the waist. You walk under them.
	var beam_y := y + 2.25
	for z: float in [-6.0, -1.4]:
		_box(self, Vector3(7.0, 0.18, 0.2), Vector3(0.0, beam_y, z), _wood)
		for side: float in [-1.0, 1.0]:
			_box(self, Vector3(0.16, 2.25, 0.16), Vector3(side * 3.4, y + 1.12, z), _wood)
	_boat(Vector3(-1.25, beam_y + 0.1, -3.7), 6.4, 1.9)   # the longboat
	_boat(Vector3(1.3, beam_y + 0.1, -3.7), 5.6, 1.7)     # the pinnace


func _build_forecastle() -> void:
	var y := ShipLayout.FORECASTLE_Y
	# The windlass, for weighing the anchors, between its two bitts.
	if _fitting(Models.WINDLASS, 0, 2.9, Vector3(0.0, y, -11.6), Basis.IDENTITY) == null:
		var barrel := _cylinder(self, 0.3, 0.3, 2.6, Vector3(0.0, y + 0.55, -11.6), _wood, 8)
		barrel.rotation.z = PI * 0.5
		for side: float in [-1.0, 1.0]:
			_box(self, Vector3(0.24, 1.1, 0.5), Vector3(side * 1.4, y + 0.55, -11.6), _wood)
	# The belfry and the ship's bell, and the galley chimney.
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0.12, 1.5, 0.12), Vector3(side * 0.45, y + 0.75, -7.95), _wood)
	_box(self, Vector3(1.2, 0.14, 0.2), Vector3(0.0, y + 1.55, -7.95), _wood)
	_cylinder(self, 0.09, 0.2, 0.3, Vector3(0.0, y + 1.3, -7.95), _brass, 10)
	_cylinder(self, 0.14, 0.14, 0.9, Vector3(1.5, y + 0.45, -10.2), _iron, 8)

	# Catheads, and an anchor hung from each.
	for side: float in [-1.0, 1.0]:
		var b := ShipLayout.half_breadth(-12.6)
		var cat := _box(self, Vector3(1.5, 0.24, 0.24),
				Vector3(side * (b + 0.4), ShipLayout.rail_y(-12.6) + 0.05, -12.6), _wood)
		cat.rotation.y = -side * 0.5
		# The modelled anchor is stowed as anchors were at sea: fished up and
		# lashed flat against the bow, ring forward. Its shank lies along the
		# model's X with the ring at +X, and it is flat in the model's XZ plane.
		var stowed := Basis(Vector3(0.0, 0.0, -1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0))
		var stow_z := -10.4
		var out := ShipLayout.half_breadth(stow_z) + 0.8
		if _fitting(Models.ANCHOR, 0, 3.4,
				Vector3(side * out, ShipLayout.rail_y(stow_z) - 1.0, stow_z), stowed) == null:
			_anchor(Vector3(side * (b + 0.45), ShipLayout.rail_y(-11.0) - 1.3, -11.0), side)


func _build_great_cabin() -> void:
	var y := ShipLayout.WAIST_Y
	var paper := _material(Color(0.91, 0.85, 0.70))
	# The table where the charts are drawn, a chart on it, and a bench under
	# the stern windows.
	_box(self, Vector3(1.8, 0.07, 1.1), Vector3(0.0, y + 0.8, 11.6), _wood)
	for corner_x: float in [-0.8, 0.8]:
		for corner_z: float in [-0.45, 0.45]:
			_box(self, Vector3(0.08, 0.8, 0.08), Vector3(corner_x, y + 0.4, 11.6 + corner_z), _wood)
	_box(self, Vector3(1.0, 0.012, 0.75), Vector3(-0.1, y + 0.845, 11.6), paper)
	_box(self, Vector3(0.3, 0.05, 0.05), Vector3(0.6, y + 0.86, 11.3), _brass)   # dividers
	var b := ShipLayout.half_breadth(14.3)
	_box(self, Vector3(b * 1.7, 0.45, 0.55), Vector3(0.0, y + 0.22, 14.45), _wood)
	_box(self, Vector3(b * 1.7, 0.08, 0.6), Vector3(0.0, y + 0.48, 14.45), _red)
	# The captain's desk and chair.
	_box(self, Vector3(1.0, 0.07, 0.7), Vector3(-2.4, y + 0.8, 6.0), _wood)
	_box(self, Vector3(0.95, 0.75, 0.65), Vector3(-2.4, y + 0.4, 6.0), _wood)
	_box(self, Vector3(0.5, 0.012, 0.35), Vector3(-2.4, y + 0.845, 6.0), paper)
	_box(self, Vector3(0.45, 0.45, 0.45), Vector3(-1.5, y + 0.22, 6.2), _wood)
	_box(self, Vector3(0.45, 0.6, 0.06), Vector3(-1.5, y + 0.7, 6.42), _wood)
	# Beams under the quarterdeck.
	for z: float in [5.5, 7.0, 8.5, 10.0, 11.5, 13.0]:
		var half := ShipLayout.half_breadth(z) - 0.25
		_box(self, Vector3(half * 2.0, 0.16, 0.14),
				Vector3(0.0, ShipLayout.QUARTERDECK_Y - 0.1, z), _wood)
	# A lantern slung over the chart table.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.75, 0.35)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.62, 0.25)
	glass.emission_energy_multiplier = 3.0
	_box(self, Vector3(0.18, 0.26, 0.18), Vector3(0.0, ShipLayout.QUARTERDECK_Y - 0.5, 11.2), glass)
	_box(self, Vector3(0.02, 0.24, 0.02), Vector3(0.0, ShipLayout.QUARTERDECK_Y - 0.25, 11.2), _iron)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.66, 0.34)
	lamp.light_energy = 2.2
	lamp.omni_range = 8.0
	lamp.position = Vector3(0.0, ShipLayout.QUARTERDECK_Y - 0.55, 11.2)
	add_child(lamp)


func _build_lower_deck() -> void:
	var y := ShipLayout.LOWER_Y
	var roof := ShipLayout.WAIST_Y
	# The ladder down, and a coaming round the hatch so nobody walks into it.
	var cx := ShipLayout.COMPANION_X
	var half := ShipLayout.COMPANION_HALF_WIDTH
	_ladder(cx, ShipLayout.COMPANION_FOOT_Z, ShipLayout.COMPANION_HEAD_Z, y, roof)
	var mid_z := (ShipLayout.COMPANION_FOOT_Z + ShipLayout.COMPANION_HEAD_Z) * 0.5
	var run := absf(ShipLayout.COMPANION_HEAD_Z - ShipLayout.COMPANION_FOOT_Z)
	var deep_end := signf(ShipLayout.COMPANION_FOOT_Z - ShipLayout.COMPANION_HEAD_Z)
	# Closed on three sides; open at the head of the ladder, where you step on.
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0.1, 0.3, run), Vector3(cx + side * (half + 0.05), roof + 0.15, mid_z), _wood)
	_box(self, Vector3(half * 2.0 + 0.2, 0.3, 0.1),
			Vector3(cx, roof + 0.15, ShipLayout.COMPANION_FOOT_Z + deep_end * 0.05), _wood)

	# Bulkheads at each end, and beams overhead.
	var aft_z := ShipLayout.LOWER_AFT_Z + 0.25
	var fore_z := ShipLayout.LOWER_FORE_Z - 0.55
	_box(self, Vector3(ShipLayout.half_breadth(aft_z) * 1.9, roof - y, 0.12),
			Vector3(0.0, (y + roof) * 0.5, aft_z), _cream)
	_box(self, Vector3(0.9, 1.7, 0.16), Vector3(0.6, y + 0.85, aft_z), _wood)   # a shut door
	_box(self, Vector3(ShipLayout.half_breadth(fore_z) * 1.9, roof - y, 0.12),
			Vector3(0.0, (y + roof) * 0.5, fore_z), _cream)
	for z: float in [-10.0, -8.2, -6.4, -4.6, -2.8, -1.0, 0.8, 2.6]:
		_box(self, Vector3(ShipLayout.half_breadth(z) * 1.9, 0.18, 0.16),
				Vector3(0.0, roof - 0.1, z), _wood)

	# Mess tables, each with two sea chests for benches.
	for side: float in [-1.0, 1.0]:
		for z: float in [-5.5, -2.5]:
			_box(self, Vector3(1.5, 0.06, 0.8), Vector3(side * 2.4, y + 0.75, z), _wood)
			_rope_between(Vector3(side * 2.4, y + 0.75, z), Vector3(side * 2.4, roof - 0.1, z), 0.015)
			for bench: float in [-0.65, 0.65]:
				_box(self, Vector3(1.3, 0.42, 0.4), Vector3(side * 2.4, y + 0.21, z + bench), _dark)

	# Hammocks slung from the beams. The sick are laid in these.
	for slot in ShipLayout.HAMMOCKS:
		var bed := CapsuleMesh.new()
		bed.radius = 0.32
		bed.height = 2.0
		var hammock := _add(self, bed, Vector3(slot.x, y + 0.9, slot.y), _cream)
		hammock.rotation.x = PI * 0.5
		hammock.scale = Vector3(1.0, 1.0, 0.45)
		for end: float in [-1.0, 1.0]:
			_rope_between(Vector3(slot.x, y + 0.95, slot.y + end * 1.0),
					Vector3(slot.x, roof - 0.1, slot.y + end * 1.35), 0.015)

	# The galley stove forward, with its fire, and casks lashed beside it.
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(1.0, 0.45, 0.12)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.38, 0.08)
	ember.emission_energy_multiplier = 3.0
	_box(self, Vector3(1.5, 1.1, 1.2), Vector3(1.5, y + 0.55, -9.9), _iron)
	_box(self, Vector3(0.7, 0.35, 0.05), Vector3(1.5, y + 0.45, -9.28), ember)
	_cylinder(self, 0.35, 0.35, 0.4, Vector3(1.5, y + 1.3, -9.9), _brass, 10)    # the copper
	_cylinder(self, 0.14, 0.14, roof - y - 1.1, Vector3(1.5, (y + 1.1 + roof) * 0.5, -10.2), _iron, 8)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.5, 0.2)
	fire.light_energy = 2.0
	fire.omni_range = 6.0
	fire.position = Vector3(1.5, y + 0.6, -9.0)
	add_child(fire)
	for k in 3:
		var cask := _cylinder(self, 0.36, 0.36, 1.0, Vector3(-1.3 - 0.8 * (k % 2), y + 0.5,
				-10.4 + 0.75 * k), _wood, 10)
		cask.scale = Vector3(1.0, 1.0, 1.0)
		_cylinder(self, 0.375, 0.375, 0.06, cask.position + Vector3(0.0, 0.3, 0.0), _iron, 10)
		_cylinder(self, 0.375, 0.375, 0.06, cask.position - Vector3(0.0, 0.3, 0.0), _iron, 10)

	# Lanterns along the middle: the only light down here.
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.75, 0.35)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.62, 0.25)
	glass.emission_energy_multiplier = 3.0
	for z: float in [-6.6, -3.6, 1.2]:
		_box(self, Vector3(0.16, 0.24, 0.16), Vector3(0.7, roof - 0.45, z), glass)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.64, 0.32)
		lamp.light_energy = 1.7
		lamp.omni_range = 6.5
		lamp.position = Vector3(0.7, roof - 0.5, z)
		add_child(lamp)


## Where a man starts and finishes his climb to a mast's top.
func climb(mast: int, starboard: bool) -> Array:
	return _climbs[mast][1 if starboard else 0]


## A point on a yard (in the ship's space), `out` metres from the mast and
## a little below the yard, where a man stands on the foot-rope.
func yard_point(mast: int, tier: int, out: float) -> Vector3:
	var local := Vector3(out, MAST_HEIGHT[mast] * YARD_AT[tier] - 1.05, -0.2)
	return _yards[mast].transform * local


# --- masts, sails and rigging ------------------------------------------------

func _build_mast(m: int) -> void:
	var z := MAST_Z[m]
	var h := MAST_HEIGHT[m]
	var size := h / 30.0
	var top_y := DECK_Y + h * TOP_AT
	var cross_y := DECK_Y + h * 0.78

	# Lower mast with iron bands, topmast, topgallant mast and truck.
	_cylinder(self, 0.3, 0.4, h * 0.5, Vector3(0.0, DECK_Y + h * 0.25, z), _wood, 12)
	for k in 5:
		_cylinder(self, 0.36, 0.37, 0.07, Vector3(0.0, DECK_Y + 1.6 + k * h * 0.075, z), _dark, 12)
	_cylinder(self, 0.17, 0.25, h * 0.36, Vector3(0.0, DECK_Y + h * 0.62, z - 0.25), _wood, 10)
	_cylinder(self, 0.08, 0.15, h * 0.22, Vector3(0.0, DECK_Y + h * 0.89, z - 0.1), _wood, 8)
	_cylinder(self, 0.14, 0.14, 0.06, Vector3(0.0, DECK_Y + h + 0.02, z - 0.1), _wood, 8)
	# The top: a platform with a rail round its after side. The crosstrees above.
	_box(self, Vector3(2.5 * size, 0.1, 2.0 * size), Vector3(0.0, top_y, z), _wood)
	_box(self, Vector3(2.5 * size, 0.06, 0.06), Vector3(0.0, top_y + 0.9, z + 1.0 * size), _wood)
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0.06, 0.9, 0.06),
				Vector3(side * 1.2 * size, top_y + 0.45, z + 1.0 * size), _wood)
	_box(self, Vector3(1.5 * size, 0.07, 0.1), Vector3(0.0, cross_y, z - 0.25), _wood)
	_box(self, Vector3(0.1, 0.07, 1.1 * size), Vector3(0.0, cross_y, z - 0.25), _wood)

	for side: float in [-1.0, 1.0]:
		# The channel: a ledge outside the hull where the shrouds make fast.
		var chain_z := z + 1.9
		var b := ShipLayout.half_breadth(chain_z)
		_box(self, Vector3(0.45, 0.08, 4.2),
				Vector3(side * (b + 0.2), ShipLayout.rail_y(chain_z) - 0.25, chain_z), _dark)
		# Lower shrouds, with ratlines to climb by.
		var heads: Array[Vector3] = []
		var feet: Array[Vector3] = []
		for k in 5:
			var foot_z := z + 0.3 + 0.8 * k
			heads.append(Vector3(side * 0.5 * size, top_y - 0.1, z + 0.1 * k))
			feet.append(Vector3(side * (ShipLayout.half_breadth(foot_z) + 0.35),
					ShipLayout.rail_y(foot_z) - 0.2, foot_z))
			_rope_between(heads[k], feet[k], 0.03)
		_climbs[m].append([feet[2], heads[2]])
		var rungs := int((top_y - ShipLayout.rail_y(z)) / 0.42)
		for r in range(1, rungs):
			var t := float(r) / rungs
			_rope_between(feet[0].lerp(heads[0], t), feet[4].lerp(heads[4], t), 0.012)
		# Topmast shrouds, and a backstay from the crosstrees to the channel.
		for k in 3:
			_rope_between(Vector3(side * 0.15, cross_y, z - 0.25),
					Vector3(side * 1.15 * size, top_y + 0.1, z - 0.3 + 0.4 * k), 0.022)
		_rope_between(Vector3(side * 0.2, cross_y, z - 0.2),
				Vector3(side * (b + 0.35), ShipLayout.rail_y(chain_z) - 0.2, z + 3.8), 0.028)
	# Stays running forward and down: from the top, and from the crosstrees.
	var stay_foot := Vector3(0.0, ShipLayout.deck_top(z - 8.4) + 1.2, z - 8.4)
	var top_stay_foot := Vector3(0.0, DECK_Y + MAST_HEIGHT[maxi(m - 1, 0)] * TOP_AT, z - 8.6)
	if m == 0:
		stay_foot = Vector3(0.0, 5.6, -20.5)
		top_stay_foot = Vector3(0.0, 6.6, -25.4)
	_rope_between(Vector3(0.0, top_y, z - 0.3), stay_foot, 0.045)
	_rope_between(Vector3(0.0, cross_y, z - 0.3), top_stay_foot, 0.03)

	var yards := Node3D.new()
	yards.position = Vector3(0.0, DECK_Y, z)
	add_child(yards)
	_yards.append(yards)
	var lifts := SurfaceTool.new()
	lifts.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in YARD_AT.size():
		var yard_y := h * YARD_AT[t]
		var span := YARD_WIDTH[t] * size + 1.2
		var yard := _cylinder(yards, 0.085 * size, 0.085 * size, span,
				Vector3(0.0, yard_y, -0.45), _wood, 8)
		yard.rotation.z = PI * 0.5
		# Lifts hold the yard level from the mast above it.
		for side: float in [-1.0, 1.0]:
			_ribbon(lifts, Vector3(side * span * 0.48, yard_y, -0.45),
					Vector3(0.0, yard_y + h * 0.1, -0.2), 0.018)
		if m == 2 and t == 1:
			continue  # the mizzen's lowest yard carries no sail
		var sail := _add(yards, _square_sail(YARD_WIDTH[t] * size, FOOT_WIDTH[t] * size,
				h * SAIL_DROP[t], t == 0), Vector3(0.0, yard_y - 0.1, -0.5), _canvas)
		_sails.append(sail)
		_sail_tier.append(t)
		var furl := _cylinder(yards, 0.2 * size, 0.2 * size, YARD_WIDTH[t] * size * 0.92,
				Vector3(0.0, yard_y - 0.2, -0.5), _cream, 8)
		furl.rotation.z = PI * 0.5
		_furls.append(furl)
	lifts.generate_normals()
	var lift_mesh := _add(yards, lifts.commit(), Vector3.ZERO, _rope)
	lift_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if m == 2:
		# The driver: a fore-and-aft sail set abaft the mizzen, over the wheel.
		var foot := ShipLayout.QUARTERDECK_Y + 2.6
		_driver = Node3D.new()
		_driver.position = Vector3(0.0, 0.0, z + 0.4)
		add_child(_driver)
		var driver := _add(_driver, _flat_sail(PackedVector3Array([
			Vector3(0.0, foot, 0.0), Vector3(0.0, foot + 0.3, 6.0),
			Vector3(0.0, foot + 8.0, 4.4), Vector3(0.0, foot + 6.0, 0.0),
		])), Vector3.ZERO, _canvas)
		_fore_and_aft.append(driver)
		var gaff := _cylinder(_driver, 0.07, 0.07, 5.2, Vector3(0.0, foot + 7.05, 2.3), _wood, 6)
		gaff.basis = Basis(Quaternion(Vector3.UP, Vector3(0.0, 2.0, 4.4).normalized()))


func _build_head_rig() -> void:
	# Bowsprit and jib-boom, the spritsail yard slung under them, and two
	# headsails set on the stays.
	_line(Vector3(0.0, 4.9, -15.2), Vector3(0.0, 6.4, -22.0), 0.26, _wood)
	_line(Vector3(0.0, 6.2, -21.0), Vector3(0.0, 7.0, -26.0), 0.12, _wood)
	var sprit := _cylinder(self, 0.08, 0.08, 9.0, Vector3(0.0, 5.3, -19.6), _wood, 6)
	sprit.rotation.z = PI * 0.5
	_rope_between(Vector3(0.0, 6.4, -22.0), Vector3(0.0, 2.6, -16.0), 0.04)   # bobstay

	var fore_top := DECK_Y + MAST_HEIGHT[0] * TOP_AT
	var fore_cross := DECK_Y + MAST_HEIGHT[0] * 0.78
	_fore_and_aft.append(_add(self, _flat_sail(PackedVector3Array([
		Vector3(0.0, 5.9, -20.0), Vector3(0.0, fore_top - 1.0, -10.6),
		Vector3(0.0, 6.4, -11.6), Vector3(0.0, 6.0, -15.5),
	])), Vector3.ZERO, _canvas))
	_fore_and_aft.append(_add(self, _flat_sail(PackedVector3Array([
		Vector3(0.0, 6.9, -25.0), Vector3(0.0, fore_cross - 1.5, -10.6),
		Vector3(0.0, fore_top + 1.0, -11.0), Vector3(0.0, 7.2, -20.5),
	])), Vector3.ZERO, _canvas))


func _build_flags() -> void:
	# The pennant at the main masthead, which streams the way the wind blows.
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

	# The red ensign on its staff at the stern: a red flag with the Union of
	# the day (before 1801, so without the red diagonal cross) in the corner.
	var staff_foot := Vector3(0.0, ShipLayout.rail_y(ShipLayout.STERN_Z), ShipLayout.STERN_Z + 0.15)
	_line(staff_foot, staff_foot + Vector3(0.0, 4.6, 0.9), 0.045, _wood)
	_ensign = Node3D.new()
	_ensign.position = staff_foot + Vector3(0.0, 4.4, 0.9)
	add_child(_ensign)
	var flag := SurfaceTool.new()
	flag.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red := Color(0.72, 0.10, 0.09)
	var blue := Color(0.10, 0.14, 0.38)
	var white := Color(0.92, 0.90, 0.84)
	_flag_patch(flag, 0.0, 3.0, 0.0, -1.8, 0.0, red)
	_flag_patch(flag, 0.0, 1.4, 0.0, -0.9, 0.004, blue)
	_flag_patch(flag, 0.58, 0.82, 0.0, -0.9, 0.008, white)     # St George, edged white
	_flag_patch(flag, 0.0, 1.4, -0.36, -0.54, 0.008, white)
	_flag_patch(flag, 0.64, 0.76, 0.0, -0.9, 0.012, red)
	_flag_patch(flag, 0.0, 1.4, -0.41, -0.49, 0.012, red)
	flag.generate_normals()
	_add(_ensign, flag.commit(), Vector3.ZERO, _canvas)


## One coloured rectangle of a flag, lying in the plane x = `out`, running
## from z0 to z1 along the fly and y0 to y1 down the hoist.
func _flag_patch(st: SurfaceTool, z0: float, z1: float, y0: float, y1: float, out: float,
		colour: Color) -> void:
	for face: float in [-1.0, 1.0]:
		var x := out * face
		var corners: Array[Vector3] = [
			Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(colour)
			st.add_vertex(corners[index])


## A square sail hanging from its yard (the origin is the middle of the
## yard), bellied forward, with panels of slightly different cloth and,
## on topsails, the darker bands where the reef points are sewn.
func _square_sail(head: float, foot: float, drop: float, reef_bands: bool) -> ArrayMesh:
	var across := 11
	var down := 9
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
			if reef_bands and (r == 1 or r == 2):
				shade *= 0.86
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


# --- smaller things ----------------------------------------------------------

## An open boat, keel down, with thwarts across.
func _boat(at: Vector3, length: float, beam: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stations := 9
	var points := 7
	for i in stations:
		var u := float(i) / (stations - 1)
		var half := beam * 0.5 * pow(sin(PI * clampf(u * 0.9 + 0.05, 0.0, 1.0)), 0.6)
		for j in points:
			var a := PI * j / (points - 1)
			st.add_vertex(Vector3(-half * cos(a), 0.75 - 0.75 * pow(sin(a), 0.8), (u - 0.5) * length))
	for i in stations - 1:
		for j in points - 1:
			var p := i * points + j
			_quad(st, p, p + points, p + points + 1, p + 1)
	st.generate_normals()
	_add(self, st.commit(), at, _cream)
	for k in 3:
		_box(self, Vector3(beam * 0.8, 0.05, 0.22),
				at + Vector3(0.0, 0.55, lerpf(-length * 0.28, length * 0.28, k / 2.0)), _wood)


## An anchor hung up and down against the bow.
func _anchor(at: Vector3, side: float) -> void:
	_box(self, Vector3(0.12, 2.6, 0.12), at + Vector3(0.0, 0.3, 0.0), _iron)        # shank
	_box(self, Vector3(0.14, 0.14, 2.2), at + Vector3(0.0, 1.5, 0.0), _wood)         # stock
	for arm: float in [-1.0, 1.0]:
		var fluke := _box(self, Vector3(0.1, 1.0, 0.16), at + Vector3(0.0, -0.7, arm * 0.4), _iron)
		fluke.rotation.x = arm * 0.9
	var ring := TorusMesh.new()
	ring.inner_radius = 0.1
	ring.outer_radius = 0.16
	var eye := _add(self, ring, at + Vector3(side * 0.02, 1.75, 0.0), _iron)
	eye.rotation.z = PI * 0.5


## Adds a rope to the standing rigging.
func _rope_between(from: Vector3, to: Vector3, radius: float) -> void:
	_ribbon(_rig, from, to, radius)


## A rope drawn as two thin strips crossed at right angles, so that it
## shows from every side. All the ropes together make one mesh.
func _ribbon(st: SurfaceTool, from: Vector3, to: Vector3, radius: float) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.UP)
	if side.length() < 0.01:
		side = along.cross(Vector3.RIGHT)
	side = side.normalized() * radius
	var other := along.cross(side).normalized() * radius
	for across: Vector3 in [side, other]:
		var corners: Array[Vector3] = [from - across, from + across, to + across, to - across]
		for index: int in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(corners[index])


func _quad(st: SurfaceTool, a: int, b: int, c: int, d: int) -> void:
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)
	st.add_index(a)
	st.add_index(c)
	st.add_index(d)


func _material(color: Color) -> ShaderMaterial:
	return Paint.material(color)


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
		mat: Material, sides: int) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _add(parent, mesh, pos, mat)


## A solid spar from one point to another.
func _line(from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var span := to - from
	var inst := _cylinder(self, radius, radius, span.length(), (from + to) * 0.5, mat, 8)
	inst.basis = Basis(Quaternion(Vector3.UP, span.normalized()))
