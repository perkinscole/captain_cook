class_name Landfall
extends Node3D
## The anchorage and the shore scene. Owns where the ship may anchor, the
## little set on the beach (a view point, two figures, some canoes), and the
## switch between the view from the deck and the view from the sand.
## It does not know what is said there: that is data in story/.

const ANCHOR_RADIUS := 130.0     ## how near the mark the ship must be
const TOW_RANGE := 450.0         ## how far off the boats can tow her in from
const ANCHOR_MAX_SPEED := 2.5    ## m/s. Come in under easy sail.
const OFF_SHORE := 170.0
const EYE_HEIGHT := 1.65

var island: Island
var deck_camera: DeckCamera
var anchorage := Vector2.ZERO    ## world (x, z) of the anchoring ground
var anchorage_name: String = "Matavai Bay"
var shore_camera: DeckCamera
var figures: Dictionary = {}     ## speaker id -> Figure, for the people ashore
var stage: String = "deck"

var _set: Node3D


## `coast_angle` is where on the island the bay lies (radians, atan2(z, x)).
func build(coast_angle: float) -> void:
	var out := Vector2(cos(coast_angle), sin(coast_angle))
	var centre := Vector2(island.position.x, island.position.z)
	var shore_radius := island.coast_radius(coast_angle)
	anchorage = centre + out * (shore_radius + OFF_SHORE)

	# The set stands on the beach, turned so that its -Z looks out to sea.
	_set = Node3D.new()
	var foot := centre + out * (shore_radius * 0.975)   # on the sand, just above the tide
	_set.position = Vector3(foot.x, 0.0, foot.y)
	_set.rotation.y = atan2(-out.x, -out.y)
	add_child(_set)

	shore_camera = DeckCamera.new()
	shore_camera.fov = 70.0
	shore_camera.far = 6000.0
	_set.add_child(shore_camera)
	shore_camera.position = _on_sand(Vector3.ZERO) + Vector3(0.0, EYE_HEIGHT, 0.0)

	var tupaia := Figure.new()
	Landfall.dress_as_tupaia(tupaia)
	tupaia.idle_facing = PI * 0.75
	_set.add_child(tupaia)
	tupaia.position = _on_sand(Vector3(-1.7, 0.0, -3.6))
	figures["tupaia"] = tupaia

	var pascoe := Figure.new()
	pascoe.coat_color = Color(0.45, 0.50, 0.55)
	pascoe.legs_color = Color(0.80, 0.76, 0.66)
	pascoe.wears_hat = false
	pascoe.long_coat = false
	pascoe.hair_color = Color(0.35, 0.24, 0.14)
	pascoe.neck_color = Color(0.55, 0.14, 0.12)
	pascoe.idle_facing = -PI * 0.75
	_set.add_child(pascoe)
	pascoe.position = _on_sand(Vector3(2.2, 0.0, -3.0))
	figures["pascoe"] = pascoe

	# Placeholder canoes drawn up on the sand: a hull, an outrigger float.
	var wood := Paint.material(Color(0.36, 0.24, 0.14))
	for i in 4:
		var canoe := Node3D.new()
		_set.add_child(canoe)
		canoe.position = _on_sand(Vector3(-9.0 - 3.2 * i, 0.0, -5.0 + 0.6 * i)) \
				+ Vector3(0.0, 0.3, 0.0)
		canoe.rotation.y = 0.25
		_box(canoe, Vector3(0.6, 0.55, 7.0), Vector3.ZERO, wood)
		_box(canoe, Vector3(0.2, 0.2, 4.5), Vector3(1.6, -0.1, 0.0), wood)
		_box(canoe, Vector3(1.7, 0.08, 0.12), Vector3(0.8, 0.2, 1.2), wood)
		_box(canoe, Vector3(1.7, 0.08, 0.12), Vector3(0.8, 0.2, -1.2), wood)


## Dresses a figure as Tupaia: pale bark cloth, no hat.
static func dress_as_tupaia(figure: Figure) -> void:
	figure.coat_color = Color(0.90, 0.85, 0.72)
	figure.legs_color = Color(0.90, 0.85, 0.72)
	figure.skin_color = Color(0.58, 0.40, 0.28)
	figure.hair_color = Color(0.07, 0.06, 0.05)
	figure.neck_color = Color(0.90, 0.85, 0.72)
	figure.wears_hat = false


func can_anchor(ship: Ship) -> bool:
	var here := Vector2(ship.position.x, ship.position.z)
	return here.distance_to(anchorage) <= ANCHOR_RADIUS and absf(ship.speed) <= ANCHOR_MAX_SPEED


## Is she close enough, and slow enough, for the boats to tow her in?
func can_tow(ship: Ship) -> bool:
	var off := Vector2(ship.position.x, ship.position.z).distance_to(anchorage)
	return off <= TOW_RANGE and off > ANCHOR_RADIUS * 0.5 and absf(ship.speed) <= 3.5 \
			and not ship.towing


func is_near(ship: Ship) -> bool:
	return Vector2(ship.position.x, ship.position.z).distance_to(anchorage) <= ANCHOR_RADIUS


## Moves the view to the deck or the shore.
func set_stage(next: String) -> void:
	stage = next
	if stage == "shore":
		shore_camera.make_current()
	else:
		deck_camera.make_current()


func active_camera() -> DeckCamera:
	return shore_camera if stage == "shore" else deck_camera


## Takes a spot given in the set's own space and stands it on the ground.
func _on_sand(local: Vector3) -> Vector3:
	var world := _set.to_global(Vector3(local.x, 0.0, local.z))
	return Vector3(local.x, island.surface_height(Vector2(world.x, world.z)), local.z)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
