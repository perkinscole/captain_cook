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
| `ship/boat_light.glb` | The longboat and the pinnace, stowed over the waist. About 28,000 triangles. |
| `ship/gun_light.glb` | The four 4-pounder guns in the waist. About 14,000 triangles. |

Each character folder has the rigged body (`*_rigged.glb`) and the same body
with a walking clip (`*_walking.glb`), which is the one the game loads.

The boat and the gun first came back far too detailed to use (1.3 million and
400,000 triangles). Those originals are not kept here; the slimmed versions
above were made from them in Meshy and can be made again from the same tasks,
which are listed in `meshy_output/model_tasks.tsv`.

## Still built in code

The decks, cabins and lower deck you walk on, masts, yards, sails and rigging,
the topmen who climb to the yards, and Tupaia.

`meshy_output/` holds the reference pictures and rendered previews from each
step. The dress and the fittings were described from memory of the period and
have not been checked against sources.
