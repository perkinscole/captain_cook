class_name ShipLayout
extends RefCounted
## The plan of the ship: where her decks are, how wide she is, where the
## ladders run and what stands in the way. The model is built from this and
## the player walks by it, so the two always agree.
##
## Everything is in the ship's own space: x to starboard, y up, z aft, with
## the origin amidships at the waterline.
##
## She has three levels open to the sky: a raised forecastle at the bow, the
## low waist amidships, and a raised quarterdeck aft. Under the quarterdeck,
## at the level of the waist, is the great cabin. Under the waist and the
## forecastle is the lower deck, where the people eat and sleep, reached by a
## ladder through a hatch in the waist.

const LENGTH := 31.0
const BOW_Z := -16.0
const STERN_Z := 15.0
const HALF_BEAM := 4.0
const KEEL_Y := -1.6
const WAIST_Y := 3.15
const FORECASTLE_Y := 4.05
const QUARTERDECK_Y := 5.25
const FORECASTLE_BREAK_Z := -7.5   ## where the forecastle ends and the waist begins
const QUARTERDECK_BREAK_Z := 4.0   ## where the waist ends and the quarterdeck begins
const BULWARK := 1.05              ## height of the rail above the deck
const LOWER_Y := 1.1               ## the lower deck
const LOWER_FORE_Z := -11.0        ## how far forward and aft the lower deck runs
const LOWER_AFT_Z := 3.6
## The hatch and ladder down to the lower deck: to port of the mainmast.
## You walk aft onto its head from the open waist, and go down facing aft.
const COMPANION_X := -1.7
const COMPANION_HALF_WIDTH := 0.55
const COMPANION_HEAD_Z := -0.6
const COMPANION_FOOT_Z := 1.6
## Where the sick lie in their hammocks on the lower deck (x, z).
const HAMMOCKS: Array[Vector2] = [
	Vector2(-2.4, -9.8), Vector2(-2.4, -7.9), Vector2(2.4, -7.6),
	Vector2(2.4, 0.4), Vector2(2.4, 2.4),
]
const GALLEY := Vector3(0.6, LOWER_Y, -8.2)   ## where the cook stands at his stove

## Ladders: how far off the centre line, and where their feet stand.
const QUARTERDECK_LADDER_X := 2.6
const QUARTERDECK_LADDER_FOOT_Z := 1.8
const FORECASTLE_LADDER_X := 2.4
const FORECASTLE_LADDER_FOOT_Z := -6.3
const LADDER_HALF_WIDTH := 0.6
const DOOR_HALF_WIDTH := 0.55      ## the great cabin door, in the quarterdeck bulkhead
const DOOR_HEIGHT := 1.9

const BODY_RADIUS := 0.3
const STEP := 0.5                  ## the biggest step a person can take up or down

## Things you cannot walk through: x, z, radius, and the deck they stand on.
const OBSTACLES: Array[Vector4] = [
	Vector4(0.0, -9.0, 0.55, FORECASTLE_Y),     # foremast
	Vector4(0.0, -11.6, 0.9, FORECASTLE_Y),     # windlass
	Vector4(0.0, -7.95, 0.5, FORECASTLE_Y),     # belfry
	Vector4(0.0, 0.0, 0.6, WAIST_Y),            # mainmast
	Vector4(-0.55, 0.9, 0.3, WAIST_Y),          # pumps
	Vector4(0.55, 0.9, 0.3, WAIST_Y),
	Vector4(-3.2, -5.3, 0.65, WAIST_Y),         # guns
	Vector4(3.2, -5.3, 0.65, WAIST_Y),
	Vector4(-3.2, -2.6, 0.65, WAIST_Y),
	Vector4(3.2, -2.6, 0.65, WAIST_Y),
	Vector4(0.0, 8.0, 0.5, QUARTERDECK_Y),      # mizzenmast, on deck
	Vector4(0.0, 8.0, 0.5, WAIST_Y),            # and where it comes down through the cabin
	Vector4(0.0, 6.0, 0.8, QUARTERDECK_Y),      # capstan
	Vector4(0.0, 12.6, 0.75, QUARTERDECK_Y),    # wheel and binnacle
	Vector4(0.0, 11.6, 1.05, WAIST_Y),          # chart table in the great cabin
	Vector4(-2.4, 6.0, 0.7, WAIST_Y),           # the captain's desk
	Vector4(0.0, 0.0, 0.6, LOWER_Y),            # mainmast, below
	Vector4(0.0, -9.0, 0.55, LOWER_Y),          # foremast, below
	Vector4(1.5, -9.9, 0.95, LOWER_Y),          # the galley stove
	Vector4(-2.4, -5.5, 0.9, LOWER_Y),          # mess tables
	Vector4(2.4, -5.5, 0.9, LOWER_Y),
	Vector4(-2.4, -2.5, 0.9, LOWER_Y),
	Vector4(2.4, -2.5, 0.9, LOWER_Y),
	Vector4(-2.4, -9.8, 0.55, LOWER_Y),         # hammocks
	Vector4(-2.4, -7.9, 0.55, LOWER_Y),
	Vector4(2.4, -7.6, 0.55, LOWER_Y),
	Vector4(2.4, 0.4, 0.55, LOWER_Y),
	Vector4(2.4, 2.4, 0.55, LOWER_Y),
]


## Half the width of the hull at a point along it.
static func half_breadth(z: float) -> float:
	var u := clampf((z - BOW_Z) / LENGTH, 0.0, 1.0)
	# Bluff, like a collier, and shaped to sit just inside the modelled hull.
	var bow := 1.0 - pow(1.0 - clampf(u / 0.3, 0.0, 1.0), 2.2)
	var stern := 1.0 - 0.22 * pow(clampf((u - 0.78) / 0.22, 0.0, 1.0), 2.0)
	return HALF_BEAM * bow * stern


## Height of the open deck at a point along the ship.
static func deck_top(z: float) -> float:
	var fore := 1.0 - smoothstep(FORECASTLE_BREAK_Z - 0.12, FORECASTLE_BREAK_Z + 0.12, z)
	var aft := smoothstep(QUARTERDECK_BREAK_Z - 0.12, QUARTERDECK_BREAK_Z + 0.12, z)
	return WAIST_Y + (FORECASTLE_Y - WAIST_Y) * fore + (QUARTERDECK_Y - WAIST_Y) * aft


## Height of the top of the rail. It sweeps up a little toward bow and stern.
static func rail_y(z: float) -> float:
	var u := clampf((z - BOW_Z) / LENGTH, 0.0, 1.0)
	return deck_top(z) + BULWARK + 0.45 * pow(absf(u - 0.5) * 2.0, 2.0)


## Is this spot down in the great cabin?
static func is_in_cabin(feet: Vector3) -> bool:
	return feet.z > QUARTERDECK_BREAK_Z and feet.y < WAIST_Y + 1.0


## Is this spot on the lower deck (or on the ladder down to it)?
static func is_below(feet: Vector3) -> bool:
	return feet.y < WAIST_Y - 0.6


## Is (x, z) over the open hatch that leads below?
static func is_over_companion(x: float, z: float) -> bool:
	return absf(x - COMPANION_X) < COMPANION_HALF_WIDTH \
			and z >= minf(COMPANION_FOOT_Z, COMPANION_HEAD_Z) \
			and z <= maxf(COMPANION_FOOT_Z, COMPANION_HEAD_Z)


## The height of the floor a person at height `y` could stand on at (x, z),
## or NAN if there is nothing there to stand on.
static func floor_at(x: float, z: float, y: float) -> float:
	if absf(x) > half_breadth(z) - 0.55 or z < BOW_Z + 1.6 or z > STERN_Z - 0.45:
		return NAN
	var floors: Array[float] = []
	for side: float in [-1.0, 1.0]:
		if absf(x - side * QUARTERDECK_LADDER_X) < LADDER_HALF_WIDTH \
				and z >= QUARTERDECK_LADDER_FOOT_Z and z <= QUARTERDECK_BREAK_Z:
			floors.append(lerpf(WAIST_Y, QUARTERDECK_Y,
					inverse_lerp(QUARTERDECK_LADDER_FOOT_Z, QUARTERDECK_BREAK_Z, z)))
		if absf(x - side * FORECASTLE_LADDER_X) < LADDER_HALF_WIDTH \
				and z <= FORECASTLE_LADDER_FOOT_Z and z >= FORECASTLE_BREAK_Z:
			floors.append(lerpf(WAIST_Y, FORECASTLE_Y,
					inverse_lerp(FORECASTLE_LADDER_FOOT_Z, FORECASTLE_BREAK_Z, z)))
	if is_over_companion(x, z):
		floors.append(lerpf(LOWER_Y, WAIST_Y,
				inverse_lerp(COMPANION_FOOT_Z, COMPANION_HEAD_Z, z)))
	elif z >= FORECASTLE_BREAK_Z:
		floors.append(WAIST_Y)   # the waist, and aft of it the great cabin
	# The lower deck. The hull is narrower down there.
	if z >= LOWER_FORE_Z and z <= LOWER_AFT_Z and absf(x) < half_breadth(z) * 0.92 - 0.55:
		floors.append(LOWER_Y)
	if z <= FORECASTLE_BREAK_Z:
		floors.append(FORECASTLE_Y)
	if z >= QUARTERDECK_BREAK_Z:
		floors.append(QUARTERDECK_Y)

	var best := NAN
	for level in floors:
		if absf(level - y) <= STEP and (is_nan(best) or level > best):
			best = level
	return best


## Would walking from one spot to another go through something solid?
## `people` are others standing on deck, as (x, y, z).
static func is_blocked(from: Vector3, to: Vector3, people: Array[Vector3]) -> bool:
	# The bulkhead under the front of the quarterdeck, with its one door.
	var crosses := (from.z - QUARTERDECK_BREAK_Z) * (to.z - QUARTERDECK_BREAK_Z) < 0.0
	if crosses and to.y < WAIST_Y + 0.5 and absf(to.x) > DOOR_HALF_WIDTH - 0.2:
		return true
	for thing in OBSTACLES:
		if absf(to.y - thing.w) < 1.2 \
				and Vector2(to.x - thing.x, to.z - thing.y).length() < thing.z + BODY_RADIUS:
			return true
	for person in people:
		if absf(to.y - person.y) < 1.2 \
				and Vector2(to.x - person.x, to.z - person.z).length() < 0.4 + BODY_RADIUS:
			return true
	return false
