class_name Dialogue
extends Node
## Runs one conversation. A conversation is plain data (see story/):
##
##   { "start": "id", "nodes": { "id": { ... }, ... } }
##
## Each node has "who" (empty for narration), "text", and optionally "pose"
## (a Figure pose for the speaker), "flag" (set on the story when reached),
## and either "next" (id of the following node; leave it out to end) or
## "choices": a list of { "text", "next", "trust", "flag" }.
##
## This class knows nothing about how lines are shown or who is posed.

signal line_changed
signal finished

var story: StoryState
var active: bool = false

var who: String = ""
var text: String = ""
var pose: String = ""
var choices: Array = []

var _nodes: Dictionary = {}
var _next: String = ""


func start(scene: Dictionary) -> void:
	_nodes = scene["nodes"]
	active = true
	_show(scene["start"])


## Moves on from a line that has no choices.
func advance() -> void:
	if active and choices.is_empty():
		_show(_next)


func choose(index: int) -> void:
	if not active or index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	if story != null:
		story.cook_trust += int(choice.get("trust", 0))
		var flag: String = choice.get("flag", "")
		if flag != "":
			story.flags[flag] = true
	_show(choice.get("next", ""))


func _show(id: String) -> void:
	if id == "" or not _nodes.has(id):
		active = false
		choices = []
		finished.emit()
		return
	var node: Dictionary = _nodes[id]
	who = node.get("who", "")
	text = node.get("text", "")
	pose = node.get("pose", "")
	choices = node.get("choices", [])
	_next = node.get("next", "")
	var flag: String = node.get("flag", "")
	if flag != "" and story != null:
		story.flags[flag] = true
	line_changed.emit()
