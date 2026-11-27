# Models

Models generated with Meshy from reference pictures that were approved first.
Anything that uses one falls back to its code-built version if the file is
missing (see `scripts/models.gd`).

## In the game

| File | Used for |
| --- | --- |
| `seaman/seaman_actions.glb` | The leadsman, boatswain's mate and cook, the hands who walk the deck, and the topmen who climb to the yards |
| `characters/old_seaman/` | Trull, the quartermaster at the wheel |
| `characters/ships_boy/` | Nicholas Young at the masthead |
| `characters/cook/` | Captain Cook |
| `characters/officer/` | Mr Clerke, standing on the quarterdeck |
| `characters/marine/` | The sentry pacing the quarterdeck |
| `characters/banks/` | Mr Banks, in the great cabin |
| `characters/tupaia/` | Tupaia, ashore at Matavai and then aboard |
| `characters/islander/` | The people on the beach at Matavai Bay |
| `ship/hull_fitted.glb` | The hull: planked sides, the inside of the bulwarks and the deck planking. Made from `source/hull.glb` by `tools/fit_hull.py`, which reshapes the model to the ship's plan in `scripts/ship_layout.gd`; run it again if that plan changes. |
| `ship/wheel.glb`, `capstan.glb`, `windlass.glb`, `anchor.glb`, `lantern.glb` | Deck fittings |
| `ship/boat_light.glb` | The longboat and the pinnace, stowed over the waist. About 28,000 triangles. |
| `ship/gun_light.glb` | The four 4-pounder guns in the waist. About 14,000 triangles. |

Each character has one file, `*_actions.glb`, holding the body, its skeleton
and its recorded clips:

| Character | Clips |
| --- | --- |
| Seaman | Idle 4, Casual Walk, Stand and Chat, Short Breathe and Look Around, Ladder Climb Loop |
| Cook, Banks, Tupaia | Idle 4, Casual Walk, Talk with Hands Open |
| Officer, old seaman | Idle 4, Casual Walk, Stand and Chat |
| Islander | Idle 4, Casual Walk, Stand and Chat, Chair Sit Idle (for the canoe paddlers) |
| Ship's boy | Idle 4, Casual Walk, Short Breathe and Look Around |
| Marine | Idle 4, Casual Walk |

The standing clip is Meshy's "Idle 4" (upright, feet together). Its plain
"Idle" is a wide, knees-bent stance that read as a hunch on deck.

`scripts/figure.gd` sorts the clips by name into idle, walk, talk, look, sit and
climb, and plays the nearest one for whatever the figure is doing. The Meshy
tasks behind every file are listed in `meshy_output/*.tsv`.

The boat and the gun first came back far too detailed to use (1.3 million and
400,000 triangles). Those originals are not kept here; the slimmed versions
above were made from them in Meshy and can be made again from the same tasks,
which are listed in `meshy_output/model_tasks.tsv`.

## Still built in code

The decks, cabins and lower deck you walk on, masts, yards, sails and rigging.

`meshy_output/` holds the reference pictures and rendered previews from each
step. The dress and the fittings were described from memory of the period and
have not been checked against sources.
