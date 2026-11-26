# Captain Cook Voyages Game: Project Plan

A brief to bring into a code project. It captures what was decided in the brainstorm, what is still open, and a build order that starts very small.

## Concept

A first-person, 3D video game with an oil-painting look, about Captain James Cook's voyages. The player is a young officer serving under Cook, who watches the captain change over the voyages. A character-driven story aboard the ship is the heart of the game. The game is somewhat educational, aimed at middle schoolers, played at home on a PC. It is a solo personal project, with Claude as the main coding tool and helper for code-made assets.

## Design pillars

1. **Story is the heart.** Cook, his officers and the crew are characters you talk to and act on. Drama and tension aboard ship drive the game, and sometimes pull against the mission.
2. **Charting is your job.** The map starts blank. You fill it in by sailing coastlines and taking measurements.
3. **You serve under a captain.** You carry out Cook's orders and choose how, or whether, to obey as they grow harsher.
4. **Weather is the antagonist at sea.** Wind and storms create the pressure between landfalls.
5. **Encounters have consequences.** Choices at landfall, including first contact, ripple forward.
6. **Teach by doing.** The game explains sailing and history the way a good first mate would, not through lectures.

## Story and characters

The arc is Cook's change: careful and humane on the first voyage, harsh and erratic by the third, seen by an officer who admires him. The long passages at sea are where this drama plays out.

- **Player character:** an invented young officer who does the charting and carries out orders. This is the current leaning. The alternative is playing Cook and watching your own judgment slip.
- **Cook:** the captain, and the figure the player watches change.
- **Joseph Banks:** the wealthy, headstrong naturalist of the first voyage, who half treats the expedition as his own.
- **Tupaia:** the Tahitian navigator who joins Endeavour on the first voyage and sees events from the other side.
- **Crew hands:** a small recurring cast with their own loyalties and grievances.

The central tension is obedience against conscience. The story should sometimes run against the Admiralty's stated objectives.

### Example pivotal scene: Moorea, 1777

A goat is stolen from the ship. Cook orders the player to take the marines ashore and burn houses and canoes until it is returned. On the beach, the player can give the order, stall and burn the minimum, or row back and refuse in front of the crew. That evening Cook sends for the player, asks only to see the chart of the bay, and praises it. The horror is not a monster but a man the player still admires.

### Keeping animation light

Tell the story through dialogue, sound and staging, not full character animation. Characters hold poses at the rail or chart table, with a few idle loops. Walking and rowing use stock motions from a library such as Mixamo. Return of the Obra Dinn tells its story in frozen scenes, and Firewatch builds a relationship almost entirely through voice.

## Story map

The story runs in three acts, one per voyage, and follows Cook from his best on the reef to his death at Kealakekua Bay. The events are historical. The player's officer and the player's part in each beat are invented. The cold open and flashback are proposed, not decided.

### Act 1: First voyage, Endeavour, 1768 to 1771. The captain worth following.

| Beat | Where and when | What happens | The player's part |
| --- | --- | --- | --- |
| Cold open: the reef | Great Barrier Reef, June 1770 | The leadsman calls deep water, then the ship strikes coral at night and starts to flood. Cook stays calm and saves her. | Tutorial under pressure: pumps, guns overboard, haul her off on the tide. |
| Flashback: Tahiti | Matavai Bay, April to July 1769 | The transit of Venus is observed. Cook punishes his own men for wronging islanders. Tupaia joins the ship. | Learn charting and conversation. Meet Banks, Tupaia and the crew. |
| Sealed orders | South Pacific, 1769 | Cook opens secret orders to search for the southern continent. | First sense that the mission has layers the crew is not told. |
| New Zealand | October 1769 to March 1770 | First meetings with Māori go badly and people are killed. Tupaia can speak with them. Both islands are charted over six months. | The big charting chapter. First hard encounter choices, with Tupaia as guide. |
| The coast north | Botany Bay and north, 1770 | The ship works up an unknown coast into a maze of reefs. | Soundings carry dread, because the player knows what is coming. |
| The reef again | June to August 1770 | The story catches up with the cold open. Weeks of repairs ashore at the Endeavour River. | Play the aftermath. Trust in Cook is at its height. |
| Batavia | Late 1770 | Disease sweeps the ship in port. Tupaia and many of the crew die. | Loss of characters the player knows. The cost of the voyage lands. |

### Act 2: Second voyage, Resolution, 1772 to 1775. The cracks.

| Beat | Where and when | What happens | The player's part |
| --- | --- | --- | --- |
| Banks walks away | England, 1772 | Banks quits before sailing after a fight over the ship. | A short scene. The player is now more senior and closer to Cook. |
| Into the ice | Antarctic Circle, 1773 to 1774 | The ships push further south than anyone before, through fog and pack ice, and lose each other. | Survival sailing. Crew morale and fear become the main pressure. |
| Cook falls ill | Pacific, early 1774 | The captain is gravely sick for weeks. | The player carries more of the ship. First doubt about his judgment. |
| Grass Cove | New Zealand, December 1773 | Ten men from the sister ship Adventure are killed ashore. The news reaches Cook later. | The crew wants revenge. The player hears both sides. |
| Home with the answer | 1775 | There is no temperate southern continent. A new chronometer has made the charts far more accurate. | Mission complete. The player is offered the third voyage. |

### Act 3: Third voyage, Resolution and Discovery, 1776 to 1780. The unravelling.

| Beat | Where and when | What happens | The player's part |
| --- | --- | --- | --- |
| No revenge | Queen Charlotte Sound, February 1777 | Cook meets the man blamed for Grass Cove and refuses to punish him. The crew is furious. | Defend the captain to the crew, or side with them. |
| Tonga | 1777 | Punishments for theft turn harsh, for islanders and crew alike. | The player is asked to carry them out. |
| Moorea | October 1777 | A goat is stolen and Cook orders houses and canoes burned. | The pivotal choice: obey, stall, or refuse. |
| First contact in Hawaii | Kauai, January 1778 | The ships reach islands no European has charted. | A last moment of wonder and good charting. |
| The passage fails | Alaska and the Bering Strait, 1778 | Ice blocks the way north. Cook forces unpopular rations on a crew near revolt. | Stand between the captain and the crew. |
| Kealakekua Bay | Hawaii, January to February 1779 | A grand welcome, then a forced return with a broken mast. A boat is stolen, Cook goes ashore to seize the chief, and he is killed on the beach. | The final choice, shaped by everything before it. The player cannot save him. |
| The long way home | 1779 to 1780 | The ships try the north once more and sail home without their captain. | Epilogue. The player's charts and choices are weighed. |

## Character map

The crew comes in three tiers: key characters with full arcs and side quests, speaking characters with a few lines each, and background crew who cannot be talked to. The table lists the first two tiers, key characters first. All of them are real. The personalities are a starting sketch from the historical record and should be checked before any dialogue is written.

| Character | Tier | Role aboard | Voyages | What they bring to the story |
| --- | --- | --- | --- | --- |
| James Cook | Key | Captain | 1, 2, 3 | The centre of the story. The player's mentor, then the player's problem. |
| Charles Clerke | Key | Master's mate, later lieutenant, later captain of the sister ship Discovery | 1, 2, 3 | Cheerful and well liked. The player's oldest friend across all three voyages. Takes command after Cook's death. |
| Joseph Banks | Key | Naturalist | 1 | Rich, charming, headstrong. Pulls the player toward shore and away from duty. |
| Tupaia | Key | Tahitian navigator and priest | 1 | Sees the voyage from the other side. Guide and translator in encounters. His death at Batavia is the first great loss. |
| Georg Forster | Key | Naturalist's son and assistant | 2 | A teenager with sharp eyes and strong opinions about how islanders are treated. |
| James King | Key | Lieutenant | 3 | Thoughtful and humane. The player's conscience, and an ally if they push back. |
| William Bligh | Key | Sailing master | 3 | A gifted, abrasive young surveyor. The player's rival at the chart table. |
| John Gore | Speaking | Lieutenant | 1, 3 | American-born, hugely experienced, practical. Tells the player how things are really done. |
| Zachary Hicks | Speaking | Second in command | 1 | Steady and quiet. Shows what loyal service to a good captain looks like. |
| Daniel Solander | Speaking | Naturalist | 1 | Banks's genial Swedish colleague. Explains the plants, animals and science. |
| Sydney Parkinson | Speaking | Artist | 1 | A gentle young Quaker who draws everything. A moral voice early on. |
| Charles Green | Speaking | Astronomer | 1 | Teaches the player navigation by the stars and the transit of Venus. |
| Jonathan Monkhouse | Speaking | Midshipman | 1 | A peer of the player. Knows the trick that saves the ship on the reef. |
| John Thompson | Speaking | Ship's cook | 1 | The one-handed cook. Lower-deck gossip and a read on crew mood. |
| Nicholas Young | Speaking | Ship's boy | 1 | About twelve years old, first to sight New Zealand. A way in for younger players. |
| Johann Forster | Speaking | Naturalist | 2 | Brilliant and quarrelsome. A source of friction in the great cabin. |
| William Wales | Speaking | Astronomer | 2 | Keeper of the new chronometer. Ties directly into chart accuracy. |
| Hitihiti | Speaking | Young man from Bora Bora who joins the ship | 2 | Sails into the Antarctic ice with the crew. Wonder and culture shock in reverse. |
| George Vancouver | Speaking | Midshipman | 2, 3 | A boy learning the trade. Someone for the player to mentor. |
| William Anderson | Speaking | Surgeon and naturalist | 3 | Troubled by Cook's punishments and seriously ill himself. A private confidant. |
| Mai | Speaking | Passenger returning home from England | 3 | Caught between two worlds after two years as a London celebrity. |
| John Ledyard | Speaking | Corporal of marines | 3 | An ambitious American. The marines' view of orders that turn violent. |

The lower deck is thinly recorded, so a few ordinary crew hands should be invented: an old sailor who has served under harsher captains, a reluctant young hand, and a boatswain's mate who carries out the floggings.

Those invented hands sit in the speaking tier. Everyone else in the ship's company is background: they work, react and mutter, and make the ship feel alive, but cannot be talked to. No more than four key characters are aboard at any one time, which keeps the writing load manageable.

### Side quests

Each key character except Cook has a side quest. Cook's relationship with the player is the main story. Quests marked real are built on recorded events. The others are invented to fit the person.

| Character | Side quest | Basis | What is at stake |
| --- | --- | --- | --- |
| Tupaia | **The chart of islands.** Help Tupaia draw his map of the Pacific from memory, and learn how his people navigate without instruments. | Real. Tupaia drew such a chart aboard Endeavour. | Two ways of knowing the sea. Deepens the bond before Batavia. |
| Banks | **Specimens against orders.** Banks talks the player into rowing him ashore to collect when the captain wants to sail. | Invented, in character. | Banks's favour against Cook's trust. |
| Clerke | **Keeping spirits up,** then **the secret.** Early on, help him lift the crew through a dull passage. On the third voyage, he asks the player to keep quiet about how ill he is. | The first is invented. The second draws on his real illness. | Friendship against duty to report. |
| Georg Forster | **The other journal.** Georg is writing a frank account and asks the player what really happened ashore. | Invented, drawing on the candid book he later published. | Honesty against loyalty to the ship. |
| King | **The observatory.** Help King set up his instruments ashore. In private, he asks what the player makes of the captain's orders. | His astronomy is real. The conversations are invented. | Whether the officers speak up together or stay silent. |
| Bligh | **The survey race.** Chart a harbour alongside Bligh, who picks the player's work apart. | Invented, drawing on his real skill and temper. | Share credit, compete, or learn from him. |

Speaking characters can offer small favours, shorter than a quest:

- **Green and Banks: the stolen quadrant.** The instrument needed for the transit of Venus goes missing at Tahiti and must be recovered. Real.
- **Parkinson: the flies.** Keep the insects off his paint while he works. Real, the flies ate his colours at Tahiti.
- **Nicholas Young: first to sight land.** Help the boy win the reward the captain has promised. Real.
- **Wales: wind the clock.** The chronometer must be wound on time every day without fail. Real.
- **Mai: a house at Huahine.** Help build the house he will live in when the ships leave. Real.

## Primary objective

Each voyage has real Admiralty orders, and the goal is to complete the mission and get home.

- **First voyage (1768 to 1771, Endeavour):** reach Tahiti in time to observe the transit of Venus, then open sealed orders to search for the great southern continent.
- **Second voyage (1772 to 1775):** settle whether that continent exists.
- **Third voyage (1776 to 1780):** search for the Northwest Passage.

The player is scored at the end of a voyage on three things: chart accuracy, crew survival, and how relations were left with the people they met. It should be possible to complete the mission and still have done harm.

## Core loop

1. Sail and chart at sea, under wind and weather.
2. Make landfall.
3. Handle the encounter.
4. Resupply.
5. Push on.

## How it plays

The game is hard in three ways: seamanship, charting accuracy, and judgment. It asks for both quick reactions and tough decisions. The player does not get stronger. They rise in rank and are handed more of the ship.

### Difficulty curve

| Voyage | Seas | What gets harder |
| --- | --- | --- |
| 1 | Warm water, trade winds, coral reefs | Learning the ship. Reefs punish careless soundings. |
| 2 | Antarctic ice, fog and gales | Survival sailing, crew morale, long gaps between landfalls. |
| 3 | Arctic ice and uncharted coasts | Everything before, under a captain whose orders can no longer be trusted. |

### Rank progression

| Rank | Proposed timing | What the player does |
| --- | --- | --- |
| Midshipman | First voyage | Hands-on work: heave the lead, sketch coastlines, row boats, carry messages. |
| Master's mate | Late first voyage and second | Stand a watch, lead a boat party ashore, run a survey. |
| Lieutenant | Third voyage | Command the deck in a storm, give orders to others, speak for the officers. |

Promotion is earned through chart quality, seamanship and the captain's trust. It can be delayed.

### Physical actions

Shipboard work uses manual inputs in the style of GTA: move, circle or hold the sticks and triggers under time pressure. Each is designed on a controller first, then given a keyboard and mouse equivalent.

| Task | Input | Where it matters |
| --- | --- | --- |
| Turn the capstan | Circle the stick | Raising the anchor, hauling the ship off the reef |
| Heave the lead line | Swing and release on the beat | Soundings in shallow water |
| Work the pumps | Alternate the triggers | Flooding after the reef, storms |
| Hold the wheel | Hold a trigger and counter-steer | Gusts and heavy seas |
| Haul a line | Hold a trigger and pull in rhythm | Making and reducing sail |

Proposed: failing costs time, damage, injuries or trust, and the story carries on. A hard game over is rare.

### Timed choices

In tense moments the options fade and the player has only seconds to pick. Letting them run out is itself an answer. Timed choices are for crises and confrontations, such as the beach at Moorea, not everyday talk.

### Talking to the crew

Dialogue is not fixed. The player walks up to someone, holds a trigger to focus on them, and picks what to say from a small menu, as in GTA. Options fit the moment, such as greet, ask about their work, lend a hand, or needle them. They change with rank and with the relationship.

### Relationships

Friendships and rivalries are made through play, not scripted.

- Each key and speaking character tracks how they feel about the player, based on what the player says and what they see the player do.
- Both friendship and rivalry are possible with the same character.
- Doors close. Snub Banks and his side quest is gone. Cross Bligh and he will not share his survey. Lose Cook's trust and someone else gets the boat command.
- History fixes each character's fate. The player's relationship with them is the player's own.
- Who stands with the player in pivotal scenes depends on who they have befriended.

## Decisions so far

| Topic | Decision |
| --- | --- |
| Platform | PC, play at home. No Chromebook or school constraints. |
| Audience | Middle schoolers |
| Heart of the game | A character-driven story aboard the ship, with a full arc |
| Player character | Leaning: an officer serving under Cook, not Cook himself |
| Camera | First person |
| Art style | Oil painting in motion: realistic proportions, brushed surfaces, moody high-contrast light. Not low-poly, not photoreal. |
| Animation | Kept light: posed characters, dialogue, sound and staging |
| Team | Solo, with Claude for code and code-made assets |
| Engine | Proposed: Godot 4 with GDScript. Not yet confirmed. |

References for first-person sailing and storytelling: Return of the Obra Dinn, Sailwind, Firewatch. Visual references are under Art direction.

## Art direction

The game should look like an 18th-century oil painting in motion: moody, with deep shadows, whites that glow and reds that look on fire. It is not low-poly and not photoreal.

- **Touchstones.** The volcano painting Cole saw at the North Carolina Museum of Art, likely Volaire's The Eruption of Mt. Vesuvius from 1777, to be confirmed. Joseph Wright of Derby for light out of darkness. William Hodges, the artist on Cook's second voyage, for Tahiti and the Antarctic ice.
- **Light.** Huge dynamic range. A few strong sources, such as a lantern, a fire, the moon or a low sun, with real darkness around them.
- **Surfaces.** Realistic proportions and shapes, with visible brushwork in place of fine detail. A limited palette for each scene.
- **Technique.** A painterly post-process filter of the Kuwahara type over the 3D scene, strong bloom on highlights, and textures painted to match.
- **Showcase scenes.** The reef at night, the lantern-lit lower deck, beach fires at Moorea, moonlit ice.
- **Game references.** Sea of Thieves for ocean and sky, Eastshade for a painted first-person world.

The risk to test in the first prototype is whether the filter holds up in motion without shimmering, keeps faces readable, and runs fast enough.

## Open questions

- **Player character.** An officer under Cook is the leaning, with playing Cook as the alternative. Who the officer is, and which voyages they sail on, is not yet decided.
- **Orders or wheel?** Current answer: start hands-on as a midshipman and graduate to giving orders with rank. How each feels still needs the first prototype.
- **Engine.** Godot 4 is the recommendation because its scenes and settings are text files that Claude can write and edit directly. Unity's advantage is its asset store.
- **Scope of the full game.** One voyage first, or all three.
- **How conversations and encounters play.** Conversations use the focus menu and timed choices. How landfall encounters and trade play is still open.
- **Voice or text.** Whether characters are voiced, and how.

## First prototype: chart one island

The smallest thing that proves the idea is fun.

- One ship, one patch of ocean, one island.
- Wind with a direction and strength that changes over time.
- First-person view from the deck.
- Two control modes to compare: giving orders (set heading, make or reduce sail) and direct steering.
- A chart that starts blank and draws the coastline as the ship sails within sight of it.
- Done when the player can sail around the island and see a finished chart.

Not in the prototype: crew, supplies, storms, encounters, story, scoring.

## Milestones after the prototype

1. **Sailing feel.** Pick the control mode. Add sail states, points of sail, and basic weather.
2. **One story scene.** A single conversation with Cook and one choice, using posed characters and placeholder text or voice, to test the light-animation approach.
3. **Charting depth.** Soundings, measurement accuracy, a chart table view.
4. **Crew and supplies.** A small named cast with health, morale, food and scurvy. How well orders are carried out depends on crew state.
5. **Landfall and encounters.** One island with one encounter that has real choices and consequences.
6. **A voyage slice.** England to Tahiti with the transit of Venus as the goal, a story thread running through it, scored at the end.
7. **Expand.** Rest of the first voyage, then later voyages and Cook's full arc.

## Asset plan

**Made in code with Claude:** ocean and sky shaders, procedural islands and terrain, chart and UI art, the oil-painting shader and lighting setup, simple props through Blender scripts.

**Buy or model by hand:** the ship, characters, and anything that needs to look detailed and hand-crafted.

## Notes for the coding assistant

- Target Godot 4 only. Do not use Godot 3 syntax or APIs. If unsure whether something is Godot 4, say so.
- Keep the scope to the current milestone. Do not build ahead.
- Keep systems separate so they can be swapped: ship movement, wind, input mode, charting.
- Prefer simple placeholder shapes for art until the prototype is fun.
- Historical content should be accurate and should present the people Cook met as people with their own perspectives, not as scenery.
