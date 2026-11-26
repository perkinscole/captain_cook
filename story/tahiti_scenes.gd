class_name TahitiScenes
extends RefCounted
## Landfall at Matavai Bay, Tahiti, 1769. One conversation in three places:
## the quarterdeck, the beach, and the quarterdeck again.
##
## PLACEHOLDER WRITING, AND AN INVENTED SCENE. The player's errand, the
## boat-hook and everything said here are made up. It is built on things the
## record supports, which should each be checked before this is final:
##   - Cook's written rules for the stay: cultivate friendship, "all
##     imaginable humanity", one person appointed to trade for provisions.
##   - Iron was highly prized, and things were often taken from the ships.
##   - Cook's answer to theft was to seize canoes until the thing came back,
##     and the canoes often belonged to people who had taken nothing.
##   - HMS Dolphin fired on the people of Matavai Bay two years earlier.
##   - Tupaia was from Ra'iatea, driven out by Bora Bora, and later sailed
##     in Endeavour. "Taio" is a formal bond of friendship.
##   - Plantain branches were offered as a sign of peace.
## Tupaia is written in plain English: he and the player understand each
## other through a mix of languages and gesture, and broken speech would
## make him sound less clever than he was.
##
## Extra keys used here: "speaker" picks which figure the view turns to, and
## "stage" moves the scene ("deck" or "shore").

const LANDFALL := {
	"start": "anchor",
	"nodes": {
		"anchor": {
			"stage": "deck",
			"text": "The anchor goes down in Matavai Bay. Canoes are already putting out "
					+ "from the black sand beach, loaded with coconuts and breadfruit.",
			"next": "rules_1",
		},
		"rules_1": {
			"who": "Captain Cook", "speaker": "cook", "pose": "regard",
			"text": "You know my rules for this place, and I will have them kept. We are to "
					+ "cultivate a friendship with these people, and treat them with all "
					+ "imaginable humanity.",
			"next": "rules_2",
		},
		"rules_2": {
			"who": "Captain Cook", "speaker": "cook", "pose": "regard",
			"text": "One officer trades for the ship's provisions and no one else. Iron buys "
					+ "food and nothing but food. Today that officer is you. Take the boat. "
					+ "Bring me back greens and hogs, and bring me back no quarrel.",
			"next": "tupaia_1",
		},
		"tupaia_1": {
			"speaker": "tupaia_deck",
			"text": "A tall man in fine bark cloth has come aboard with Mr Banks. He has "
					+ "been watching you, not the captain. He speaks partly in his own "
					+ "tongue and partly in the English he has gathered from Mr Banks. "
					+ "With gestures, you find you can follow him.",
			"next": "tupaia_2",
		},
		"tupaia_2": {
			"who": "Tupaia", "speaker": "tupaia_deck",
			"text": "I am Tupaia. I am not of this island. My island is Ra'iatea, to the "
					+ "west, and men of Bora Bora hold it now.",
			"next": "tupaia_3",
		},
		"tupaia_3": {
			"who": "Tupaia", "speaker": "tupaia_deck",
			"text": "I will go with you to the beach. You come to buy. Here, a man first "
					+ "gives. A gift makes a friend, a taio, and friends feed one another. "
					+ "A stranger who only bargains is still a stranger.",
			"choices": [
				{
					"text": "\"Then we begin with gifts, before we ask for anything.\"",
					"next": "open_gifts", "flag": "tupaia_warm",
					"relations": {"tahiti": 2}, "regard": {"tupaia": 1},
				},
				{
					"text": "\"The captain wants a set price in nails and beads, "
							+ "the same for every man.\"",
					"next": "open_barter", "flag": "open_barter",
				},
				{
					"text": "\"First the marines fire a volley over the water, "
							+ "so that everyone knows what a musket is.\"",
					"next": "open_muskets",
					"relations": {"tahiti": -2}, "regard": {"tupaia": -1},
				},
			],
		},

		"open_gifts": {
			"stage": "shore",
			"text": "On the sand you lay out beads and a hatchet before an old man Tupaia "
					+ "points out to you. He looks at them for a long time, then sends boys "
					+ "running. They come back with plantain branches, and then with food: "
					+ "far more than the gifts were worth.",
			"next": "theft_1",
		},
		"open_barter": {
			"stage": "shore",
			"text": "On the sand you set out nails and beads in rows and hold up fingers for "
					+ "the price. The trade is brisk and orderly. Nobody smiles much. "
					+ "Tupaia stands a little apart.",
			"next": "theft_1",
		},
		"open_muskets": {
			"stage": "shore",
			"text": "The volley cracks across the bay. Birds go up from the trees. Children "
					+ "are carried back from the beach, and for a while nobody comes at all.",
			"next": "open_muskets_2",
		},
		"open_muskets_2": {
			"who": "Tupaia", "speaker": "tupaia",
			"text": "Now they know what you carry. They knew already. A ship like yours came "
					+ "here two years ago, and its great guns killed many on this beach.",
			"next": "theft_1",
		},

		"theft_1": {
			"speaker": "pascoe",
			"text": "The last baskets are being counted when Will Pascoe gives a shout. A "
					+ "young man is running up the beach with the boat-hook from your boat, "
					+ "its iron head flashing in the sun.",
			"next": "theft_2",
		},
		"theft_2": {
			"who": "Will Pascoe", "speaker": "pascoe",
			"text": "He has our boat-hook, sir! The marines can stop him. Shall they fire?",
			"next": "theft_3",
		},
		"theft_3": {
			"who": "Tupaia", "speaker": "tupaia",
			"text": "Do not. I know whose son he is. Iron is a great thing here. There is "
					+ "none in all these islands but what ships bring. Let me go to his "
					+ "family and ask for it. It will come back by evening, and no one shamed.",
			"next": "theft_4",
		},
		"theft_4": {
			"text": "Along the beach, drawn up above the tide, lie a row of canoes. You know "
					+ "what many a captain would do: hold the canoes until the iron comes back.",
			"choices": [
				{
					"text": "\"No firing. Go, Tupaia. We will wait for you.\"",
					"next": "end_ask", "flag": "theft_asked", "trust": 1,
					"relations": {"tahiti": 2}, "regard": {"tupaia": 2},
				},
				{
					"text": "\"No firing. Haul two of those canoes down to the boat. "
							+ "They go free when the boat-hook comes back.\"",
					"next": "end_seize", "flag": "theft_seized",
					"relations": {"tahiti": -2}, "regard": {"tupaia": -1},
				},
				{
					"text": "\"No firing. Let him run. It is one boat-hook, "
							+ "and we need say nothing of it.\"",
					"next": "end_let_go", "flag": "theft_let_go", "trust": -1,
				},
			],
		},

		"end_ask": {
			"flag": "tupaia_warm",
			"text": "You wait through the heat of the afternoon, and the men grumble. Near "
					+ "sunset Tupaia comes back along the sand with the boat-hook over his "
					+ "shoulder. An older man walks beside him, carrying a small pig as "
					+ "if it were an apology.",
			"next": "end_ask_2",
		},
		"end_ask_2": {
			"who": "Tupaia", "speaker": "tupaia",
			"text": "This is the father. He says his son is young, and iron made him "
					+ "foolish. He asks that you eat with him when you next come ashore.",
			"next": "report",
		},
		"end_seize": {
			"text": "The marines drag two canoes down to the water. Their owners come "
					+ "running and shouting. Within the hour the boat-hook is thrown down "
					+ "on the sand. After that, nobody will sell you anything.",
			"next": "end_seize_2",
		},
		"end_seize_2": {
			"who": "Tupaia", "speaker": "tupaia",
			"text": "Those canoes belong to fishermen. They took nothing from you. Tonight "
					+ "their families eat no fish, and they will remember who stopped the "
					+ "canoes, not who took the iron.",
			"next": "report",
		},
		"end_let_go": {
			"text": "You watch him go. The marines lower their muskets. Pascoe stares at you.",
			"next": "end_let_go_2",
		},
		"end_let_go_2": {
			"who": "Tupaia", "speaker": "tupaia",
			"text": "It is a small thing. But your captain counts his iron. Small things "
					+ "are counted on your ship. I have seen it.",
			"next": "report",
		},

		"report": {
			"stage": "deck",
			"who": "Captain Cook", "speaker": "cook", "pose": "regard",
			"text": "Well? Let me have your account. All of it.",
			"next": "report_ask",
			"branches": [
				{"flag": "theft_seized", "next": "report_seize"},
				{"flag": "theft_let_go", "next": "report_let_go"},
			],
		},
		"report_ask": {
			"who": "Captain Cook", "speaker": "cook", "pose": "regard",
			"text": "You lost half a day over a boat-hook. And you have brought me back the "
					+ "boat-hook, a boat full of food, and a man who wants you at his table. "
					+ "That is half a day well spent. I shall remember how it was done.",
			"next": "farewell",
		},
		"report_seize": {
			"who": "Captain Cook", "speaker": "cook", "pose": "regard",
			"text": "It is what I should have done myself. A theft must never be seen to "
					+ "pay, or we shall not keep a nail in the ship.",
			"next": "report_seize_2",
		},
		"report_seize_2": {
			"who": "Captain Cook", "speaker": "cook", "pose": "at_ease",
			"text": "Yet you tell me the canoes were not the thief's. Hm. We want these "
					+ "people's friendship more than we want a boat-hook. Think on that. "
					+ "I shall.",
			"next": "farewell",
		},
		"report_let_go": {
			"who": "Captain Cook", "speaker": "cook", "pose": "regard",
			"text": "The boatswain tells me there is a boat-hook short in the pinnace. "
					+ "I hear it from him, and not from you.",
			"next": "report_let_go_2",
		},
		"report_let_go_2": {
			"who": "Captain Cook", "speaker": "cook", "pose": "at_ease",
			"text": "I can forgive the loss of a boat-hook. Mercy is no fault. But I will "
					+ "have the truth of my own boats, and I will have it first. That will do.",
			"next": "farewell",
		},

		"farewell": {
			"who": "Tupaia", "speaker": "tupaia_deck",
			"text": "Your ship has many clever things in it, and not much patience. "
					+ "I am still deciding what I think of you.",
			"branches": [{"flag": "tupaia_warm", "next": "farewell_warm"}],
			"next": "farewell_cool",
		},
		"farewell_cool": {
			"text": "He goes down into Mr Banks's boat without looking back.",
		},
		"farewell_warm": {
			"who": "Tupaia", "speaker": "tupaia_deck",
			"text": "But you listen. Not all of your people listen. When this ship leaves, "
					+ "I think I will sail in her. There are islands to the west that your "
					+ "captain has not dreamed of, and I know the way to them.",
		},
	},
}
