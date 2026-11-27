# Bodgeworks

A father–son hackathon project: a physics sandbox where you bolt parts together into vehicles, then use them to beat challenges. Players build from modular parts on a grid, the design compiles into physics, and challenges score the result. Rewards unlock new parts, and new parts open new ways to solve every challenge.

**How we work:** get a minimal playable version first, then iterate. The docs below are a starting point, not gospel. Change them when the game teaches us something.

## Play it

New here? **[Getting started](docs/getting-started.md)** takes you from nothing installed to driving, step by step.

**What works so far:** a test map with a jump ramp, a pond, crates and hills. There are two vehicles built from blueprints (a Buggy and an Amphibian), with wheel suspension, floating and propellers. You can make your own vehicles and parts by editing JSON files.

**Next up:** a garage editor to build vehicles in the game, then a first challenge.

## Docs

| Doc | What it is |
|---|---|
| [Getting started](docs/getting-started.md) | Install Godot, open the project, controls, and how to make your own vehicles and parts. |
| [Game mechanics reference](docs/spec/game-mechanics.md) | Analysis of the vehicle-construction genre: building, physics, challenges, progression, and the design pillars we're borrowing from. |
| [Architecture](docs/spec/architecture.md) | Proposed Godot 4 + Rust (gdext) + Jolt architecture, data flows, and the first vertical-slice milestone. |

## Design pillars (short version)

1. **Modularity:** reusable parts with defined properties.
2. **Physical simulation:** design choices have physical consequences.
3. **Player expression:** players build their own tools.
4. **Objective-based play:** the game sets the goal, and the player works out how to reach it.
5. **Iterative engineering:** failure feeds redesign.
6. **Expanding possibility space:** new parts enable new solutions.
