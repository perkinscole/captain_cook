class_name Tutorial
extends Node
## The lessons at the start: one thing at a time, told by a shipmate, and
## each one finished by doing it. Charles Clerke was a real master's mate
## in Endeavour, cheerful and well liked; his words here are invented.
##
## Other code tells the tutorial what the player has done with note().

signal step_done
signal finished

const TEACHER := "Mr Clerke, master's mate"
const STEPS: Array[Dictionary] = [
	{"id": "look", "text": "Welcome aboard! I am Charles Clerke. Have a look about "
			+ "you: move the mouse. That is Captain Cook at the rail on your right, "
			+ "and old Trull at the wheel behind you."},
	{"id": "walk", "text": "Now stretch your legs. W, A, S and D walk you about the "
			+ "deck. There are ladders down to the waist at the front of this "
			+ "quarterdeck, and the door under it leads to the great cabin."},
	{"id": "sail", "text": "We are jogging along under topsails. Press the Up arrow "
			+ "twice to make more sail, and feel her gather way. The Down arrow takes "
			+ "it in again."},
	{"id": "course", "text": "The compass up on the left shows where her head points. "
			+ "You do not hold the wheel: you give the course. Press the Left "
			+ "or Right arrow a few times. One press is one point of the compass, and the brass pointer "
			+ "shows what you have ordered."},
	{"id": "wind", "text": "Now the wind. The blue arrow on the compass flies the way "
			+ "it blows. See the red wedge? No square-rigger sails into that. Keep the "
			+ "wind on her side or behind her and she flies. If you order a course "
			+ "inside the wedge, Trull will hold her as close to the wind as she will "
			+ "go. To get upwind you zig-zag: press X to go about onto the other tack."},
	{"id": "chart", "text": "Your chart is at the bottom right. Press M to bring it "
			+ "to the table, and M again to put it away. The coast draws itself in "
			+ "pencil as we sail in sight of it."},
	{"id": "lead", "text": "There is coral round this island, and you cannot see it "
			+ "in thick weather. Press the Down arrow until we are under nine knots. Then press Space "
			+ "to set Pascoe swinging the lead, and Space again to let go when the "
			+ "marker is in the green."},
	{"id": "bearing", "text": "Pencil is only a sketch. To fix the coast in ink, press "
			+ "Q for your spyglass and find a headland: a rock, a bluff or a clump of "
			+ "palms, marked with its name. Put the cross on it and press F. Then sail "
			+ "on a good way and do the same again. Where the two lines cross is "
			+ "where it truly lies."},
	{"id": "talk", "text": "A crew works better for an officer who knows them. Look "
			+ "at one of the hands, or at the captain, and press E."},
	{"id": "stores", "text": "Last thing. Press C for the crew and the stores. Fresh "
			+ "food keeps off the scurvy. When it runs low, anchor in Matavai Bay "
			+ "on the north side and trade for more."},
	{"id": "done", "text": "That is the whole trade! Sketch the coast right round, "
			+ "fix what headlands you can, then show the captain your chart. "
			+ "H brings up the keys if you forget them. You have the deck."},
]

var ship: Ship
var control: OrdersMode
var charting: Charting

var active: bool = false
var step: int = 0

var _noted: Dictionary = {}
var _timer: float = 0.0
var _looked: float = 0.0
var _course_at_start: float = 0.0


func start() -> void:
	active = true
	step = 0
	_enter()


## Ends the lessons early.
func skip() -> void:
	if active:
		active = false
		finished.emit()


func title() -> String:
	return "%s      (lesson %d of %d.  T to skip the lessons)" % [TEACHER, step + 1, STEPS.size()]


func text() -> String:
	return STEPS[step]["text"] if active else ""


## Tells the tutorial that something happened, e.g. "chart_opened".
func note(what: String) -> void:
	_noted[what] = true


func looked(pixels: float) -> void:
	_looked += pixels


func _process(delta: float) -> void:
	if not active:
		return
	_timer += delta
	if _is_done(STEPS[step]["id"]):
		step += 1
		if step >= STEPS.size():
			active = false
			finished.emit()
		else:
			step_done.emit()
			_enter()


func _enter() -> void:
	_noted.clear()
	_timer = 0.0
	_looked = 0.0
	_course_at_start = control.ordered_deg


func _is_done(id: String) -> bool:
	match id:
		"look":
			return _looked > 900.0 and _timer > 4.0
		"walk":
			return _noted.has("walked")
		"sail":
			return ship.sail >= 4 or (_noted.has("sail") and ship.sail >= 3 and _timer > 6.0)
		"course":
			return absf(wrapf(control.ordered_deg - _course_at_start, -180.0, 180.0)) >= 20.0
		"wind":
			return _timer > 14.0
		"chart":
			return _noted.has("chart_opened") and _noted.has("chart_closed")
		"lead":
			return _noted.has("sounding")
		"bearing":
			return _noted.has("fix") or charting.fixed_count() > 0
		"talk":
			return _noted.has("talked")
		"stores":
			return _noted.has("crew_panel")
		"done":
			return _timer > 16.0
	return true
