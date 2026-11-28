# Getting started

From nothing to driving in about 15 minutes.

## 1. Install the tools (free)

| Tool | Where | Notes |
|---|---|---|
| **Godot 4.7** (or any newer 4.x) | [godotengine.org/download](https://godotengine.org/download) | Pick the standard **Godot Engine** download, not ".NET". There's no installer: unzip it and run it. On a Mac, drag it into Applications. |
| **GitHub Desktop** | [desktop.github.com](https://desktop.github.com) | Sign in with your GitHub account. |
| A gamepad (optional) | Any Xbox-style controller | Plug it in. A keyboard works fine too. |

## 2. Get the project

1. In GitHub Desktop: **File → Clone repository** and pick `aaronrsiphone/bodgeworks`.
2. Switch to the branch you're working on with the **Current branch** dropdown.
3. Whenever you want the latest changes, click **Fetch origin** and then **Pull**.

## 3. Open it in Godot

1. Start Godot. In the Project Manager click **Import**, browse to the cloned folder, and pick `project.godot`.
2. The first time, Godot spends a few seconds importing files. That's normal.
3. Press **F5** (or the ▶ Play button, top right). You start in the garage. Press **G** to drive.

## The garage

The game starts in the **garage**, with the Buggy ready to change.

| Do this | How |
|---|---|
| Pick a part | Click it in the bottom bar, or press 1–9 |
| Add a part | Left-click. The see-through ghost shows where it goes and snaps onto the face of the part you point at. Red means it can't go there. |
| Remove a part | Right-click it |
| Rotate the part | R (useful for propellers, which push away from their blades) |
| Turn the camera | Right-drag, or Q/E and the arrow keys |
| Zoom / slide | Scroll wheel / middle-drag |
| Undo | Ctrl+Z, or the Undo button |
| Drive it! | G, or the **Test Drive!** button. Press G again to come back. |

Rules: parts must touch the vehicle, a vehicle can have at most 60 parts, and the yellow arrow on the floor points to the front. The panel at the top left warns you if something's missing, like no seat or no engine.

**Save** keeps your vehicle (type a name first). **Load...** brings back a saved vehicle or a starter. Saved vehicles also show up when you press Tab in the test map.

## Missions

The **Missions** list in the garage starts a challenge with the vehicle you've built. Your best time and medal show on the button.

**Special Delivery:** get the orange crate into the green zone on the far side of the pond.
- The clock starts when you first press the throttle.
- Medals: **gold** under 0:15, **silver** under 0:25, **bronze** under 1:00.
- **T** restarts the mission, and **G** takes you back to the garage to improve your design.

Tips (spoilers!):
- A flat front pushes the crate fine in a straight line, but it slides off as soon as you turn. Build "forks" (blocks sticking forward on both sides) so the crate sits between them.
- The crate floats. Going straight across the pond is shorter, but your vehicle has to swim and climb out too.
- Carrying the crate on top is another way to do it.

To make your own delivery mission, duplicate `missions/special_delivery.tscn`, then move its **Start**, **Cargo** and **Goal** nodes in the editor and set the medal times in the Inspector. Add it to the `MISSIONS` list in `game.gd`.

## Driving controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Drive / reverse | W / S (or arrow keys) | Right trigger / left trigger |
| Steer | A / D | Left stick |
| Brake | Space | B |
| Flip upright | R | Y |
| Next vehicle | Tab | Back / View |
| Back to the garage | G | Start / Menu |
| Restart mission | T | X |

## Things to try

- Hit the **jump ramp** straight ahead, then smash the **crate pyramid** behind it.
- Drive the **Buggy** into the **pond** (to the right). It floats, but it's stuck, because wheels can't swim.
- Press **Tab** for the **Amphibian**. Its floats and propellers get it across the pond and up the ramp on the far side.
- Press **Tab** again for the **Plane**. Point it down a long, clear stretch (the east side of the map is best) and hold **W**. It takes off by itself at about 55 km/h and keeps climbing. Steer gently!
- Put **Flat Wings** on the sides of the Buggy, and a couple at the back as a tail, then hit the jump ramp. You glide much further.

## Make a vehicle by hand (the JSON way)

The garage is the easy way, but vehicles are just **blueprints**: JSON files in `data/blueprints/`. Each part has a grid position `[x, y, z]`:

- **x** is left (−) / right (+).
- **y** is down (−) / up (+).
- **z** is forward (−) / back (+). Forward is *minus* z.
- Each grid cell is 1 metre.

To make one:

1. Copy `buggy.json` to `my_car.json` and change the `"name"`.
2. Add, move or remove parts. The part types are listed in `data/parts.json`.
3. Everything in `data/blueprints/` appears in the garage's **Load...** menu and in the test map's Tab list.

Rules the physics enforces:

- You need a **seat** and an **engine**, or nothing pushes the vehicle.
- Wheels in front of the middle of the vehicle steer.
- Heavy parts high up make the vehicle tippy.
- Propellers push from where they are, so one off to the side will turn you.
- Propellers swivel when you steer, like an outboard motor. That's how you steer in water.
- Wheels only grip the ground. They can't climb on crates, so push things with your body or forks.
- A normal **Propeller** is a boat propeller: in the air it only gives a fifth of its push. An **Air Propeller** (orange) pushes just as hard in the air as in water, so it's the one for planes.
- Wings lift when air flows over them, and the faster you go, the more they lift. They push from where they are, just like propellers.
- **Wing** (cream) is curved: it lifts even when it's level, so it's the one that gets a plane off the ground. But on a car it makes the tyres light and slippy.
- **Flat Wing** (pale blue) only lifts when it's tilted into the wind. Use it as a **tail**: a few flat wings well behind the middle keep the nose pointing where you're going, like the feathers on a dart. Without a tail, a plane or a glider tips its nose up and flops.
- Tilt the wing too steeply (more than about 15°) and it **stalls**: most of the lift suddenly goes away.
- Wings do nothing under water.

## Make a new part (still no code)

Open `data/parts.json` and copy an entry. The numbers you can change:

- `mass`: weight in kg.
- `buoyancy`: kg of weight the part can hold up under water. A part floats if this is more than its mass.
- `engine.force` and `engine.top_speed`: how much push the engine gives, and up to what speed.
- `wheel.radius`, `wheel.travel` (suspension) and `wheel.grip`.
- `thrust.force`, `thrust.steer` and `thrust.air`: how hard a propeller pushes, how many degrees it swivels when you steer, and how much of its push it keeps out of the water (0.2 = a fifth for a boat **Propeller**; 1.0 for an **Air Propeller**).
- `wing.area`, `wing.lift`, `wing.stall` and `wing.camber`: how big the wing is in square metres, how strongly it lifts, the angle in degrees where it stalls, and how much it lifts when perfectly level.

Try a monster-grip wheel, or a float that makes things fly out of the water.

## Change the map

Open `world/test_map.tscn`. The ground, ramps and pond are **CSG** boxes and spheres. Select one, then drag it, resize it, or duplicate it (Ctrl+D). Anything under the `Ground` node is merged into one solid floor, and setting a box's *Operation* to **Subtraction** digs a hole. To move the pond, move the `PondPit` box and the `Pond` water node together.

## Where things live

```
project.godot          Godot project settings (uses Jolt physics)
data/parts.json        the part catalog: every part's numbers
data/blueprints/       vehicles, as lists of parts on a grid
vehicle/vehicle.gd     turns a blueprint into a physics body and applies wheel, float, propeller and wing forces
vehicle/part_catalog.gd  loads and saves the JSON files
vehicle/part_visuals.gd  what each part looks like (shared by the garage and the test map)
garage/                the garage editor (garage.gd) and its orbit camera
game.gd                global state: your build, the mission list, and the save file (best times)
missions/              delivery missions, the crate and its floating
world/test_map.tscn    the test level
world/main.gd          spawns the vehicle and reads your controls
world/input_setup.gd   the key and gamepad bindings
world/water.gd         the pond (anything inside it gets buoyancy)
camera/chase_camera.gd the follow camera
tests/                 automated checks that run without a screen
docs/spec/             the design spec and architecture (a starting point, not gospel)
```

## Automated tests (optional)

Run them all with one command. It prints PASS or FAIL for each test, and exits with an error if anything failed:

```
GODOT=/path/to/godot tests/run_all.sh
```

It takes about 30 seconds, because the driving tests run at the same time. The garage test needs a window, so on a computer without a screen it runs under `xvfb-run` (and is skipped if that isn't installed). Each test's full log is saved; the script prints where.

You can also run one test on its own. This drives the car without opening a window, prints what happens, then checks it (for example, `straight` must cover at least 60 m without tipping over):

```
godot --headless --path . --script res://tests/drive_test.gd -- buggy straight
godot --headless --path . --script res://tests/drive_test.gd -- amphibian ramp
```

The scenarios are `straight`, `turn`, `pond`, `ramp`, `push` (weave while pushing a crate), `pyramid` (plough through the crates) `swim` (steer in the pond), `jump` (off the jump ramp; with a winged vehicle, the plain buggy jumps first to compare) and `fly` (full throttle down the long east side). Use `forklift`, `winged_buggy` or `plane` instead of `buggy` to try another vehicle, or give a blueprint's path, like `res://data/blueprints/plane.json`. The checks are at the bottom of `tests/drive_test.gd`, in `_check_expectations()`.

An autopilot can play the delivery mission and report the time. It fails if it doesn't finish, or is slower than silver:

```
godot --headless --path . --script res://tests/mission_test.gd -- res://tests/blueprints/forklift.json
```

The garage test clicks around like a player would, so it needs a window:

```
godot --path . --script res://tests/garage_test.gd
```

To take screenshots of the garage, the test map, the pond and the mission (they go in the `shots` folder):

```
godot --path . --script res://tests/screenshot.gd -- all shots
```

The camera spots are in `tests/screenshot_presets.json`. Add your own there.

### On GitHub

Every pull request, and every push to `main`, runs `tests/run_all.sh` on GitHub with Godot 4.7.2 (see `.github/workflows/tests.yml`). A green tick on the PR means everything passed. If it goes red, open the **Tests** check to read the log. Logs and screenshots from the failed run are attached at the bottom of the run's summary page under **Artifacts**.
