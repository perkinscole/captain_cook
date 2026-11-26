class_name Topmen
extends Node3D
## The hands who work the sails. When sail is ordered they run to the
## shrouds, climb to the yard that is to be worked, lay out along it, and
## come down again when the work is done. The sail does not move until
## they are on the yard, so an order given late in a squall is a late sail.
##
## Child of the Ship, beside the ShipVisual it climbs.

enum Where { ON_DECK, GOING_UP, ON_YARD, COMING_DOWN }

const CLIMB_SECONDS := 6.0
const GIVE_UP_SECONDS := 12.0   ## if something goes wrong, the sail moves anyway
const WORKED_TIER: Array[int] = [0, 0, 0, 1, 2]   # which yards a sail order touches

var visual: ShipVisual
var ship: Ship
var skill: float = 1.0   ## how smartly they climb, 0..1

var _men: Array[Dictionary] = []
var _tier: int = 0
var _since_order: float = 99.0
var _work_done_for: float = 0.0


func _ready() -> void:
	# Three men to each of the fore and main masts.
	for mast in 2:
		for n in 3:
			var side := -1.0 if n == 0 else 1.0
			var out: float = [-2.6, 2.6, 1.0][n] * ShipVisual.MAST_HEIGHT[mast] / 30.0
			# They wait just forward of their mast, clear of the ladders.
			var z := ShipVisual.MAST_Z[mast] - 1.0 - 0.6 * n
			var deck_spot := Vector3(side * (ShipLayout.half_breadth(z) - 0.75),
					ShipLayout.deck_top(z), z)
			var figure := Figure.new()
			figure.coat_color = Color(0.30, 0.34, 0.40).lerp(Color(0.45, 0.30, 0.22), n / 2.0)
			figure.legs_color = Color(0.80, 0.76, 0.66)
			figure.hair_color = Color(0.25, 0.18, 0.12)
			figure.neck_color = Color(0.20, 0.25, 0.40)
			figure.wears_hat = false
			figure.wears_cap = n != 1
			figure.long_coat = false
			figure.position = deck_spot
			figure.idle_facing = -side * PI * 0.5   # looking outboard
			add_child(figure)
			_men.append({
				"figure": figure, "mast": mast, "starboard": side > 0.0, "out": out,
				"deck": deck_spot, "where": Where.ON_DECK, "t": 0.0,
			})


## Sends the hands aloft for a change of sail from one order to another.
func send_aloft(sail_before: int, sail_after: int) -> void:
	_tier = WORKED_TIER[clampi(maxi(sail_before, sail_after), 0, WORKED_TIER.size() - 1)]
	_since_order = 0.0
	_work_done_for = 0.0
	for man in _men:
		if man["where"] != Where.GOING_UP:
			if man["where"] == Where.ON_YARD:
				man["t"] = 0.85   # shift from one yard to another
			man["where"] = Where.GOING_UP
			(man["figure"] as Figure).set_pose("climb", 0.4)


## 1 when the hands are on the yard and the sail can be worked, else 0.
func readiness() -> float:
	if _since_order > GIVE_UP_SECONDS:
		return 1.0
	for man in _men:
		if man["where"] != Where.ON_YARD:
			return 0.0
	return 1.0


func _process(delta: float) -> void:
	if ship == null or visual == null:
		return
	_since_order += delta
	var settled := absf(ship.canvas - Ship.SAIL_AREA[ship.sail]) < 0.01
	_work_done_for = _work_done_for + delta if settled else 0.0
	var rate := delta / CLIMB_SECONDS * clampf(skill, 0.4, 1.0)

	for man in _men:
		var figure: Figure = man["figure"]
		var side := 1.0 if man["starboard"] else -1.0
		match man["where"]:
			Where.GOING_UP:
				man["t"] = minf(float(man["t"]) + rate, 1.0)
				figure.position = _along_path(man, man["t"])
				figure.facing = side * PI * 0.5   # facing in toward the mast
				if float(man["t"]) >= 1.0:
					man["where"] = Where.ON_YARD
					figure.set_pose("haul", 0.5)
			Where.ON_YARD:
				figure.position = visual.yard_point(man["mast"], _tier, man["out"])
				figure.facing = 0.0
				if _work_done_for > 2.0:
					man["where"] = Where.COMING_DOWN
					figure.set_pose("climb", 0.5)
			Where.COMING_DOWN:
				man["t"] = maxf(float(man["t"]) - rate, 0.0)
				figure.position = _along_path(man, man["t"])
				figure.facing = side * PI * 0.5
				if float(man["t"]) <= 0.0:
					man["where"] = Where.ON_DECK
					figure.rest()


## Where a man is, `t` of the way from his place on deck to his place on
## the yard: across the deck, up the shrouds, then out along the yard.
func _along_path(man: Dictionary, t: float) -> Vector3:
	var path: Array = visual.climb(man["mast"], man["starboard"])
	var deck: Vector3 = man["deck"]
	var foot: Vector3 = path[0]
	var head: Vector3 = path[1]
	if t < 0.12:
		return deck.lerp(foot, t / 0.12)
	if t < 0.82:
		return foot.lerp(head, (t - 0.12) / 0.70)
	return head.lerp(visual.yard_point(man["mast"], _tier, man["out"]), (t - 0.82) / 0.18)
