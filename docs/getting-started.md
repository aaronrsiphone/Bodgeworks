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
| Pick a part | Click it in the bottom bar, or press 1–6 |
| Add a part | Left-click. The see-through ghost shows where it goes and snaps onto the face of the part you point at. Red means it can't go there. |
| Remove a part | Right-click it |
| Rotate the part | R (useful for propellers, which push away from their blades) |
| Turn the camera | Right-drag, or Q/E and the arrow keys |
| Zoom / slide | Scroll wheel / middle-drag |
| Undo | Ctrl+Z, or the Undo button |
| Drive it! | G, or the **Test Drive!** button. Press G again to come back. |

Rules: parts must touch the vehicle, a vehicle can have at most 60 parts, and the yellow arrow on the floor points to the front. The panel at the top left warns you if something's missing, like no seat or no engine.

**Save** keeps your vehicle (type a name first). **Load...** brings back a saved vehicle or a starter. Saved vehicles also show up when you press Tab in the test map.

## Driving controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Drive / reverse | W / S (or arrow keys) | Right trigger / left trigger |
| Steer | A / D | Left stick |
| Brake | Space | B |
| Flip upright | R | Y |
| Next vehicle | Tab | Back / View |
| Back to the garage | G | Start / Menu |

## Things to try

- Hit the **jump ramp** straight ahead, then smash the **crate pyramid** behind it.
- Drive the **Buggy** into the **pond** (to the right). It floats, but it's stuck, because wheels can't swim.
- Press **Tab** for the **Amphibian**. Its floats and propellers get it across the pond and up the ramp on the far side.

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

## Make a new part (still no code)

Open `data/parts.json` and copy an entry. The numbers you can change:

- `mass`: weight in kg.
- `buoyancy`: kg of weight the part can hold up under water. A part floats if this is more than its mass.
- `engine.force` and `engine.top_speed`: how much push the engine gives, and up to what speed.
- `wheel.radius`, `wheel.travel` (suspension) and `wheel.grip`.
- `thrust.force`: how hard a propeller pushes.

Try a monster-grip wheel, or a float that makes things fly out of the water.

## Change the map

Open `world/test_map.tscn`. The ground, ramps and pond are **CSG** boxes and spheres. Select one, then drag it, resize it, or duplicate it (Ctrl+D). Anything under the `Ground` node is merged into one solid floor, and setting a box's *Operation* to **Subtraction** digs a hole. To move the pond, move the `PondPit` box and the `Pond` water node together.

## Where things live

```
project.godot          Godot project settings (uses Jolt physics)
data/parts.json        the part catalog: every part's numbers
data/blueprints/       vehicles, as lists of parts on a grid
vehicle/vehicle.gd     turns a blueprint into a physics body and applies wheel, float and propeller forces
vehicle/part_catalog.gd  loads and saves the JSON files
vehicle/part_visuals.gd  what each part looks like (shared by the garage and the test map)
garage/                the garage editor (garage.gd) and its orbit camera
game.gd                global state: carries your build between the garage and the test map
world/test_map.tscn    the test level
world/main.gd          spawns the vehicle and reads your controls
world/input_setup.gd   the key and gamepad bindings
world/water.gd         the pond (anything inside it gets buoyancy)
camera/chase_camera.gd the follow camera
tests/                 automated checks that run without a screen
docs/spec/             the design spec and architecture (a starting point, not gospel)
```

## Automated test (optional)

This drives the car without opening a window and prints what happens:

```
godot --headless --path . --script res://tests/drive_test.gd -- buggy straight
godot --headless --path . --script res://tests/drive_test.gd -- amphibian ramp
```

The scenarios are `straight`, `turn`, `pond` and `ramp`.

The garage test clicks around like a player would, so it needs a window:

```
godot --path . --script res://tests/garage_test.gd
```
