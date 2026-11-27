extends SceneTree
## Headless smoke test: loads the test map, holds the throttle, and prints what happens.
## Run:  godot --headless --path . --script res://tests/drive_test.gd
##   or: godot --headless --path . --script res://tests/drive_test.gd -- amphibian pond

var main: Node
var frame := 0
var scenario := "straight"
var crate: RigidBody3D
var min_upright := 1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	main = load("res://world/test_map.tscn").instantiate()
	if args.size() > 0 and args[0] == "amphibian":
		main.blueprints.assign(["res://data/blueprints/amphibian.json"])
	if args.size() > 0 and args[0] == "forklift":
		main.blueprints.assign(["res://tests/blueprints/forklift.json"])
	if args.size() > 1:
		scenario = args[1]
	root.add_child(main)
	print("physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine"))


func _physics_process(_delta: float) -> bool:
	frame += 1
	var v: Vehicle = main.vehicle
	if frame == 2:
		print("vehicle: %s  mass %.0f kg  COM %s  inertia %s" % [v.blueprint_name, v.mass, v.center_of_mass, v.inertia])
		if scenario == "pond":
			# Drop it straight into the deep end of the pond.
			v.global_position = Vector3(45, 0, -10)
		if scenario == "push":
			# Open ground, heading west (-x), with a heavy crate right in front.
			v.global_transform = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(90, 1, 90))
			crate = load("res://world/crate.tscn").instantiate()
			crate.mass = 40.0
			crate.position = Vector3(84, 0.5, 90)
			main.add_child(crate)
		if scenario == "swim":
			# Middle of the pond, facing north along its length.
			v.global_transform = Transform3D(Basis.IDENTITY, Vector3(40, 0, 5))
		if scenario == "pyramid":
			v.global_position = Vector3(0, 1, -60)
		if scenario == "ramp":
			# Line up on the boat ramp facing into the pond (+x).
			v.global_transform = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(15, 1, -10))
	match scenario:
		"straight":
			if frame > 60: Input.action_press("accelerate")
		"turn":
			if frame > 60: Input.action_press("accelerate")
			if frame > 180: Input.action_press("steer_left")
		"pond":
			if frame > 180: Input.action_press("accelerate")
		"ramp":
			if frame > 30: Input.action_press("accelerate")
		"push":
			if frame > 30: Input.action_press("accelerate")
			# weave left and right while pushing
			var phase := (frame / 90) % 4
			if frame > 150 and phase == 1: Input.action_press("steer_left")
			else: Input.action_release("steer_left")
			if frame > 150 and phase == 3: Input.action_press("steer_right")
			else: Input.action_release("steer_right")
		"pyramid":
			if frame > 30: Input.action_press("accelerate")
		"swim":
			if frame > 30: Input.action_press("accelerate")
			if frame > 120: Input.action_press("steer_left")
	min_upright = minf(min_upright, v.global_basis.y.y)
	if frame % 30 == 0:
		var up := v.global_basis.y
		var grounded := v.wheels.filter(func(w): return w.grounded).size()
		var fwd := -v.global_basis.z
		var heading := rad_to_deg(atan2(-fwd.x, -fwd.z)) # 0 = north, +90 = west (turned left)
		print("t=%4.1fs pos=(%6.1f %5.2f %6.1f) speed=%5.1f km/h upright=%.2f wheels_down=%d heading=%4.0f" % [
			frame / 60.0, v.global_position.x, v.global_position.y, v.global_position.z,
			v.speed_kmh(), up.y, grounded, heading])
		if crate:
			print("        crate=(%6.1f %5.2f %6.1f) %.1f m ahead" % [crate.position.x, crate.position.y, crate.position.z, (crate.position - v.global_position).dot(-v.global_basis.z)])
	if frame == 600:
		print("min upright: %.2f  %s" % [min_upright, "FLIPPED" if min_upright < 0.3 else "stayed upright"])
	return frame >= 600
