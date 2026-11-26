class_name LeadLine
extends Node
## Heaving the lead: a weight on a marked line, swung forward and dropped to
## measure the depth. The leadsman swings it like a pendulum and you call the
## release. Let go at the top of the forward swing for a true reading.
##
## Depths are in fathoms (1 fathom = 6 feet, about 1.83 m). The line has
## "marks" tied on at certain fathoms; the depths in between are "deeps".

## `voice` names the recorded line for this cry, if anyone has recorded one.
signal cast_made(cry: String, voice: String)

const FATHOM := 1.83
const SWING_SECONDS := 1.5
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
var swing: float = 0.0   ## -1 (aft) .. +1 (forward). Release near +1.
var skill: float = 1.0   ## how good the leadsman is today, 0..1
var busy: float = 0.0    ## seconds until the lead can be hove again

var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	_time += delta
	busy = maxf(0.0, busy - delta)
	swing = sin(_time * TAU / SWING_SECONDS)


func heave() -> void:
	if busy > 0.0:
		return
	if ship.speed > MAX_SPEED:
		busy = 1.0
		cast_made.emit("Too much way on her! Shorten sail to sound.", "lead_too_fast")
		return
	busy = HAUL_SECONDS

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
