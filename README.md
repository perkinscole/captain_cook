# Captain Cook Voyages

A first-person game about Captain James Cook's voyages, seen by a young officer
who serves under him. The full brief is in [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md).

## Current state: chart one island, then show the chart to Cook

One ship, one patch of ocean, one island, and a chart that starts blank and
fills in as you sail within sight of the coast. It is done when you have sailed
round the island and the chart is complete.

On top of that, the sailing now has some depth:

- **Sail states.** Five orders from bare poles to all sail, with reefed
  topsails for heavy weather. The hands take a few seconds to make or shorten sail.
- **Points of sail.** She is fastest with the wind on the quarter and cannot
  sail closer than about 50 degrees to it. Closer than that the sails shiver,
  and head to wind they are taken aback and she goes slowly astern, with the
  wheel working backwards. She also makes leeway (slides downwind) when close-hauled.
- **Tacking.** With good speed she will carry her way through the wind onto the
  other tack. Too slow and she misses stays; turn the other way round instead.
- **Weather.** Fair spells are broken by squalls (a warning, then hard gusts, a
  wind shift, a steep sea and poor visibility) and by banks of mist. Carry too
  much sail in a squall and one blows out. In thick weather you must stand
  closer inshore to chart the coast.

And there is work to do while you sail:

- **Reefs and the lead line.** Coral reefs lie hidden off the island. Press
  Space to heave the lead and learn the depth; let go when the marker is in the
  green for a true reading. The lead only reaches bottom below about 9 knots,
  so shorten sail to sound. Soundings are written on the chart in fathoms. In
  clear weather the masthead lookout may spot pale water dead ahead; in mist or
  a squall you only have the lead. Strike a reef and she has to be hauled off.
- **Bearings.** Coast you sail past is only sketched by eye, in pencil, and is
  a little out of place. Twelve headlands each have a landmark. Raise the
  spyglass, put the cross on one and press F, then do it again from further along. Where the
  two lines cross fixes the headland, and the coast between fixed headlands
  turns to ink. Lines that cross near a right angle give the best fix.
- **The chart table.** M opens the full chart, with headland names, sounding
  figures and an accuracy score.

The ship now has a crew and stores:

- **Five named hands** stand about the ship: the quartermaster at the wheel
  behind you, the leadsman at the starboard side, the boatswain's mate by the
  mainmast, the cook at his stove on the lower deck, and the ship's boy at the masthead. Walk up to one, look at him
  and press E for a word (the boy aloft you hail from the deck); what they say tells you how the lower deck is
  feeling. Each has health and morale, and does his job worse when either is
  low: slower sail handling, a sluggish helm, wilder soundings, a lookout who
  sees less far.
- **Days pass** (one every two minutes). Fresh greens last three days. After
  that scurvy sets in unless sour krout is served, which the men dislike.
  Salt provisions last eight days, longer on short rations, which the men
  dislike more. An extra issue of grog lifts spirits, three times only.
- **So time matters.** Staying out to fix every headland makes a truer chart
  and a sicker, sourer crew.

And there is a landfall. The island is a stand-in for Tahiti in 1769 (the
shape is made up; only Point Venus and Matavai Bay are real names). Matavai
Bay is marked on the chart on the north side. Bring the ship nearly to a stop
there and press Enter to anchor. Cook sends you ashore to trade for fresh food,
and Tupaia, a navigator and priest from Ra'iatea, goes with you. Two choices on
the beach decide how much food comes back, how the people ashore regard the
ship, what Tupaia makes of you, and what Cook says afterwards. The scene is
invented and its historical grounding is listed, for checking, at the top of
`story/tahiti_scenes.gd`.

There is also one story scene, to test telling the story through poses and
dialogue instead of animation. Captain Cook stands on the quarterdeck, to your
right. Walk up to him, look at him and press E to speak. Once the survey is complete he asks to
see the chart and puts one question to you; your answer changes how he regards
you and how the finished chart is drawn. The ship lies hove to while you talk.

Everything is placeholder shapes, and the dialogue is placeholder writing that
still needs checking against the historical record. There is no scoring yet, and nobody dies.

Control is by giving orders (you call a course and the helmsman steers). The
first prototype also tried holding the wheel directly; giving orders was chosen.

## Look, sound and interface

- **Title and pause pages.** The game opens on a title page. Esc pauses and
  shows the keys.
- **Lessons.** Choose "Begin, with Mr Clerke" and a shipmate teaches one thing
  at a time; each lesson ends when you have done it. T skips them. The weather
  stays fair and the stores do not run down until the lessons are over.
- **Interface.** A steering compass shows the heading, the wind (blue arrow),
  the part of the compass she cannot sail into (red wedge) and the course
  ordered (brass pointer). Panels show the ship, the crew and the stores. What
  the hands call back appears at the bottom left. H shows the keys.
- **Oil paint.** The brush strokes are painted onto the things themselves:
  the hull, deck, sails, people, rocks, trees and land each carry strokes in
  their own space, so the paint stays on the object as it moves. Every stroke
  is a slightly different mix of the colour, with paint piled along its sides
  and the marks of the brush hairs, and the scene's own light catches the
  ridges. Strokes stay about the same size on screen near or far. Over the
  whole picture there is a light softening into dabs, then the colouring of an
  old painting: deep shadows, warm lights, yellowed varnish and a darkened
  border. P turns the softening and colouring on and off. The sea and sky are
  painted too: strokes on the sea lie along the swell, are fixed to the water
  and drift on with the waves, and foam is laid in dabs; strokes in the sky
  are fixed to the dome of the sky, and the clouds are built of dabs with
  broken edges. The fair-weather sky is blue.
- **Waves.** Two long swells that never change, plus wind waves that run
  before the local wind and build as it blows harder, so a squall raises a
  real sea. Crests are sharp and troughs wide, whitecaps appear when it
  freshens, shallows and reefs show pale, the shore has white water, and the
  ship leaves a wake that spreads and fades astern.
- **Sea and sky.** Surf along the shore; drifting clouds that thicken in a squall; a sun
  that climbs and sinks through the day; fog with depth that catches the
  light; and seabirds over the island and in the ship's wake.
- **Spyglass.** Q (or holding the right mouse button) raises a spyglass. The
  headlands you can take a bearing on are picked out by name: rocks, bluffs
  and clumps of tall palms. Put the cross on one and press F.
- **Crew cards.** C shows each hand as a card with a drawn face that changes
  with their health and spirits.
- **The ship.** A likeness of HM Bark Endeavour that you can walk about:
  a raised forecastle with the windlass, bell and anchors; the waist with its
  hatches, pumps, guns and the boats stowed overhead; a raised quarterdeck
  with the wheel (which turns with the rudder) and capstan; and under it the
  great cabin, with stern windows, the chart table and a lantern. Ladders join
  the decks. She has full standing rigging with ratlines, bellied sails that
  fill the wrong way when taken aback, a pennant that streams downwind and the
  red ensign at the stern. Proportions are stretched a little so there is room
  to walk. People are built from rounded shapes. All of it is made in code.
- **A living ship and sea.** She lists away from the wind. People have
  jointed arms and legs, faces, queues and caps; hands walk their beats about
  the deck, stopping to lean on the rail or haul on a rope, and a marine
  sentry paces the quarterdeck. Gulls wheel over the island and follow the
  ship, frigatebirds hang high above her, dolphins come to leap in the bow
  wave, and flying fish break from the sea ahead. She pushes a V of bow waves
  with ripples inside it and white water along her sides, and in a fresh
  wind the crests sharpen, break, and leave foam behind them.
- **Things that move.** Order sail and six topmen run to the shrouds, climb
  to the yard and lay out along it; the sail does not move until they are
  there, then it is let fall from the yard or gathered up into a furl. The
  wheel turns under the helmsman's hands, the lead swings from the chains, spray
  comes over the bow when she drives into a sea, rain falls in a squall, and
  people on deck glance about them.
- **Below decks.** A hatch in the waist, just to port of the mainmast,
  leads down (walk aft onto the head of its ladder) to the lantern-lit lower deck: mess tables and sea chests, the
  galley stove with the cook at it, casks, and hammocks. A hand who falls sick
  is laid in a hammock there until he is well.
- **Sound.** Sea, wind, creaking timbers, the ship's bell, the splash of the
  lead, and a boatswain's pipe for orders. Every sound is synthesised by
  `tools/make_sounds.py`, so they are stand-ins. There are no voices yet, but
  `audio/voice/README.md` lists the lines the game will play if you record them.

## Running it

1. Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET). The project was first written against 4.3.
2. In the Godot project manager choose **Import** and pick `project.godot`.
3. Press **F5**.

## Controls

| Key | Action |
| --- | --- |
| W A S D | Walk the deck (Shift to hurry) |
| Left / Right arrows | Order the course one compass point to port / starboard |
| Up / Down arrows | Make / reduce sail |
| Space, then Space | Start the lead swinging, then let go in the green |
| Q, or hold right mouse | Raise the spyglass |
| F | Take a bearing on the landmark under the spyglass cross |
| E | Speak with the person you have walked up to and are looking at |
| Space, then 1 to 3 | Continue a conversation, then pick an answer |
| Enter | Anchor, when nearly stopped in Matavai Bay |
| M | Open or put away the chart table |
| C | Show or hide the crew and stores list |
| R / K / G | Change rations / serve sour krout / issue extra grog |
| P | Painted look on or off |
| H | Show the keys |
| T | Skip the lessons |
| Mouse | Look around |
| Esc | Pause |

A square-rigger cannot sail closer than about 50 degrees to the wind. To get
upwind, zig-zag (tack) either side of it.

## Layout

Systems are kept separate so each can be swapped:

| File | What it owns |
| --- | --- |
| `scripts/wind.gd` | Wind direction and strength over time |
| `scripts/sea.gd`, `shaders/ocean.gdshader` | The waves, and how high the water is under the ship |
| `scripts/wake.gd`, `shaders/wake.gdshader` | The ship's wake |
| `shaders/paint_strokes.gdshaderinc` | What one brush stroke is, shared by everything painted |
| `shaders/paint.gdshaderinc`, `painted.gdshader`, `scripts/paint.gd` | Brush strokes painted onto surfaces |
| `shaders/painterly.gdshader`, `impasto.gdshader` | Softening into dabs, and the colouring of an old painting |
| `scripts/sound_board.gd`, `audio/`, `tools/make_sounds.py` | Sounds, and how they are made |
| `scripts/ui/` | Theme, compass, panels, spyglass, crew cards, title and pause pages |
| `scripts/atmosphere.gd`, `shaders/sky.gdshader` | Sky, sun, clouds and fog |
| `scripts/birds.gd`, `shaders/surf.gdshader` | Seabirds, and surf on the shore |
| `scripts/sea_life.gd` | Dolphins and flying fish |
| `scripts/deckhands.gd` | Hands who walk the deck |
| `scripts/tutorial.gd` | The lessons |
| `scripts/weather.gd` | Fair weather, squalls and mist; drives the wind and visibility |
| `scripts/ship.gd` | Ship movement from wind, sail and rudder |
| `scripts/control_mode.gd`, `orders_mode.gd` | How the ship is steered (giving orders) |
| `scripts/island.gd` | Procedural island and its coastline |
| `scripts/seabed.gd` | Water depth and hidden reefs |
| `scripts/lead_line.gd`, `lead_gauge.gd` | Heaving the lead, and the timing gauge |
| `scripts/charting.gd` | Coast sketched, bearings and fixes, accuracy, the ship's track |
| `scripts/chart_view.gd` | Drawing the chart |
| `scripts/ship_layout.gd` | The plan of the ship: decks, ladders and what is in the way |
| `scripts/ship_visual.gd` | The ship model, built from that plan |
| `scripts/player.gd`, `deck_camera.gd` | Walking the deck, and the first-person view |
| `scripts/topmen.gd` | The hands who climb to work the sails |
| `scripts/deck_effects.gd` | Spray, rain and the swinging lead |
| `scripts/supplies.gd` | Stores, rations and the passing of days |
| `scripts/crew.gd`, `hand.gd` | The named hands, their health and morale, and how well each job is done |
| `story/crew_lines.gd` | What each hand says, as data |
| `scripts/landfall.gd` | The anchorage, the set on the beach, and switching between deck and shore |
| `story/tahiti_scenes.gd` | The landfall at Matavai Bay, as data |
| `scripts/dialogue.gd`, `dialogue_box.gd` | Running a conversation, and showing it |
| `scripts/figure.gd` | Posed character |
| `scripts/story_state.gd` | What the story remembers (Cook's trust, flags) |
| `story/cook_scenes.gd` | Conversations with Cook, as data |
| `scripts/main.gd` | Builds the scene and wires the above together |

## Version control note

Godot (4.4 and later) writes a small `.uid` file beside every script and
shader. Commit those along with the code. The `.godot/` folder is the editor's
cache and stays out of the repository.
