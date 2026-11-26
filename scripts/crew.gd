class_name Crew
extends Node
## The named hands, and how their health and spirits change day by day.
## Other systems ask efficiency(role) to learn how well a job is being done.
##
## Young and Thompson were real members of Endeavour's company. Trull, Pascoe
## and Harker are invented, because the lower deck is thinly recorded.

signal news(text: String)

const RATION_MORALE: Array[float] = [0.0, -6.0, -12.0]  ## morale per day
const SICK_BELOW := 45.0
const WELL_ABOVE := 55.0

var supplies: Supplies
var hands: Array[Hand] = []


func _ready() -> void:
	var trull := _add("Amos Trull", "quartermaster, at the wheel", "helm", 1.2, 72.0)
	trull.skin = Color(0.70, 0.50, 0.38)
	trull.hair = Color(0.74, 0.74, 0.72)
	trull.jacket = Color(0.30, 0.22, 0.16)
	trull.kerchief = Color(0.14, 0.20, 0.36)
	trull.beard = true
	var pascoe := _add("Will Pascoe", "leadsman", "lead", 1.0, 58.0)
	pascoe.hair = Color(0.35, 0.24, 0.14)
	pascoe.jacket = Color(0.42, 0.48, 0.55)
	var harker := _add("Ned Harker", "boatswain's mate", "sails", 0.8, 70.0)
	harker.skin = Color(0.74, 0.55, 0.42)
	harker.hair = Color(0.10, 0.09, 0.08)
	harker.jacket = Color(0.18, 0.28, 0.30)
	harker.kerchief = Color(0.70, 0.55, 0.20)
	var young := _add("Nicholas Young", "ship's boy, at the masthead", "lookout", 0.9, 82.0)
	young.skin = Color(0.86, 0.68, 0.56)
	young.hair = Color(0.72, 0.52, 0.28)
	young.jacket = Color(0.55, 0.30, 0.22)
	young.kerchief = Color(0.20, 0.35, 0.30)
	young.boy = true
	var thompson := _add("John Thompson", "ship's cook", "cook", 1.1, 68.0)
	thompson.hair = Color(0.38, 0.36, 0.34)
	thompson.jacket = Color(0.72, 0.68, 0.60)
	thompson.kerchief = Color(0.90, 0.88, 0.82)


func hand_for(role: String) -> Hand:
	for h in hands:
		if h.role == role:
			return h
	return null


## How well a job is being done, from about 0.45 (a sick man's stand-in)
## to 1.0 (a fit hand in good heart).
func efficiency(role: String) -> float:
	var h := hand_for(role)
	if h == null:
		return 1.0
	if h.sick:
		return 0.45
	return lerpf(0.55, 1.0, h.morale / 100.0) * (0.7 + 0.3 * h.health / 100.0)


func average_morale() -> float:
	var total := 0.0
	for h in hands:
		total += h.morale
	return total / maxf(hands.size(), 1.0)


func sick_count() -> int:
	var n := 0
	for h in hands:
		if h.sick:
			n += 1
	return n


## Something happened that the whole crew feels.
func cheer(amount: float) -> void:
	for h in hands:
		h.morale = clampf(h.morale + amount, 0.0, 100.0)


## The officer stopped to speak with a hand. It counts once a day.
func noticed(h: Hand) -> void:
	if h.last_talked_day != supplies.day():
		h.last_talked_day = supplies.day()
		h.morale = clampf(h.morale + 4.0, 0.0, 100.0)


func _process(delta: float) -> void:
	var step := delta / Supplies.DAY_SECONDS
	var cook_hand := hand_for("cook")
	var good_cooking := cook_hand != null and not cook_hand.sick and not supplies.is_starving()

	for h in hands:
		if supplies.is_starving():
			h.health -= 10.0 * step
			h.morale -= 15.0 * step
		if supplies.has_fresh_food():
			h.health += 6.0 * step
		elif supplies.days_without_fresh > 1.0:
			h.health -= 9.0 * h.frailty * step

		h.morale += RATION_MORALE[supplies.rations] * step
		if supplies.serving_krout and supplies.greens <= 0.0 and supplies.krout > 0.0:
			h.morale -= 2.0 * step  # nobody likes it at first
		if good_cooking and h.morale < 70.0:
			h.morale += 5.0 * step

		h.health = clampf(h.health, 5.0, 100.0)
		h.morale = clampf(h.morale, 0.0, 100.0)

		if not h.sick and h.health < SICK_BELOW:
			h.sick = true
			news.emit("%s is down with scurvy and cannot stand his watch." % h.full_name)
		elif h.sick and h.health > WELL_ABOVE:
			h.sick = false
			news.emit("%s is on his feet again." % h.full_name)


func report() -> String:
	var lines := PackedStringArray()
	for h in hands:
		lines.append("%s, %s" % [h.full_name, h.title])
		lines.append("      %s, %s" % [h.health_word(), h.morale_word()])
	return "\n".join(lines)


func _add(full_name: String, title: String, role: String, frailty: float,
		morale: float) -> Hand:
	var h := Hand.new()
	h.full_name = full_name
	h.title = title
	h.role = role
	h.frailty = frailty
	h.morale = morale
	hands.append(h)
	return h
