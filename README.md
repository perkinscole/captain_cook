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

There is also one story scene, to test telling the story through poses and
dialogue instead of animation. Captain Cook stands on the quarterdeck, to your
right. Look at him and press E to speak. Once the survey is complete he asks to
see the chart and puts one question to you; your answer changes how he regards
you and how the finished chart is drawn. The ship lies hove to while you talk.

Everything is placeholder shapes, and the dialogue is placeholder writing that
still needs checking against the historical record. There is no crew or scoring yet.

Control is by giving orders (you call a course and the helmsman steers). The
first prototype also tried holding the wheel directly; giving orders was chosen.

## Running it

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (standard build, not .NET).
2. In the Godot project manager choose **Import** and pick `project.godot`.
3. Press **F5**.

## Controls

| Key | Action |
| --- | --- |
| A / D | Order the course one compass point to port / starboard |
| W / S | Make / reduce sail |
| M | Enlarge or put away the chart |
| E | Speak with the person you are looking at |
| Space, then 1 to 3 | Continue a conversation, then pick an answer |
| Mouse | Look around (click to capture the mouse, Esc to free it) |

A square-rigger cannot sail closer than about 50 degrees to the wind. To get
upwind, zig-zag (tack) either side of it. The arrow on the chart shows which
way the wind is blowing.

## Layout

Systems are kept separate so each can be swapped:

| File | What it owns |
| --- | --- |
| `scripts/wind.gd` | Wind direction and strength over time |
| `scripts/weather.gd` | Fair weather, squalls and mist; drives the wind and visibility |
| `scripts/ship.gd` | Ship movement from wind, sail and rudder |
| `scripts/control_mode.gd`, `orders_mode.gd` | How the ship is steered (giving orders) |
| `scripts/island.gd` | Procedural island and its coastline |
| `scripts/charting.gd` | Which coast has been surveyed, and the ship's track |
| `scripts/chart_view.gd` | Drawing the chart |
| `scripts/ship_visual.gd`, `deck_camera.gd` | Placeholder ship and first-person view |
| `scripts/dialogue.gd`, `dialogue_box.gd` | Running a conversation, and showing it |
| `scripts/figure.gd` | Placeholder posed character |
| `scripts/story_state.gd` | What the story remembers (Cook's trust, flags) |
| `story/cook_scenes.gd` | Conversations with Cook, as data |
| `scripts/main.gd` | Builds the scene and wires the above together |
