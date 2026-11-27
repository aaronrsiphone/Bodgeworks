extends SceneTree
## Renders the test map and saves screenshots (needs a display, so not --headless).
## Run: godot --path . --rendering-method gl_compatibility --script res://tests/screenshot.gd -- out_dir

var main: Node
var frame := 0
var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	main = load("res://world/test_map.tscn").instantiate()
	root.add_child(main)


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		10:
			# Overview from up high.
			main.camera.target = null
			main.camera.global_position = Vector3(-30, 45, 50)
			main.camera.look_at(Vector3(15, 0, -30))
		20:
			_shot("01_overview.png")
			main.camera.target = main.vehicle
			main.camera.snap()
			Input.action_press("accelerate")
		90:
			_shot("02_buggy.png")
		420:
			_shot("03_crates.png")
			Input.action_release("accelerate")
			main.spawn_vehicle(1)
			main.vehicle.global_transform = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(15, 1, -10))
			main.camera.snap()
			Input.action_press("accelerate")
		600:
			_shot("04_amphibian_swimming.png")
	return frame >= 605


func _shot(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name))
	print("saved ", name)
