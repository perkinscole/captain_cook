class_name Models
extends RefCounted
## Where the modelled bodies and ship parts live (see models/README.md).
## Everything that uses one of these falls back to its code-built version if
## the file is not there.

const SEAMAN := "res://models/seaman/seaman_actions.glb"
const OLD_SEAMAN := "res://models/characters/old_seaman/old_seaman_actions.glb"
const SHIPS_BOY := "res://models/characters/ships_boy/ships_boy_actions.glb"
const COOK := "res://models/characters/cook/cook_actions.glb"
const OFFICER := "res://models/characters/officer/officer_actions.glb"
const MARINE := "res://models/characters/marine/marine_actions.glb"
const BANKS := "res://models/characters/banks/banks_actions.glb"

const HULL := "res://models/ship/hull.glb"
const WHEEL := "res://models/ship/wheel.glb"
const CAPSTAN := "res://models/ship/capstan.glb"
const WINDLASS := "res://models/ship/windlass.glb"
const ANCHOR := "res://models/ship/anchor.glb"
const LANTERN := "res://models/ship/lantern.glb"
const BOAT := "res://models/ship/boat_light.glb"
const GUN := "res://models/ship/gun_light.glb"


static func has(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


## Every mesh in a loaded model, including its top node if that is one.
static func meshes_of(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		found.append(root as MeshInstance3D)
	for child in root.find_children("*", "MeshInstance3D", true, false):
		found.append(child as MeshInstance3D)
	return found


## The picture (texture) a model's mesh carries, or null.
static func picture_of(mesh: MeshInstance3D) -> Texture2D:
	var original := mesh.get_active_material(0) as BaseMaterial3D
	return original.albedo_texture if original != null else null
