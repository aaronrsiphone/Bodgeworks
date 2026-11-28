extends SceneTree
## Renders PNG screenshots of any scene, from camera presets in tests/screenshot_presets.json.
## Needs a display (not --headless). On a server, run it under xvfb-run:
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-method gl_compatibility --resolution 1280x720 \
##       --script res://tests/screenshot.gd -- <scene|all> <out_dir> [preset...]
##
##   all                         every preset in the file
##   res://garage/garage.tscn    only the presets for that scene (or one default shot if it has none)
##   preset...                   only these presets, by name
##
## Each preset loads its scene fresh, optionally spawns a blueprint / starts a mission,
## places the vehicle, holds input actions, runs a scripted action, simulates some
## seconds, points the camera and saves <out_dir>/<name>.png. See the JSON file for the fields.

const PRESETS_PATH := "res://tests/screenshot_presets.json"
const SIZE := Vector2i(1280, 720)

var failures := 0
var saved := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		_fail("usage: -- <scene|all> <out_dir> [preset...]")
		quit(2)
		return
	var scene: String = args[0]
	var out_dir := _absolute(args[1])
	var names := args.slice(2)
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Inside the project? Keep Godot from importing the PNGs on the next editor open.
	if out_dir.begins_with(ProjectSettings.globalize_path("res://")) and not FileAccess.file_exists(out_dir.path_join(".gdignore")):
		FileAccess.open(out_dir.path_join(".gdignore"), FileAccess.WRITE)

	var presets := _pick(PartCatalog.load_json(PRESETS_PATH).get("presets", []), scene, names)
	if presets.is_empty():
		quit(1)
		return

	await process_frame # the Game autoload is ready from here on
	var game: Node = root.get_node("Game")
	game.persist = false # never overwrite the player's real best times

	for preset in presets:
		await _shoot(game, preset, out_dir)
	print("RESULT: %s (%d shots in %s)" % ["PASS" if failures == 0 else "%d FAILED" % failures, saved, out_dir])
	quit(0 if failures == 0 else 1)


## The presets to run: by name if any are given, else by scene.
func _pick(all: Array, scene: String, names: Array) -> Array:
	var out := []
	if not names.is_empty():
		for n in names:
			var found := all.filter(func(p): return p.name == n)
			if found.is_empty():
				_fail("no preset called '%s'" % n)
			out.append_array(found)
		return out
	if scene == "all":
		return all
	out = all.filter(func(p): return p.scene == scene)
	if out.is_empty():
		if not ResourceLoader.exists(scene):
			_fail("'%s' is not 'all' or a scene" % scene)
			return []
		print("no presets for %s, taking one shot from its own camera" % scene)
		out.append({"name": scene.get_file().get_basename(), "scene": scene, "seconds": 1.0})
	return out


func _shoot(game: Node, p: Dictionary, out_dir: String) -> void:
	# Fresh state for every shot.
	for action in InputMap.get_actions():
		Input.action_release(action)
	game.save = {"missions": {}}
	game.blueprint = PartCatalog.load_blueprint(p.blueprint) if p.has("blueprint") else {}
	game.mission_scene = p.get("mission", "")

	change_scene_to_file(p.scene)
	while current_scene == null or current_scene.scene_file_path != p.scene:
		await process_frame
	var scene := current_scene
	await physics_frame

	if p.has("vehicle") and scene.get("vehicle") != null:
		var v: Node3D = scene.vehicle
		var pose: Dictionary = p.vehicle
		v.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(pose.get("yaw", 0.0))), _vec(pose.position))
		if scene.get("camera") is ChaseCamera:
			scene.camera.snap()
	for action in p.get("hold", []):
		Input.action_press(action)
	if p.has("action"):
		_action(scene, p.action, p)

	var camera := root.get_viewport().get_camera_3d()
	for i in roundi(p.get("seconds", 0.0) * Engine.physics_ticks_per_second):
		await physics_frame
		_place_camera(camera, p)
	_place_camera(camera, p)
	# Let the renderer catch up with the last physics step.
	for i in 3:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join(p.name + ".png")
	img.save_png(path)
	var problem := _check(img)
	if problem != "":
		_fail("%s: %s" % [p.name, problem])
	else:
		saved += 1
		print("saved ", path)


func _place_camera(camera: Camera3D, p: Dictionary) -> void:
	if camera == null or not p.has("camera"):
		return # keep the scene's own camera (e.g. the chase camera following the vehicle)
	if camera is ChaseCamera:
		camera.target = null
	camera.global_position = _vec(p.camera.position)
	camera.look_at(_vec(p.camera.look_at))
	if p.camera.has("fov"):
		camera.fov = p.camera.fov


## Scripted actions a preset can ask for, by name.
func _action(scene: Node, action: String, p: Dictionary) -> void:
	match action:
		"deliver_cargo":
			# Drop the mission's cargo into the goal so the result screen shows.
			var m = scene.get("mission")
			if m == null:
				_fail("%s: deliver_cargo needs a mission" % p.name)
				return
			m.time = p.get("mission_time", m.time)
			m.cargo.global_position = m.goal.global_position + Vector3.UP
			m.cargo.linear_velocity = Vector3.ZERO
		_:
			_fail("%s: unknown action '%s'" % [p.name, action])


## Catches the obvious failures: wrong size, or one flat colour (a blank frame).
func _check(img: Image) -> String:
	if img.get_size() != SIZE:
		return "image is %s, expected %s" % [img.get_size(), SIZE]
	var first := img.get_pixel(0, 0)
	for y in range(0, img.get_height(), 40):
		for x in range(0, img.get_width(), 40):
			if not img.get_pixel(x, y).is_equal_approx(first):
				return ""
	return "frame is blank (all one colour)"


func _vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _absolute(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return OS.get_environment("PWD").path_join(path)


func _fail(what: String) -> void:
	printerr("  FAIL  " + what)
	failures += 1
