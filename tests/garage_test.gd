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
		# Thin parts: put a plate (key 8) on the block we stacked on the seat.
		_select_key(KEY_8)
		_click_cell_top(Vector3(0, 2, 1), MOUSE_BUTTON_LEFT)
	if frame == 30:
		check(garage.parts.get(Vector3i(0, 3, 1), {}).get("part") == "plate", "picked plate with key 8 and placed it")
		# The plate is thin: its top is 0.3 m below the middle of its cell. Clicking there stacks on it.
		_click_cell_top(Vector3(0, 3, 1), MOUSE_BUTTON_LEFT, -0.3)
	if frame == 35:
		check(garage.parts.get(Vector3i(0, 4, 1), {}).get("part") == "plate", "clicking the top of a thin plate stacks the next part in the cell above")
		_key(KEY_Z, true)
	if frame == 38:
		_key(KEY_Z, true) # undo both plates so the counts below stay the same
	if frame == 42:
		check(not garage.parts.has(Vector3i(0, 3, 1)), "ctrl+z removed the plates again")
		_select_key(KEY_0) # the tenth part
	if frame == 44:
		check(garage.selected == "tray", "key 0 picks the tenth part (tray), got %s" % garage.selected)
	if frame == 46:
		_select_key(KEY_7) # spring
		_click_cell_top(Vector3(1, 2, 2), MOUSE_BUTTON_LEFT) # on top of the propeller
	if frame == 50:
		check(garage.parts.get(Vector3i(1, 3, 2), {}).get("part") == "spring", "picked spring with key 7 and placed it")
		_key(KEY_B) # wire mode
		_click_cell_top(Vector3(1, 3, 2), MOUSE_BUTTON_LEFT) # spring: unwired -> button 1
	if frame == 55:
		check(garage.wiring, "B turned on wire mode")
		var spring: Dictionary = garage.parts.get(Vector3i(1, 3, 2), {})
		check(spring.get("button") == 1, "clicking the spring in wire mode wired it to button 1")
		check(spring.node.get_node_or_null("Badge") != null, "the spring shows a button badge")
		_click_cell_top(Vector3(0, 2, 1), MOUSE_BUTTON_LEFT) # a block can't be wired
	if frame == 60:
		check(garage.parts[Vector3i(0, 2, 1)].button == 0, "blocks can't be wired to a button")
		check(garage.parts.size() == 15, "clicks in wire mode didn't add parts (15), got %d" % garage.parts.size())
		_shot("garage_03_wiring.png")
		# Save and load it back: the wiring must survive. Use a test-only name so
		# we never overwrite one of the player's own vehicles.
		var bp: Dictionary = garage.to_blueprint()
		bp.name = "zz garage test wiring"
		var path := PartCatalog.save_blueprint(bp)
		garage.clear()
		garage._load_blueprint(PartCatalog.load_blueprint(path))
		DirAccess.remove_absolute(path)
		check(garage.parts.get(Vector3i(1, 3, 2), {}).get("button") == 1, "the spring's button survived save and load")
		garage._name_edit.text = "My Vehicle"
		_key(KEY_B) # wire mode off again
	if frame == 65:
		check(not garage.wiring, "B turned wire mode off")
		_key(KEY_G)
	if frame == 125:
		var main := current_scene
		check(main.name == "TestMap", "G switched to the test map")
		check(main.vehicle.parts.size() == 15, "test map drives the garage build (15 parts), got %d" % main.vehicle.parts.size())
		check(main.vehicle.buttons.has(1), "the vehicle has a part on button 1")
		_shot("garage_04_test_drive.png")
		_key(KEY_G)
	if frame == 155:
		check(current_scene.name == "Garage" and current_scene.parts.size() == 15, "G went back to the garage with the build kept")
		check(current_scene.parts.get(Vector3i(1, 3, 2), {}).get("button") == 1, "...including the wiring")
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
