class_name Supplies
extends Node
## The ship's stores and the passing of days. Time is squeezed: one ship's
## day lasts DAY_SECONDS of play.
##
## Scurvy is the slow danger. It comes from weeks without fresh food. Cook
## fought it with fresh greens whenever he could get them and with casks of
## sour krout (pickled cabbage) when he could not.

signal news(text: String)

const DAY_SECONDS := 120.0
const RATION_NAMES: Array[String] = ["Full allowance", "Two-thirds allowance", "Half allowance"]
const RATION_RATE: Array[float] = [1.0, 0.667, 0.5]

var days: float = 0.0          ## days since the survey began
var greens: float = 3.0        ## days of fresh greens left
var krout: float = 6.0         ## days of sour krout left, when it is served
var provisions: float = 8.0    ## days of salt meat and biscuit at full allowance
var grog: int = 3              ## extra issues of grog in hand
var rations: int = 0           ## index into RATION_NAMES
var serving_krout: bool = false
var days_without_fresh: float = 0.0


func day() -> int:
	return int(days) + 1


func has_fresh_food() -> bool:
	return greens > 0.0 or (serving_krout and krout > 0.0)


func is_starving() -> bool:
	return provisions <= 0.0


func cycle_rations() -> void:
	rations = (rations + 1) % RATION_NAMES.size()


func _process(delta: float) -> void:
	var step := delta / DAY_SECONDS
	days += step

	if greens > 0.0:
		greens -= step
		if greens <= 0.0:
			greens = 0.0
			news.emit("The last of the fresh greens are eaten. Scurvy will follow "
					+ "unless the sour krout is served (K).")
	elif serving_krout and krout > 0.0:
		krout -= step
		if krout <= 0.0:
			krout = 0.0
			news.emit("The sour krout cask is empty.")

	if has_fresh_food():
		days_without_fresh = 0.0
	else:
		days_without_fresh += step

	if provisions > 0.0:
		provisions -= step * RATION_RATE[rations]
		if provisions <= 0.0:
			provisions = 0.0
			news.emit("The bread room is empty. The people are going hungry.")


func report() -> String:
	var lines := PackedStringArray([
		"Day %d" % day(),
		"Salt provisions: %.1f days   (%s)" % [
			provisions / RATION_RATE[rations], RATION_NAMES[rations]],
		"Fresh greens: %.1f days" % greens,
		"Sour krout: %.1f days   (%s)" % [krout, "being served" if serving_krout else "not served"],
		"Extra grog: %d issues" % grog,
	])
	return "\n".join(lines)
