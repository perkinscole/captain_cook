class_name CookScenes
extends RefCounted
## Conversations with Captain Cook, as data for Dialogue.
##
## PLACEHOLDER WRITING. The scene is invented. It leans on things the record
## supports: Cook was an exacting surveyor who distinguished coast he had
## fixed from coast he had only glimpsed. Check the voice and the detail
## against the journals before this is treated as final.

## Before the survey is finished.
const ORDERS := {
	"start": "orders",
	"nodes": {
		"orders": {
			"who": "Captain Cook",
			"text": "You have your orders. Take her right round the island and lay down "
					+ "every yard of coast you can see. Bring me the chart when it is done.",
		},
	},
}

## After the chart has been shown once.
const CARRY_ON := {
	"start": "carry_on",
	"nodes": {
		"carry_on": {
			"who": "Captain Cook",
			"text": "That will do for now. Carry on.",
		},
	},
}

## The survey is complete and the captain asks to see it. One choice.
const THE_CHART := {
	"start": "greet",
	"nodes": {
		"greet": {
			"who": "Captain Cook",
			"text": "So. You have been right round her. Let me see what you have made of it.",
			"pose": "regard",
			"flag": "chart_shown",
			"next": "reads",
		},
		"reads": {
			"who": "",
			"text": "He takes the sheet and turns it to the light. For a long moment "
					+ "he says nothing. The ship lies hove to, creaking.",
			"pose": "reading",
			"next": "praise",
		},
		"praise": {
			"who": "Captain Cook",
			"text": "A fair hand. Your coast closes, and your track is honestly laid down.",
			"pose": "reading",
			"next": "ask",
		},
		"ask": {
			"who": "Captain Cook",
			"text": "But there are places here, and here, where your line is as firm as "
					+ "all the rest. Did you see that shore with your own eyes? Or did "
					+ "you draw what you supposed must be there?",
			"pose": "pointing",
			"choices": [
				{
					"text": "\"I did not see all of it, sir. I joined the line by guess.\"",
					"next": "honest_1", "trust": 1, "flag": "chart_dotted",
				},
				{
					"text": "\"I saw it all, sir.\"",
					"next": "claim_1", "trust": -1,
				},
				{
					"text": "Say nothing.",
					"next": "silent_1", "flag": "chart_dotted",
				},
			],
		},

		"honest_1": {
			"who": "Captain Cook",
			"text": "Then say so on the paper. Prick it in with a dotted line.",
			"pose": "regard",
			"next": "honest_2",
		},
		"honest_2": {
			"who": "Captain Cook",
			"text": "A chart is a promise to the next ship: here I have been, and this "
					+ "is what I saw. Where you have not been, leave her master to "
					+ "keep his own lookout.",
			"pose": "regard",
			"next": "honest_3",
		},
		"honest_3": {
			"who": "Captain Cook",
			"text": "I would sooner have an honest gap than a handsome guess. Men will "
					+ "trust their lives to this sheet long after we are home. "
					+ "It is good work. Carry on.",
			"pose": "offer",
		},

		"claim_1": {
			"who": "Captain Cook",
			"text": "Did you.",
			"pose": "regard",
			"next": "claim_2",
		},
		"claim_2": {
			"who": "Captain Cook",
			"text": "I was on deck when we passed that shore, and I could not have sworn "
					+ "to every cable of it. But your eyes are younger than mine. "
					+ "Perhaps they are better.",
			"pose": "regard",
			"next": "claim_3",
		},
		"claim_3": {
			"who": "Captain Cook",
			"text": "A chart is a promise to the next ship. See that this one is kept. "
					+ "That will do.",
			"pose": "offer",
		},

		"silent_1": {
			"who": "Captain Cook",
			"text": "No answer. Then I take it you are not certain, and that is an "
					+ "answer of a kind.",
			"pose": "regard",
			"next": "silent_2",
		},
		"silent_2": {
			"who": "Captain Cook",
			"text": "Dot the line wherever you are not sure of it. And next time, tell "
					+ "me so before I must ask. A chart is a promise to the next ship. "
					+ "Carry on.",
			"pose": "offer",
		},
	},
}
