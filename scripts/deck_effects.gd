class_name DeckEffects
extends Node3D
## Small moving things about the ship: spray thrown up when the bow drives
## into a sea, rain in a squall, and the lead swung from the chains.
## Child of the Ship.

var ship: Ship
var lead: LeadLine
var lead_station := Vector3.ZERO   ## where the leadsman stands, in the ship's space

var _spray: CPUParticles3D
var _rain: CPUParticles3D
var _lead_arm: Node3D
var _spray_left: float = 0.0


func _ready() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	white.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	white.billboard_keep_scale = true
	white.albedo_texture = Paint.soft_dot()

	var drop := QuadMesh.new()
	drop.size = Vector2(0.45, 0.45)
	drop.material = white
	_spray = CPUParticles3D.new()
	_spray.mesh = drop
	_spray.amount = 160
	_spray.lifetime = 1.6
	_spray.local_coords = false
	_spray.emitting = false
	_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_spray.emission_box_extents = Vector3(3.2, 0.4, 1.2)
	_spray.direction = Vector3(0.0, 1.0, 0.35)
	_spray.spread = 38.0
	_spray.initial_velocity_min = 5.0
	_spray.initial_velocity_max = 11.0
	_spray.gravity = Vector3(0.0, -9.8, 0.0)
	_spray.scale_amount_min = 0.4
	_spray.scale_amount_max = 1.3
	_spray.position = Vector3(0.0, 0.8, ShipLayout.BOW_Z + 0.5)
	add_child(_spray)

	var streak_mat := white.duplicate() as StandardMaterial3D
	streak_mat.albedo_color = Color(0.85, 0.88, 0.92, 0.2)
	var streak := QuadMesh.new()
	streak.size = Vector2(0.012, 0.55)
	streak.material = streak_mat
	_rain = CPUParticles3D.new()
	_rain.mesh = streak
	_rain.amount = 900
	_rain.lifetime = 0.9
	_rain.local_coords = false
	_rain.emitting = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(22.0, 0.5, 22.0)
	_rain.direction = Vector3(0.0, -1.0, 0.0)
	_rain.spread = 4.0
	_rain.initial_velocity_min = 24.0
	_rain.initial_velocity_max = 30.0
	_rain.gravity = Vector3.ZERO
	_rain.position = Vector3(0.0, 20.0, 0.0)
	add_child(_rain)

	# The lead: a weight on a line, hanging from the leadsman's hand.
	_lead_arm = Node3D.new()
	_lead_arm.visible = false
	add_child(_lead_arm)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.12, 0.13)
	var line := MeshInstance3D.new()
	var cord := CylinderMesh.new()
	cord.top_radius = 0.012
	cord.bottom_radius = 0.012
	cord.height = 2.2
	line.mesh = cord
	line.material_override = iron
	line.position = Vector3(0.0, -1.1, 0.0)
	_lead_arm.add_child(line)
	var weight := MeshInstance3D.new()
	var plummet := CylinderMesh.new()
	plummet.top_radius = 0.035
	plummet.bottom_radius = 0.06
	plummet.height = 0.3
	weight.mesh = plummet
	weight.material_override = iron
	weight.position = Vector3(0.0, -2.3, 0.0)
	_lead_arm.add_child(weight)


## Throws spray over the bow for a moment.
func burst() -> void:
	_spray_left = 0.5


## Rain falls over the given spot (in the ship's space) when `falling`.
func rain(falling: bool, over: Vector3) -> void:
	_rain.emitting = falling
	_rain.position = Vector3(over.x, over.y + 16.0, over.z)


func _process(delta: float) -> void:
	_spray_left = maxf(0.0, _spray_left - delta)
	_spray.emitting = _spray_left > 0.0

	if lead == null:
		return
	var swinging := lead.state == LeadLine.State.SWINGING
	_lead_arm.visible = swinging
	if swinging:
		# Out over the side from his hand, swinging fore and aft.
		_lead_arm.position = lead_station + Vector3(0.75, 1.25, 0.0)
		_lead_arm.rotation.x = lead.swing * 1.1
