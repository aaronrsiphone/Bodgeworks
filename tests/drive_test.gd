extends SceneTree
## Headless smoke test: loads the test map, holds the throttle, prints what happens,
## then checks the scenario's expectations. Exits 1 if any of them fail.
## Run:  godot --headless --path . --script res://tests/drive_test.gd
##   or: godot --headless --path . --script res://tests/drive_test.gd -- amphibian pond

const SCENARIOS := ["straight", "turn", "pond", "ramp", "push", "pyramid", "swim", "jump", "fly"]
const VEHICLES := ["buggy", "amphibian", "forklift", "winged_buggy", "plane"]
const BLUEPRINTS := {
	"amphibian": "res://data/blueprints/amphibian.json",
	"forklift": "res://tests/blueprints/forklift.json",
	"winged_buggy": "res://tests/blueprints/winged_buggy.json",
	"plane": "res://data/blueprints/plane.json",
}
const FRAMES := 600
const JUMP_FRAMES := 1500 # the jump scenario can do two jumps, then stops early
const RAMP_TOP_Z := -42.0 # past here on the jump ramp, losing the ground means we jumped

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
var max_height := -INF
# Jump scenario: a vehicle with wings first watches a plain buggy jump, to compare.
var jump_runs: Array[Dictionary] = [] # {name, distance, height} per finished jump
var jump_start := 0 # frame this jump's run-up started
var takeoff := Vector3.INF # where the wheels left the ramp
var airborne := 0 # frames in the air so far
var jump_top := -INF


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		vehicle_arg = args[0]
	if args.size() > 1:
		scenario = args[1]
	# A blueprint path works too (handy for trying out a new design): res://... or user://...
	var is_path := vehicle_arg.ends_with(".json")
	if (vehicle_arg not in VEHICLES and not is_path) or scenario not in SCENARIOS:
		printerr("FAIL unknown vehicle or scenario: %s %s (vehicles: %s, scenarios: %s)" % [vehicle_arg, scenario, VEHICLES, SCENARIOS])
		quit(1)
		return
	main = load("res://world/test_map.tscn").instantiate()
	if BLUEPRINTS.has(vehicle_arg) or is_path:
		# The test map spawns the first one. The buggy comes second, for comparing jumps.
		main.blueprints.assign([BLUEPRINTS.get(vehicle_arg, vehicle_arg), "res://data/blueprints/buggy.json"])
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
		if scenario == "fly":
			# The long open runway along the east side of the map, heading north.
			v.global_transform = Transform3D(Basis.IDENTITY, Vector3(100, 1, 110))
		if scenario == "jump" and vehicle_arg != "buggy":
			main.spawn_vehicle(1) # the plain buggy jumps first
			v = main.vehicle
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
		"fly":
			if frame > 30: Input.action_press("accelerate")
		"jump":
			if frame - jump_start > 30: Input.action_press("accelerate")
			if _track_jump(v):
				return _finish()
			v = main.vehicle # may have swapped from the buggy to the vehicle under test
	if frame > 2:
		max_height = maxf(max_height, v.global_position.y)
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
	if frame % (10 if scenario == "jump" and takeoff != Vector3.INF else 30) == 0:
		var up := v.global_basis.y
		var grounded := v.wheels.filter(func(w): return w.grounded).size()
		var heading := _heading(v)
		# pitch: + = nose up. roll: + = leaning right. (degrees)
		var pitch := rad_to_deg(asin(clampf(-v.global_basis.z.y, -1.0, 1.0)))
		var roll := rad_to_deg(asin(clampf(-v.global_basis.x.y, -1.0, 1.0)))
		print("t=%4.1fs pos=(%6.1f %5.2f %6.1f) speed=%5.1f km/h upright=%.2f pitch=%3.0f roll=%3.0f wheels_down=%d heading=%4.0f" % [
			frame / 60.0, v.global_position.x, v.global_position.y, v.global_position.z,
			v.speed_kmh(), up.y, pitch, roll, grounded, heading])
		if crate:
			print("        crate=(%6.1f %5.2f %6.1f) %.1f m ahead" % [crate.position.x, crate.position.y, crate.position.z, (crate.position - v.global_position).dot(-v.global_basis.z)])
	if scenario == "jump" and frame >= JUMP_FRAMES:
		check(false, "finished both jumps within %d frames" % JUMP_FRAMES)
		return _finish()
	if frame == FRAMES and scenario != "jump":
		print("min upright: %.2f  %s" % [min_upright, "FLIPPED" if min_upright < 0.3 else "stayed upright"])
		_check_expectations(v)
		return _finish()
	return false


## Jump scenario: watches for the wheels leaving the jump ramp and landing again.
## Returns true when every jump is done (and checks have run).
func _track_jump(v: Vehicle) -> bool:
	var grounded := v.wheels.filter(func(w): return w.grounded).size()
	if takeoff == Vector3.INF:
		if grounded == 0 and v.global_position.z < RAMP_TOP_Z:
			takeoff = v.global_position
			print("        %s took off at %.1f km/h" % [v.blueprint_name, v.speed_kmh()])
		return false
	jump_top = maxf(jump_top, v.global_position.y)
	airborne += 1
	if grounded == 0 or airborne < 10:
		return false
	var d := Vector2(v.global_position.x - takeoff.x, v.global_position.z - takeoff.z).length()
	jump_runs.append({"name": v.blueprint_name, "distance": d, "height": jump_top - takeoff.y})
	print("        %s landed: jumped %.1f m, %.1f m above the ramp top, %.1f s in the air" % [v.blueprint_name, d, jump_top - takeoff.y, airborne / 60.0])
	var want := 1 if vehicle_arg == "buggy" else 2
	if jump_runs.size() < want:
		# Now the vehicle under test, from the same start.
		Input.action_release("accelerate")
		main.spawn_vehicle(0)
		jump_start = frame
		takeoff = Vector3.INF
		airborne = 0
		jump_top = -INF
		return false
	print("min upright: %.2f" % min_upright)
	check(min_upright > 0.5, "didn't flip on the jump (min upright %.2f > 0.5)" % min_upright)
	if want == 2:
		var plain: float = jump_runs[0].distance
		var winged: float = jump_runs[1].distance
		check(winged >= plain * 1.3, "%s jumped at least 30%% further than the plain buggy (%.1f m vs %.1f m, %+.0f%%)" % [
			jump_runs[1].name, winged, plain, (winged / plain - 1.0) * 100.0])
	return true


## 0 = north, +90 = west (turned left).
func _heading(v: Vehicle) -> float:
	var fwd := -v.global_basis.z
	return rad_to_deg(atan2(-fwd.x, -fwd.z))


func _check_expectations(v: Vehicle) -> void:
	var moved := Vector2(v.global_position.x - start_pos.x, v.global_position.z - start_pos.z).length()
	print("travelled %.1f m, turned %.0f deg" % [moved, turned])
	# Every scenario: nothing should tip over. Planes may bank and pitch a bit more.
	var upright_min := 0.5 if scenario == "fly" else 0.8
	check(min_upright > upright_min, "stayed upright (min upright %.2f > %.1f)" % [min_upright, upright_min])
	match scenario:
		"fly":
			var climb := v.global_position.y - start_pos.y
			print("height: start %.1f m, highest %.1f m, end %.1f m" % [start_pos.y, max_height, v.global_position.y])
			check(climb >= 5.0, "took off and climbed at least 5 m by itself (%.1f m)" % climb)
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
