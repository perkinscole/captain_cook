class_name StoryState
extends RefCounted
## What the story remembers about the player. Deliberately tiny for now.

var cook_trust: int = 0
var flags: Dictionary = {}
var relations: Dictionary = {}  ## place -> how its people regard the ship
var regard: Dictionary = {}     ## person -> how they regard the player


## Adds each amount in `changes` (name -> number) to a tally such as
## relations or regard.
static func add_to(tally: Dictionary, changes: Dictionary) -> void:
	for key: String in changes:
		tally[key] = int(tally.get(key, 0)) + int(changes[key])


func has_flag(flag: String) -> bool:
	return flags.has(flag)
