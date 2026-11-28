# Bodgeworks: agent guide

A father–son hackathon game. Players build vehicles from parts on a grid, like Lego, then drive them to complete physics challenges. **Godot 4.7, GDScript, Jolt physics.** It's inspired by the vehicle-construction genre (see `docs/spec/`). Make it original: never copy another game's names, art or levels.

**How we work:** get a minimal playable version first, then iterate. One of the developers is a kid. Keep code readable, comment *why* things happen, and keep tuning numbers in data files where he can change them. Player-facing changes go in `docs/getting-started.md`. The spec is a starting point, not gospel.

## Quick facts

- Engine: **Godot 4.7.x standard** (not .NET). The renderer is Forward+, with physics interpolation on.
- Physics: **Jolt** (`physics/3d/physics_engine="Jolt Physics"`), 60 Hz.
- Main scene: `garage/garage.tscn`. Autoload: `Game` (`game.gd`).
- Dev machine: Linux laptop with an RTX 3050 (hybrid GPU). Vulkan works.
- Units: 1 grid cell = 1 m, mass in kg, forces in N. **Forward is −Z**, up is +Y, right is +X.
- Physics layers: `1 world` (ground, ramps, walls), `2 props` (crates, cargo), `3 vehicles` (bit value 4).

## Project map

```
project.godot            settings: Jolt, autoload Game, layer names, main scene = garage
game.gd                  autoload Game: current blueprint, mission list (MISSIONS), save file
                         (user://save.json, best times), tier_for(), format_time(), scene switching
data/parts.json          PART CATALOG: every part's numbers; behaviours are keys (see below)
data/blueprints/*.json   starter vehicles (Buggy, Amphibian); appear in garage Load and test-map Tab
vehicle/vehicle.gd       Vehicle (RigidBody3D): compiles a blueprint into ONE body, then applies
                         per-part forces each tick: wheels, propellers, buoyancy, drag. Core physics lives here.
vehicle/part_catalog.gd  PartCatalog: loads parts/blueprints JSON, saves to user://blueprints, lists files
vehicle/part_visuals.gd  PartVisuals: meshes per part (shared by garage and test map), icon()
garage/garage.gd         garage editor: ghost placement, remove, rotate, mirror mode (M), undo, save/load, stats panel,
                         missions list; UI is built in code (_build_ui)
garage/garage_camera.gd  orbit camera (right-drag, scroll, middle-drag, Q/E and arrows)
garage/garage.tscn       floor grid, light, FRONT arrow; parts go under the Build node
world/test_map.tscn      driving level: CSG ground (pond pit + boat ramps, hills, walls), jump ramp,
                         Pond (Water), crate stacks, Spawn, ChaseCamera, HUD
world/main.gd            test-map controller: spawns the vehicle(s), reads input, HUD, adds the mission
world/water.gd           Water: group "water", depth_at(point); node sits AT the surface
world/input_setup.gd     all input actions, defined in code (keyboard + gamepad)
world/crate*.{tscn,gd}   pushable crates (layer props) and the pyramid builder
camera/chase_camera.gd   follow camera (uses get_global_transform_interpolated)
missions/delivery_mission.gd  DeliveryMission: needs Start (Marker3D), Cargo (RigidBody3D), Goal (Area3D)
                              children; timer starts on first throttle; medals; T restarts
missions/special_delivery.tscn  the first mission (route around or across the pond)
missions/cargo.{gd,tscn} floating cargo crate (own simple buoyancy)
tests/                   headless/xvfb test scripts (see Testing)
tests/blueprints/        test-only vehicles (forklift.json = pusher with forks, six_propellers.json = power-budget test, air_sled/water_sled.json = airprop test, buggy_tank.json = buggy + fuel tank)
tests/screenshot_presets.json  named camera presets for tests/screenshot.gd (see Visual review)
docs/spec/               game-mechanics.md (design reference + figures), architecture.md (target architecture)
docs/concept-art/        mood boards and part ideas (art direction, colour coding); inspiration, not specs
docs/getting-started.md  player/dev guide: install, controls, garage, missions, editing parts/maps
docs/implementation-plan.md  roadmap; each item links to a GitHub issue
docs/.gdignore           keeps Godot from importing docs/
```

## How the game flows

`garage` → **G** / Test Drive calls `Game.test_drive(bp)`. A mission button calls `Game.start_mission(bp, id)`. Both load `world/test_map.tscn`.

- With `Game.mission_scene` set, `main.gd` instances the mission, moves Spawn to the mission's `Start`, and drives only the garage build.
- Without it, Tab cycles: the garage build, then the starter blueprints, then saved ones.
- **G** returns to the garage with the build kept in `Game.blueprint`.

## Data formats

**Blueprint:** `{"name": "...", "parts": [{"part": "block", "pos": [x, y, z], "rot": 0-3}]}`.
- `rot` is a yaw in 90° steps. Wheels ignore it.
- The garage builds only at y ≥ 0, within ±12 cells, with at most 60 parts, and every part must touch another.
- JSON numbers load as floats, so wrap them in `int()` for grid cells.

**Part** (`data/parts.json`): `name`, `mass`, `buoyancy` (kg it can hold up under water; more than its mass means it floats) and `color`. Behaviour keys:
- `seat: {reserve_fuel}` — a vehicle needs one to drive. `reserve_fuel` is the fuel a vehicle gets when it has **no** tank (largest seat's value; 30 = 30 s at full power for one engine).
- `engine: {force, power, fuel_use}` — engines are summed into one budget. Total push = `min(force, power / speed)`, so power (W) sets the top speed and force (N) the standstill push. `fuel_use` is fuel units per second at full power.
- `fuel: {capacity}` — a fuel tank. Tanks' capacities add up.
- `wheel: {radius, travel, grip}` — raycast suspension, no collider.
- `thrust: {force, steer, air, water, blade}` — a propeller: pushes along its facing, swivels `steer`° with steering, and keeps `air` (0–1) of its force out of water and `water` (0–1, default 1) under water. `blade` is the visual blade length. Parts: `propeller` (Water Propeller: air 0, water 1) and `air_propeller` (air 1, water 0.3).

A part with no special look renders as a cube, so new parts need no code unless they need a new behaviour.

## Physics model (vehicle/vehicle.gd)

- **Compile:** all parts become box colliders (except wheels) on one RigidBody3D. Mass, centre of mass (custom) and diagonal inertia are summed from the parts. The vehicle is shifted so its origin sits under the centre of mass horizontally.
  - No joints yet, so nothing can move relative to anything else.
- **Power budget:** each tick the total push is shared by the consumers: every grounded wheel (weight 1) and every propeller (weight `lerp(air, water, submerged)`). Push opposite to motion (reverse to brake) gets the full `force`. Test: `amphibian power` (6 propellers on one engine must be < 1.5× faster than 2).
- **Wheels:** a ray from the mount, masked to `LAYER_WORLD` only, so wheels never climb onto crates.
  - Self-tuning spring and damper.
  - Tyre force (drive + rolling resistance + side grip) is clamped to `load * grip`, and **applied at axle height** to avoid wheelies and flips.
  - Wheels in front of the centre of mass steer. Steering lock shrinks with speed.
- **Propellers:** their power share, capped at `thrust.force × lerp(air, water, submerged)`, at the propeller's position. Off-centre thrust therefore turns the vehicle. They swivel when steering (direction flips for propellers in front of the centre of mass).
- **Water:** per part, `submerged_at()` gives buoyancy at the part's position, plus directional drag: strong vertically, strong sideways (keel effect), weak forwards.
- Vehicle bodies have friction 0.2, so pushed objects slide off them. Air drag is quadratic.
- **Fuel:** drains by `fuel_use × engine_load × delta` (`_burn_fuel`). `engine_load` (0–1) = delivered push × max(speed, knee) / `engine_power`, where delivered push is what grounded wheels and propellers actually got from the budget and knee = `power / force`. So full throttle on the road burns `fuel_use`/s, but airborne wheels or a water propeller on land burn nothing. At 0 fuel there's no push. `Vehicle.fuel_for(defs)` sums the numbers and the garage uses it too. A new Vehicle starts full, so respawn, restart and garage all refill.
- **R** flips upright (in `_integrate_forces`). Falling below y = −30 respawns the vehicle.

## Testing

Godot isn't installed in a fresh cloud container. Download the binary, which is about 75 MB. If the proxy blocks `downloads.godotengine.org`, use the GitHub release instead:

```
mkdir -p $SCRATCH/godot && cd $SCRATCH/godot
curl -sSL -o g.zip "https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=linux.x86_64.zip&platform=linux.64" \
  || curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
unzip -q g.zip && ln -sf $PWD/Godot_v4.7.2-stable_linux.x86_64 godot
```

**Run everything:** `GODOT=$SCRATCH/godot/godot tests/run_all.sh` (from the repo root).
- It imports the project, runs every drive scenario, the mission autopilot and the garage test (under `xvfb-run`) in parallel, takes about 25 s, prints `PASS`/`FAIL` per test plus a summary, and **exits non-zero if anything failed**.
- A test also fails if it times out (`TEST_TIMEOUT`, default 180 s), prints a `SCRIPT ERROR`, or never prints a `RESULT ... PASS` line.
- Logs (one per test) and garage screenshots go to `$LOG_DIR`, else `$TEST_OUTPUT_DIR`, else a temp folder; the script prints where.
- Each script also exits 1 on its own failure, so single runs are trustworthy too. A drive scenario's checks live in `_check_expectations()` in `tests/drive_test.gd`; add one there when you add a scenario, and add the scenario to `DRIVE_SCENARIOS` in `run_all.sh`.

Individual tests (run `godot --headless --path . --import` once first; it generates `.godot/` and the `*.uid` / `*.import` files):

| Test | Command (from repo root) | Needs a display? |
|---|---|---|
| Driving scenarios | `godot --headless --path . --script res://tests/drive_test.gd -- <buggy\|amphibian\|forklift\|buggy_tank> <straight\|turn\|pond\|ramp\|push\|pyramid\|swim\|power\|airprop\|fuel>` | no |
| Garage clicks (22 checks, incl. mirror mode) | `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility --resolution 1280x720 --script res://tests/garage_test.gd [-- out_dir]` | yes (Xvfb) |
| Mission autopilot | `godot --headless --path . --script res://tests/mission_test.gd -- res://tests/blueprints/forklift.json [out_dir]` (expect gold, about 11.7 s; screenshots need Xvfb) | no |
| Screenshots | `xvfb-run ... --script res://tests/screenshot.gd -- <scene\|all> <out_dir> [preset...]` (see Visual review) | yes |

Gotchas:
- **Headless physics runs in real time.** A 10 s scenario takes about 10 s, so run scenarios in parallel or in the background.
- Exit codes are reliable: 0 = pass, 1 = a check failed. Every script prints a final `RESULT <test>: PASS|FAIL` line, and drive scenarios print each check as `  ok    ...` or `  FAIL  ...`.
- In `--script` mode, the `Game` autoload **doesn't exist at compile or `_initialize` time**. Never write `Game.` or reference types that use it (such as `DeliveryMission`) in test scripts. Use `root.get_node("Game")` on the first frame.
- GDScript can't infer types from Dictionary access. Write `var x: Vector3 = d.foo`, not `:=`.
- Container screenshots use the software Compatibility renderer, so they look washed out compared with real hardware. That's expected.
- `docs/.gdignore` keeps Godot from importing docs images. Commit the generated `*.uid` and `*.import` files.

## Visual review

`tests/screenshot.gd` renders PNG screenshots of any scene from named camera presets. Use it to check UI, levels and visuals, and to attach before/after images to PRs (issues labelled `vision-required`).

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility \
    --script res://tests/screenshot.gd -- <scene|all> <out_dir> [preset...]
```

- `all shots/` renders every preset into `shots/`. That folder is git-ignored, and the tool puts a `.gdignore` in any output folder inside the project, so Godot doesn't import the PNGs.
- `res://garage/garage.tscn shots/` renders only that scene's presets. If the scene has no presets, it takes one shot from the scene's own camera.
- `all shots/ pond mission_result` renders only the named presets.
- It exits non-zero and prints `FAIL` if a shot is blank (all one colour), isn't 1280×720, or names an unknown preset or action. The last line is `RESULT: PASS (n shots in <dir>)`.

Presets live in `tests/screenshot_presets.json`. Each one loads its scene fresh. The fields are:

| Field | Meaning |
|---|---|
| `name`, `scene` | Required. The output file is `<name>.png`. |
| `camera` | `{position, look_at, fov?}`. Leave it out to keep the scene's own camera, such as the chase camera following the vehicle. |
| `blueprint` | Vehicle to load (garage) or spawn first (test map). |
| `mission` | Mission scene to play in the test map. |
| `vehicle` | `{position, yaw}` (yaw in degrees): moves the spawned vehicle. |
| `hold` | Input actions held down while simulating, e.g. `["accelerate"]`. |
| `action` | Scripted action run before simulating. Right now: `deliver_cargo` (drops the mission cargo into the goal; `mission_time` sets the clock shown). |
| `seconds` | How long to simulate before the shot. |

The current presets are `garage_overview`, `garage_closeup`, `test_map_overview`, `pond`, `mission_start` and `mission_result`. The tool sets `Game.persist = false`, so staged results never overwrite the player's real best times.

**Colours look flatter than on real hardware.** Under xvfb, Godot runs the Compatibility (OpenGL) renderer on llvmpipe (software rendering): no Forward+ lighting, weaker shading, and distant ground washes out in the fog. Judge layout, framing, UI and presence of objects, not exact colour or lighting quality.

## Conventions

- Keep tuning numbers in JSON or `@export` vars, with comments a kid can follow. Build UI in code unless editor editing is the point.
- Prefer small, playable increments. Every feature needs a way to see or test it, and ideally a headless test scenario.
- Update `docs/getting-started.md` (player-facing) and this file (agent-facing) when structure changes.
- GitHub issue labels:
  - `vision-required`: verifying the work means looking at rendered output (UI layout, level design, visuals, camera feel). Use a vision-capable agent and the screenshot tooling.
  - `no-vision`: verifiable from numbers and logs alone.
  - Area labels: `physics`, `garage`, `missions`, `progression`, `world`, `infra`, `visual`.
