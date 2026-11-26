class_name Hand
extends RefCounted
## One named member of the ship's company.

var full_name: String = ""
var title: String = ""       ## e.g. "quartermaster"
var role: String = ""        ## the job they do for the ship: "helm", "lead", ...
var health: float = 95.0     ## 0..100
var morale: float = 70.0     ## 0..100
var frailty: float = 1.0     ## how hard scurvy hits them
var sick: bool = false       ## too ill to stand their watch
var last_talked_day: int = 0


func health_word() -> String:
	if sick:
		return "sick, off duty"
	if health >= 80.0:
		return "hearty"
	if health >= 60.0:
		return "well enough"
	return "poorly"


func morale_word() -> String:
	if morale >= 75.0:
		return "cheerful"
	if morale >= 50.0:
		return "steady"
	if morale >= 30.0:
		return "grumbling"
	return "sullen"
