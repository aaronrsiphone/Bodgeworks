# Bodgeworks: notes for agents

Godot 4.7 project (GDScript, Jolt physics). Start with `README.md` and `docs/getting-started.md`. Tests live in `tests/` and run as `--script` SceneTree scripts. See the "Automated test" section of getting-started for the commands.

## Visual review

`tests/screenshot.gd` renders PNG screenshots of any scene from named camera presets. Use it to check UI, levels and visuals, and to attach before/after images to PRs (issues labelled `vision-required`).

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility \
    --script res://tests/screenshot.gd -- <scene|all> <out_dir> [preset...]
```

- `all shots/` renders every preset into `shots/`.
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

Godot isn't preinstalled in cloud containers. Download the Linux build (e.g. `Godot_v4.7.1-stable_linux.x86_64.zip` from the godotengine/godot GitHub releases) and run `godot --headless --path . --import` once before the first run.
