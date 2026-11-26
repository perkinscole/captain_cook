class_name LeadLine
extends Node
## Heaving the lead: a weight on a marked line, swung forward and dropped to
## measure the depth. One press starts the leadsman swinging it; a second
## press lets go. Let go at the top of the forward swing for a true reading.
##
## Depths are in fathoms (1 fathom = 6 feet, about 1.83 m). The line has
## "marks" tied on at certain fathoms; the depths in between are "deeps".

## `voice` names the recorded line for this cry, if anyone has recorded one.
signal cast_made(cry: String, voice: String)
signal swing_started

enum State { IDLE, SWINGING, HAULING }

const FATHOM := 1.83
const SWING_SECONDS := 1.5
const MAX_SWINGS := 4.0       ## after this many swings he lets go by himself, badly
const HAUL_SECONDS := 2.5     ## hauling the line back in before the next cast
const MAX_SPEED := 4.5        ## m/s. Faster than this the lead cannot reach bottom.
const LINE_FATHOMS := 20
const MARKS: Array[int] = [2, 3, 5, 7, 10, 13, 15, 17, 20]
const NUMBER_WORDS: Array[String] = [
	"nought", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
	"eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
	"eighteen", "nineteen", "twenty",
]

var ship: Ship
var seabed: Seabed

## Every sounding taken: { "pos": Vector2, "fathoms": int, "good": bool }.
## fathoms is -1 for "no bottom".
var soundings: Array[Dictionary] = []
var state: State = State.IDLE
var swing: float = -1.0  ## -1 (aft) .. +1 (forward). Release near +1.
var skill: float = 1.0   ## how good the leadsman is today, 0..1

var _clock: float = 0.0  # seconds spent in the present state
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	_clock += delta
	match state:
		State.SWINGING:
			swing = -cos(_clock * TAU / SWING_SECONDS)
			if _clock > SWING_SECONDS * MAX_SWINGS:
				swing = 0.0  # his arm has tired: a slack cast
				_release()
		State.HAULING:
			if _clock >= HAUL_SECONDS:
				state = State.IDLE


## The one key: starts the swing, or lets go if he is already swinging.
func heave() -> void:
	match state:
		State.IDLE:
			if ship.speed > MAX_SPEED:
				cast_made.emit("Too much way on her! Shorten sail to sound.", "lead_too_fast")
				return
			state = State.SWINGING
			_clock = 0.0
			swing = -1.0
			swing_started.emit()
		State.SWINGING:
			_release()


func _release() -> void:
	state = State.HAULING
	_clock = 0.0

	var true_depth := seabed.depth_at(Vector2(ship.position.x, ship.position.z))
	var measured := true_depth
	var good := swing > 0.8
	var remark := ""
	if good:
		measured += _rng.randf_range(-0.3, 0.3) / skill
	elif swing > 0.3:
		measured += _rng.randf_range(-1.0, 1.0) * (1.0 + 0.15 * true_depth) / skill
		remark = "  (a fair cast)"
	else:
		measured += _rng.randf_range(-1.0, 1.0) * (2.0 + 0.4 * true_depth) / skill
		remark = "  (a slack cast: do not trust it)"

	var fathoms := roundi(maxf(measured, 0.0) / FATHOM)
	var here := Vector2(ship.position.x, ship.position.z)
	if fathoms > LINE_FATHOMS:
		soundings.append({"pos": here, "fathoms": -1, "good": good})
		cast_made.emit("No bottom with this line." + remark, "lead_no_bottom")
		return
	soundings.append({"pos": here, "fathoms": fathoms, "good": good})
	var cry := "By the %s %s!" % ["mark" if fathoms in MARKS else "deep", NUMBER_WORDS[fathoms]]
	if fathoms <= 3:
		cry += " Shoal water!"
	cast_made.emit(cry + remark, "lead_%d" % fathoms)
