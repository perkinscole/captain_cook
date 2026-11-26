# Models

Models generated with Meshy from reference pictures that were approved first.
Anything that uses one falls back to its code-built version if the file is
missing (see `scripts/models.gd`).

## In the game

| File | Used for |
| --- | --- |
| `seaman/seaman_walking.glb` | The leadsman, boatswain's mate and cook, and the hands who walk the deck |
| `characters/old_seaman/` | Trull, the quartermaster at the wheel |
| `characters/ships_boy/` | Nicholas Young at the masthead |
| `characters/cook/` | Captain Cook |
| `characters/officer/` | Mr Clerke, standing on the quarterdeck |
| `characters/marine/` | The sentry pacing the quarterdeck |
| `characters/banks/` | Mr Banks, in the great cabin |
| `ship/hull.glb` | An outer shell wrapped round the code-built ship. Only seen from outside. |
| `ship/wheel.glb`, `capstan.glb`, `windlass.glb`, `anchor.glb`, `lantern.glb` | Deck fittings |

Each character folder has the rigged body (`*_rigged.glb`) and the same body
with a walking clip (`*_walking.glb`), which is the one the game loads.

## Not in the game yet

| File | Why |
| --- | --- |
| `ship/boat.glb` | About 1.3 million triangles: too heavy to use twice on deck until it is slimmed down |
| `gun/gun_4pdr.glb` | About 400,000 triangles, and it appears four times |

## Still built in code

The decks, cabins and lower deck you walk on, masts, yards, sails and rigging,
the topmen who climb to the yards, and Tupaia.

`meshy_output/` holds the reference pictures and rendered previews from each
step. The dress and the fittings were described from memory of the period and
have not been checked against sources.
