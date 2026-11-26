class_name SeamanBody
extends Node3D
## A seaman modelled and rigged outside the game (see models/README.md),
## with a recorded walk. It answers to the same few things as the code-built
## Figure (`walking`, `facing`, `set_pose`), so the two can stand in for
## each other.
##
## The model file holds the body, its skeleton and one clip, the walk. There
## is no clip for standing still yet, so when he stops he is held at the
## moment of the walk where he stands most upright with his arms down.

const MODEL := "res://models/seaman/seaman_walking.glb"
const STAND_AT := 0.5        ## seconds into the walk clip: the upright moment
const CLIP_PACE := 1.3       ## metres a second the clip was made to walk at

var facing: float = 0.0      ## yaw (radians) he turns toward
var walking: bool = false    ## set while he is being moved along the deck
var pace: float = 1.05       ## how fast he is being moved, to match his stride to it
var tint := Color(1.0, 1.0, 1.0)   ## set before adding him: a wash of colour over his clothes

var _player: AnimationPlayer
var _walk: StringName = &""
var _was_walking: bool = false


## Is the model there to be used? (It needs Godot to have imported it.)
static func available() -> bool:
	return ResourceLoader.exists(MODEL)


func _ready() -> void:
	var scene := load(MODEL) as PackedScene
	if scene == null:
		return
	var body := scene.instantiate() as Node3D
	# The model was made facing +Z; everyone in the game faces -Z.
	body.rotation.y = PI
	add_child(body)

	# Paint him like everything else, using the colours of his own texture.
	for found in body.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		var original := part.get_active_material(0) as BaseMaterial3D
		if original != null and original.albedo_texture != null:
			part.material_override = Paint.textured(original.albedo_texture, tint)

	# Find the walk, make it repeat, and start him standing.
	for found in body.find_children("*", "AnimationPlayer", true, false):
		_player = found as AnimationPlayer
	if _player == null:
		return
	for clip in _player.get_animation_list():
		if clip != &"RESET":
			_walk = clip
	if _walk == &"":
		return
	_player.get_animation(_walk).loop_mode = Animation.LOOP_LINEAR
	_player.play(_walk)
	_stand()
	rotation.y = facing


## The code-built figures take named poses. He has none yet, so this does
## nothing; it is here so that the same code can direct either.
func set_pose(_pose: String, _seconds: float = 0.9) -> void:
	pass


func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-3.5 * delta))
	if _player == null or _walk == &"":
		return
	if walking and not _was_walking:
		_player.speed_scale = pace / CLIP_PACE
		_player.play(_walk)
	elif not walking and _was_walking:
		_stand()
	_was_walking = walking


## Holds him at the upright moment of the walk.
func _stand() -> void:
	_player.speed_scale = 0.0
	_player.seek(STAND_AT, true)
