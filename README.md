# Captain Cook Voyages

A first-person game about Captain James Cook's voyages, seen by a young officer
who serves under him. The full brief is in [docs/PROJECT_PLAN.md](docs/PROJECT_PLAN.md).

## Current state: prototype 1, "chart one island"

One ship, one patch of ocean, one island, a wind that wanders, and a chart that
starts blank and fills in as you sail within sight of the coast. It is done
when you have sailed round the island and the chart is complete.

Everything is placeholder shapes. There is no crew, story, weather or scoring yet.

## Running it

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (standard build, not .NET).
2. In the Godot project manager choose **Import** and pick `project.godot`.
3. Press **F5**.

## Controls

| Key | Action |
| --- | --- |
| Tab | Switch between the two control modes |
| A / D | **Giving orders:** order the course one compass point to port / starboard. **At the wheel:** hold to turn the wheel. |
| W / S | Make / reduce sail |
| M | Enlarge or put away the chart |
| Mouse | Look around (click to capture the mouse, Esc to free it) |

A square-rigger cannot sail closer than about 50 degrees to the wind. To get
upwind, zig-zag (tack) either side of it. The arrow on the chart shows which
way the wind is blowing.

## Layout

Systems are kept separate so each can be swapped:

| File | What it owns |
| --- | --- |
| `scripts/wind.gd` | Wind direction and strength over time |
| `scripts/ship.gd` | Ship movement from wind, sail and rudder |
| `scripts/control_mode.gd`, `orders_mode.gd`, `helm_mode.gd` | The two input modes being compared |
| `scripts/island.gd` | Procedural island and its coastline |
| `scripts/charting.gd` | Which coast has been surveyed, and the ship's track |
| `scripts/chart_view.gd` | Drawing the chart |
| `scripts/ship_visual.gd`, `deck_camera.gd` | Placeholder ship and first-person view |
| `scripts/main.gd` | Builds the scene and wires the above together |
