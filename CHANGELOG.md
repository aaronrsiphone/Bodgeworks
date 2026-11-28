# Changelog

All the notable changes to Bodgeworks, newest first. We don't have version numbers yet, so each heading is a date and a short name. Each one says what you can now do in the game. The "Under the hood" bits are for people working on the code.

## 2026-11-28 — Design kit

### Added
- **The design kit showcase** (`showcase/showcase.tscn`, press F6). It shows the look from the concept art: chunky parts with rounded edges, grey bolted hardpoints where things join, and colours that say what a part does. It has 16 parts and five starter platforms: a rover, a submarine, a plane, a helicopter and a boat. They're for looking at only; you can't drive them yet.

### Under the hood
- `kit/kit_mesh.gd` builds rounded boxes, lathed shapes and lofted wings in code. `kit/kit.gd` holds the parts and colours, and `kit/platforms.gd` puts the vehicles together. There are new `showcase_*` screenshot presets.

## 2026-11-28 — Planes, springs and fuel (#43)

This one combined seven smaller pieces of work into one go (they replaced PRs #36 to #40 and #42, because they all changed the same files).

### Added
- **Thin parts: Plate, Wall and Tray.** Flat bits for floors, back walls and cargo beds. A Tray has rims on the back and right, so put four together (turned rims-out) to make a 2×2 bed that holds cargo in. A cargo crate on a flat Plate slides off at the first turn, so use a Tray when you carry things. (Closes #10)
- **Fuel Tank.** Engines now burn fuel. (Closes #7)
- **Wing and Flat Wing.** Real lift and drag from the air moving past them. Use the Wing (curved) on planes, and the Flat Wing for tails, or on cars that still need their tyres to grip. (Closes #8)
- **Plane starter vehicle** in the Load menu (and in Tab on the test map). Full throttle down the long east side and it takes off.
- **Air Propeller.** Pushes at full strength in the air, and weakly (30%) in water. This is the one for planes.
- **Accessory buttons 1, 2 and 3** (keys 1/2/3, or A/X/B on a gamepad). Press **B** in the garage for wire mode, click a part to give it a button, and a coloured number appears above it. Several parts can share a button. (Closes #9)
- **Spring.** A button part that kicks its foot out. Use it to hop over things, or to boot a crate away.
- **Hopper starter vehicle** to show off the Spring (press 1 to jump).
- A fuel readout in the garage panel, and a fuel gauge on the driving screen if you have tanks.

### Changed
- **One engine, shared power.** Engines now add up into one pool, shared out between every wheel on the ground and every propeller. Power sets your top speed and force sets your push from a standstill. Bolting on six propellers will not make you six times faster. (Closes #6)
- **Propellers split in two.** The old propeller is now the **Water Propeller**: full push under water, nothing on land. The **Air Propeller** is the one for flying.
- **Fuel:** every vehicle gets a 2 minute reserve for free (at full throttle with one engine). Each Fuel Tank adds 1 more minute but weighs 40 kg. Extra engines burn fuel faster. You only burn fuel for power you actually use, so spinning wheels in the air, or a Water Propeller on dry land, burn none. When you run dry you stop pushing. Respawning (Tab), restarting a mission (T) or going to the garage (G) refills you.
- The garage part bar now wraps onto a second row so all 15 parts fit.

### Fixed
- The screenshot tool now keeps its window at 1280×720.

### Under the hood
- New drive test scenarios: `power`, `airprop`, `fuel`, `jump`, `fly`, `hop` and `kick`. New test vehicles: `carrier`, `six_propellers`, `air_sled`, `water_sled`, `buggy_tank` and `winged_buggy`.
- The garage test picks parts by id, and checks mirror mode after the test drive.
- Parts can now have a `shape` (one or more boxes), so thin parts get a real collider and the right centre of mass.

## 2026-11-28 — Mirror mode (#35)

### Added
- **Mirror mode (M).** A blue line appears down the middle of your vehicle, and every part you add or remove gets a twin on the other side. Ctrl+Z undoes both at once. Great for wheels, wings and anything else that should be even.

### Changed
- Mirror mode leaves "pointing up" and "pointing down" parts alone, because those have no left or right.

## 2026-11-28 — Teamwork, tests and tools (#31, #32, #33, #34, #41, #44)

Nothing new to play here, but it makes the game easier and safer to build.

### Added
- **Concept art folder** (`docs/concept-art/`) with mood boards and ideas for parts, flight, a helicopter, a submarine, the garage and the pond. These are inspiration, not plans. (#41)
- **Screenshot tool** that takes pictures of any scene from named camera spots, so we can check how things look without opening the game. (#34, closes #4)
- **Implementation plan** (`docs/implementation-plan.md`), a roadmap with each idea linked to a GitHub issue. (#33)

### Under the hood
- `CLAUDE.md` is now the guide for AI helpers: how the project is laid out, how the physics works, how to test. (#33)
- Tests now fail loudly: real checks, proper pass or fail exit codes, and a `tests/run_all.sh` script that runs everything at once. (#31)
- GitHub Actions runs the whole test suite on every pull request and every push to `main`. (#32)
- Teamwork rules added to `CLAUDE.md`: claim an issue before starting, use one work branch per work session, and open one PR at the end. (#44)

## 2026-11-27 — The first playable game (#1)

Where it all started.

### Added
- **Design docs** (`docs/spec/`): how the game should work, and the plan for how the code fits together.
- **Drive your own vehicle.** A test map with hills, walls, a jump ramp, a pond with boat ramps, and stacks of crates to smash into.
- **The garage.** Build a vehicle from parts on a grid, like Lego. Place and remove parts, rotate them, undo, save and load, and see stats about your build. Orbit the camera with right-drag and scroll.
- **Starter vehicles:** Buggy and Amphibian.
- **Parts:** Wooden Block, Seat, Engine, Wheel, Float and Propeller. Float parts keep you on top of the water.
- **Special Delivery**, the first mission: carry a floating cargo crate to the goal, around the pond or straight across it. There is a timer and bronze, silver and gold medals. Your best times are saved. Press **T** to restart.
- A chase camera that follows your vehicle.
- Steering in water, and steadier pushing of crates.
- Propellers pushed weakly in the air (later reworked, see #43).
- Screenshots in the README.

### Under the hood
- Automated driving tests, and a test-only **Forklift** (a Buggy with "forks" that hold a crate while you push) that the mission autopilot drives to gold.
