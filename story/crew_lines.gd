class_name CrewLines
extends RefCounted
## What each hand says when spoken to. One line, chosen by how they are and
## what is going on. It is the player's read on the mood of the lower deck.
##
## PLACEHOLDER WRITING. Trull, Pascoe and Harker are invented. Young and
## Thompson were real, but their words here are not from any record. The sour
## krout detail is recorded: Cook had it served at the officers' table so
## that the men would want it too.

const LINES := {
	"helm": {
		"sick": "My gums are sore and my old wounds ache, sir. It is the scurvy. "
				+ "I have had it before, under worse captains.",
		"aground": "Coral, sir. It will open her like a knife. I would keep the lead going.",
		"low": "The people are grumbling, sir. Short commons and long days. "
				+ "I have seen where that road goes.",
		"good": "She steers sweet today, sir. I have served captains who would flog a "
				+ "man for a shivering sail. This one asks why it shivered.",
	},
	"lead": {
		"sick": "My arms are like wet rope, sir. I cannot swing the lead true.",
		"aground": "I am sorry, sir. I had no cast of the lead before she struck.",
		"low": "My uncle signed me aboard, sir. I did not ask for the sea, "
				+ "and it did not ask for me.",
		"good": "Call for the lead when you want it, sir. I never thought to be good "
				+ "at anything aboard, but I can find the bottom.",
	},
	"sails": {
		"sick": "I am not fit to go aloft, sir, and half my topmen are no better. "
				+ "You will wait for your canvas today.",
		"aground": "We hauled her off, sir, but the hands will not thank us for another.",
		"low": "They are slow to the braces and they look at me sideways. "
				+ "Sullen men make slow sail.",
		"good": "The hands are lively aloft, sir. Call for sail and you shall have it smartly.",
	},
	"lookout": {
		"sick": "My eyes swim, sir. I would not swear to what I see.",
		"thick": "I cannot see the jib-boom in this, sir! You must trust the lead.",
		"aground": "I never saw it, sir. The water was all one colour.",
		"low": "It is cold up here, sir, and a long way down.",
		"good": "I can see clear to the edge of the world from here, sir! "
				+ "Pale water shows as plain as milk.",
	},
	"cook": {
		"sick": "I can barely lift the kettle, sir. The people will eat cold today.",
		"hungry": "There is nothing left to boil, sir. Not a biscuit.",
		"krout": "They pull faces at the sour krout, but they eat it. The captain has it "
				+ "served at his own table, and that settles the matter.",
		"no_fresh": "The greens are gone, sir. Salt beef and biscuit now. The captain "
				+ "swears by the sour krout, if the men will eat it.",
		"short": "Two-thirds of a man's allowance makes two-thirds of a man, sir.",
		"low": "A sour mess deck, sir. I hear all of it over the coppers.",
		"good": "Fresh greens in the kettle and no complaints, sir. "
				+ "A fed ship is a quiet ship.",
	},
}


## Picks the line for a hand. `thick` = poor visibility, `aground` = she has
## struck lately.
static func line_for(h: Hand, supplies: Supplies, thick: bool, aground: bool) -> String:
	var lines: Dictionary = LINES[h.role]
	var key := "good"
	if h.sick:
		key = "sick"
	elif h.role == "cook" and supplies.is_starving():
		key = "hungry"
	elif h.role == "lookout" and thick:
		key = "thick"
	elif aground and lines.has("aground"):
		key = "aground"
	elif h.role == "cook" and supplies.greens <= 0.0 and supplies.serving_krout:
		key = "krout"
	elif h.role == "cook" and supplies.greens <= 0.0:
		key = "no_fresh"
	elif h.role == "cook" and supplies.rations > 0:
		key = "short"
	elif h.morale < 50.0:
		key = "low"
	return lines[key]
