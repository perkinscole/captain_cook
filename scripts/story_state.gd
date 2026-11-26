class_name StoryState
extends RefCounted
## What the story remembers about the player. Deliberately tiny for now.

var cook_trust: int = 0
var flags: Dictionary = {}


func has_flag(flag: String) -> bool:
	return flags.has(flag)
