extends SceneTree
## Headless smoke test: loads the test map, holds the throttle, prints what happens,
## then checks the scenario's expectations. Exits 1 if any of them fail.
## Run:  godot --headless --path . --script res://tests/drive_test.gd
##   or: godot --headless --path . --script res://tests/drive_test.gd -- amphibian pond

const SCENARIOS := ["straight", "turn", "pond", "ramp", "push", "pyramid", "swim"]
const VEHICLES := ["buggy", "amphibian", "forklift"]
const FRAMES := 600

var main: Node
var frame := 0
var scenario := "straight"
var crate: RigidBody3D
var min_upright := 1.0
var vehicle_arg := "buggy"
var start_pos := Vector3.ZERO
var last_heading := 0.0
var turned := 0.0 # signed degrees turned since the start, + = left
var crate_worst_ahead := -INF # from 2 s on, how far ahead the crate got at most (m)
var crate_closest_ahead := INF # ...and how close (negative = behind the vehicle)
var crate_worst_side := 0.0 # ...and how far off to the side
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		vehicle_arg = args[0]
	if args.size() > 1:
		scenario = args[1]
	if vehicle_arg not in VEHICLES or scenario not in SCENARIOS:
		printerr("FAIL unknown vehicle or scenario: %s %s (vehicles: %s, scenarios: %s)" % [vehicle_arg, scenario, VEHICLES, SCENARIOS])
		quit(1)
		return
	main = load("res://world/test_map.tscn").instantiate()
	if vehicle_arg == "amphibian":
		main.blueprints.assign(["res://data/blueprints/amphibian.json"])
	if vehicle_arg == "forklift":
		main.blueprints.assign(["res://tests/blueprints/forklift.json"])
	root.add_child(main)
	print("physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine"))


func _physics_process(_delta: float) -> bool:
	if main == null:
		return true
	frame += 1
	var v: Vehicle = main.vehicle
	if v == null:
		check(false, "the test map spawned a vehicle")
		return _finish()
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
		start_pos = v.global_position
		last_heading = _heading(v)
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
	if frame > 2:
		var h := _heading(v)
		turned += wrapf(h - last_heading, -180.0, 180.0)
		last_heading = h
	if crate and frame >= 120:
		var to_crate := crate.global_position - v.global_position
		var ahead := to_crate.dot(-v.global_basis.z)
		crate_worst_ahead = maxf(crate_worst_ahead, ahead)
		crate_closest_ahead = minf(crate_closest_ahead, ahead)
		crate_worst_side = maxf(crate_worst_side, absf(to_crate.dot(v.global_basis.x)))
	if frame % 30 == 0:
		var up := v.global_basis.y
		var grounded := v.wheels.filter(func(w): return w.grounded).size()
		var heading := _heading(v)
		print("t=%4.1fs pos=(%6.1f %5.2f %6.1f) speed=%5.1f km/h upright=%.2f wheels_down=%d heading=%4.0f" % [
			frame / 60.0, v.global_position.x, v.global_position.y, v.global_position.z,
			v.speed_kmh(), up.y, grounded, heading])
		if crate:
			print("        crate=(%6.1f %5.2f %6.1f) %.1f m ahead" % [crate.position.x, crate.position.y, crate.position.z, (crate.position - v.global_position).dot(-v.global_basis.z)])
	if frame == FRAMES:
		print("min upright: %.2f  %s" % [min_upright, "FLIPPED" if min_upright < 0.3 else "stayed upright"])
		_check_expectations(v)
		return _finish()
	return false


## 0 = north, +90 = west (turned left).
func _heading(v: Vehicle) -> float:
	var fwd := -v.global_basis.z
	return rad_to_deg(atan2(-fwd.x, -fwd.z))


func _check_expectations(v: Vehicle) -> void:
	var moved := Vector2(v.global_position.x - start_pos.x, v.global_position.z - start_pos.z).length()
	print("travelled %.1f m, turned %.0f deg" % [moved, turned])
	# Every scenario: nothing should tip over.
	check(min_upright > 0.8, "stayed upright (min upright %.2f > 0.8)" % min_upright)
	match scenario:
		"straight":
			check(moved >= 60.0, "travelled at least 60 m (%.1f m)" % moved)
		"turn":
			check(turned > 90.0, "turned left more than 90 deg (%.0f deg)" % turned)
		"ramp":
			check(moved >= 60.0, "drove up the boat ramp and on at least 60 m (%.1f m)" % moved)
		"swim":
			check(absf(turned) > 60.0, "heading changed by more than 60 deg in the water (%.0f deg)" % turned)
		"pond":
			if vehicle_arg == "amphibian":
				check(moved >= 10.0, "swam at least 10 m across the pond (%.1f m)" % moved)
		"push":
			if vehicle_arg == "forklift":
				check(crate_closest_ahead > 0.0 and crate_worst_ahead <= 3.0,
					"crate stayed within 3 m ahead while weaving (%.1f to %.1f m)" % [crate_closest_ahead, crate_worst_ahead])
				check(crate_worst_side <= 2.0, "crate stayed in front, not off to the side (max %.1f m)" % crate_worst_side)


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _finish() -> bool:
	print("RESULT drive %s %s: %s" % [vehicle_arg, scenario, "PASS" if failures == 0 else "FAIL (%d)" % failures])
	quit(1 if failures > 0 else 0)
	return true
