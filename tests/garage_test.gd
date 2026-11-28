extends SceneTree
## Clicks around the garage like a player would, then test drives the result.
## Needs a display (mouse picking): run with xvfb-run on a server. Exits 1 if any check fails.
## godot --path . --rendering-method gl_compatibility --script res://tests/garage_test.gd -- out_dir

var garage: Node
var frame := 0
var out_dir := ""
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	change_scene_to_file("res://garage/garage.tscn")


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		garage = current_scene
		check(garage.parts.size() == 12, "starts with the buggy (12 parts), got %d" % garage.parts.size())
		_shot("garage_01_start.png")
		# Point at the top of the seat at (0,1,1) and click: should stack a block on it at (0,2,1).
		_click_cell_top(Vector3(0, 1, 1), MOUSE_BUTTON_LEFT)
	if frame == 10:
		check(garage.parts.has(Vector3i(0, 2, 1)), "left click stacked a block on top of the seat")
		_select_key(KEY_6) # propeller
		_click_cell_top(Vector3(1, 1, 2), MOUSE_BUTTON_LEFT) # on top of the engine
	if frame == 15:
		check(garage.parts.get(Vector3i(1, 2, 2), {}).get("part") == "propeller", "picked propeller with key 6 and placed it")
		_click_cell_top(Vector3(1, 2, 2), MOUSE_BUTTON_RIGHT) # remove it again
	if frame == 20:
		check(not garage.parts.has(Vector3i(1, 2, 2)), "right click removed the propeller")
		_key(KEY_Z, true) # undo the removal
	if frame == 25:
		check(garage.parts.has(Vector3i(1, 2, 2)), "ctrl+z brought it back")
		check(garage.why_not(Vector3i(8, 0, 8)) != "", "floating parts far from the vehicle are not allowed")
		check(garage.why_not(Vector3i(0, 0, 1)) != "", "can't place inside an existing part")
		_shot("garage_02_built.png")
		# Thin parts: put a plate on the block we stacked on the seat.
		_select_part("plate")
		_click_cell_top(Vector3(0, 2, 1), MOUSE_BUTTON_LEFT)
	if frame == 30:
		check(garage.parts.get(Vector3i(0, 3, 1), {}).get("part") == "plate", "picked the plate and placed it")
		# The plate is thin: its top is 0.3 m below the middle of its cell. Clicking there stacks on it.
		_click_cell_top(Vector3(0, 3, 1), MOUSE_BUTTON_LEFT, -0.3)
	if frame == 35:
		check(garage.parts.get(Vector3i(0, 4, 1), {}).get("part") == "plate", "clicking the top of a thin plate stacks the next part in the cell above")
		_key(KEY_Z, true)
	if frame == 38:
		_key(KEY_Z, true) # undo both plates so the counts below stay the same
	if frame == 42:
		check(not garage.parts.has(Vector3i(0, 3, 1)), "ctrl+z removed the plates again")
		_key(KEY_G)
	if frame == 100:
		var main := current_scene
		check(main.name == "TestMap", "G switched to the test map")
		check(main.vehicle.parts.size() == 14, "test map drives the garage build (14 parts), got %d" % main.vehicle.parts.size())
		_shot("garage_03_test_drive.png")
		_key(KEY_G)
	if frame == 130:
		check(current_scene.name == "Garage" and current_scene.parts.size() == 14, "G went back to the garage with the build kept")
		# Mirror mode. The build spans x = -1 .. 2, so the mirror line is at x = 0.5
		# (stored doubled as mirror_x2 = 1) and cell x mirrors to 1 - x.
		garage = current_scene
		_key(KEY_M)
		_select_key(KEY_1) # block
	if frame == 135:
		check(garage.mirror_on and garage.mirror_x2 == 1, "M turned mirror on with the line at x = 0.5 (x2 = %d)" % garage.mirror_x2)
		check(garage.mirror_rot(1) == 3 and garage.mirror_rot(3) == 1 and garage.mirror_rot(0) == 0 and garage.mirror_rot(2) == 2, "mirrored rotation swaps left and right")
		check(garage.mirror_rot(4) == 4 and garage.mirror_rot(5) == 5, "rotations without a left or right (4, 5) stay the same")
		# Fill the gap between the left wheels so (-2,0,1) has something to touch.
		garage.build_at(Vector3i(-1, 0, 1))
		check(garage.parts.has(Vector3i(-1, 0, 1)) and garage.parts.has(Vector3i(2, 0, 1)), "mirror placed a twin at (2,0,1)")
		garage.build_at(Vector3i(-2, 0, 1))
	if frame == 140:
		check(garage.parts.has(Vector3i(-2, 0, 1)) and garage.parts.has(Vector3i(3, 0, 1)), "placing at (-2,0,1) also filled the mirrored cell (3,0,1)")
		check(garage.parts.size() == 18, "four parts added as two pairs (18), got %d" % garage.parts.size())
		_shot("garage_04_mirror.png")
		_key(KEY_Z, true)
	if frame == 145:
		check(not garage.parts.has(Vector3i(-2, 0, 1)) and not garage.parts.has(Vector3i(3, 0, 1)), "one ctrl+z removed both mirrored parts")
		check(garage.parts.has(Vector3i(-1, 0, 1)) and garage.parts.has(Vector3i(2, 0, 1)), "...and kept the earlier pair")
		check(garage.why_not_pair(Vector3i(-2, 0, 3)) != "", "a pair is refused when it doesn't touch the vehicle")
		garage.remove_at(Vector3i(2, 0, 1))
		check(not garage.parts.has(Vector3i(-1, 0, 1)) and not garage.parts.has(Vector3i(2, 0, 1)), "removing a part also removed its twin")
		_key(KEY_M)
	if frame == 150:
		check(not garage.mirror_on, "M turned mirror off again")
		garage.build_at(Vector3i(-1, 0, 1))
		check(garage.parts.has(Vector3i(-1, 0, 1)) and not garage.parts.has(Vector3i(2, 0, 1)), "with mirror off only one part is placed")
		print("RESULT garage: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
		quit(1 if failures > 0 else 0)
		return true
	if frame > 600:
		check(false, "finished within 600 frames (stuck at frame %d)" % frame)
		quit(1)
		return true
	return false


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


## Clicks the top of the part in this cell. top is how high its top is above the
## cell's middle: 0.5 for a whole-cell part, less for a thin one.
func _click_cell_top(cell: Vector3, button: MouseButton, top := 0.5) -> void:
	var cam: Camera3D = garage.camera
	var pos := cam.unproject_position(cell + Vector3(0, top, 0))
	root.warp_mouse(pos)
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = pos
		Input.parse_input_event(e)


func _select_key(code: Key) -> void:
	_key(code)


## Picks a part by id, like a player would: its number key if it has one (1-9),
## else a click on its button. So the test doesn't break when parts.json grows.
func _select_part(id: String) -> void:
	var i: int = garage.part_ids.find(id)
	if i >= 0 and i < 9:
		_key(KEY_1 + i)
	else:
		garage._part_buttons[id].emit_signal("pressed")


func _key(code: Key, ctrl := false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.ctrl_pressed = ctrl
		e.pressed = pressed
		Input.parse_input_event(e)


func _shot(name: String) -> void:
	if out_dir != "":
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name))
