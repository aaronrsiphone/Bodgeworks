extends SceneTree
## An autopilot plays Special Delivery: drives through waypoints around the pond
## pushing the crate, and reports the time and medal. Exits 1 if it doesn't
## finish within 90 s, or finishes slower than silver.
## godot --headless --path . --script res://tests/mission_test.gd -- res://tests/blueprints/forklift.json
##
## Add "carry" to the arguments for a vehicle with trays: the crate is put in its
## trays before the start, and the run also fails if the crate isn't still in
## them at the finish (it fell out on a turn).
## godot --headless --path . --script res://tests/mission_test.gd -- res://tests/blueprints/carrier.json carry

const ROUTE := [Vector2(14, -10), Vector2(18, 12), Vector2(25, 20), Vector2(55, 20), Vector2(63, 12), Vector2(85, -10)]

var frame := 0
var next := 0
var game: Node


var path := "res://tests/blueprints/forklift.json"
var started := false
var shot_dir := "" # optional 2nd argument: save screenshots here (needs a display)
var done_frame := -1
var carry := false # "carry" argument: start with the crate in the vehicle's trays
var loaded := false
var worst_slide := 0.0 # how far the crate slid around in the trays (m)

const LOAD_FRAME := 30 # put the crate in once the vehicle has settled on its wheels
const GO_FRAME := 60 # ...and drive off once the crate has settled in the trays


func _initialize() -> void:
	var args := []
	for a in OS.get_cmdline_user_args():
		if a == "carry":
			carry = true
		else:
			args.append(a)
	if args.size() > 0:
		path = args[0]
	if args.size() > 1:
		shot_dir = args[1]


## Runs on the first frame, once the Game autoload exists.
func _start() -> void:
	game = root.get_node("Game")
	game.blueprint = PartCatalog.load_blueprint(path)
	game.save = {"missions": {}} # start fresh, no best times
	game.mission_scene = "res://missions/special_delivery.tscn"
	change_scene_to_file("res://world/test_map.tscn")


func _physics_process(_delta: float) -> bool:
	if not started:
		started = true
		_start()
		return false
	frame += 1
	var main := current_scene
	if main == null or main.get("vehicle") == null or main.mission == null:
		if frame > 600:
			print("RESULT mission %s: FAIL  the mission never started" % path.get_file())
			quit(1)
			return true
		return false
	var v: Vehicle = main.vehicle
	var m = main.mission
	if carry:
		if not loaded:
			if frame < LOAD_FRAME:
				return false
			if _tray_middle(v) == Vector3.INF:
				print("RESULT mission %s: FAIL  carry needs a vehicle with trays" % path.get_file())
				quit(1)
				return true
			# Lower the crate into the trays (the crate is 1.2 m, the tray floor is 0.3 m below the cell middle).
			m.cargo.global_transform = Transform3D(v.global_basis, v.to_global(_tray_middle(v) + Vector3(0, -0.3 + 0.62, 0)))
			m.cargo.linear_velocity = v.linear_velocity
			m.cargo.angular_velocity = Vector3.ZERO
			loaded = true
			return false
		if frame < GO_FRAME:
			return false
		if not m.finished:
			worst_slide = maxf(worst_slide, _crate_slide(v, m.cargo))
	if frame == 240 and shot_dir != "":
		root.get_viewport().get_texture().get_image().save_png(shot_dir.path_join("mission_01_pushing.png"))
	if m.finished and shot_dir != "" and done_frame < 0:
		done_frame = frame
	if m.finished and (shot_dir == "" or frame >= done_frame + 30):
		if shot_dir != "":
			root.get_viewport().get_texture().get_image().save_png(shot_dir.path_join("mission_02_delivered.png"))
		var tier: String = game.tier_for(m.time, m.gold_time, m.silver_time, m.bronze_time)
		var ok := tier == "gold" or tier == "silver"
		var extra := ""
		if carry:
			# Still in the trays? Its middle must be over the 2 m bed and above the tray floor.
			var slide := _crate_slide(v, m.cargo)
			var in_trays := slide < 0.6 and v.to_local(m.cargo.global_position).y > _tray_middle(v).y
			ok = ok and in_trays
			extra = "  crate %s (%.2f m from the bed's middle, slid %.2f m at most)" % [
				"still in the trays" if in_trays else "NOT in the trays", slide, worst_slide]
		print("RESULT mission %s: %s  finished at %s  tier=%s (silver is %s)  crate=%s%s" % [path.get_file(), "PASS" if ok else "FAIL",
			game.format_time(m.time), tier, game.format_time(m.silver_time), m.cargo.global_position, extra])
		quit(0 if ok else 1)
		return true
	if frame > 60 * 90:
		print("RESULT mission %s: FAIL  TIMEOUT after 90 s, crate at %s, vehicle at %s" % [path.get_file(), m.cargo.global_position, v.global_position])
		quit(1)
		return true

	var pos := Vector2(v.global_position.x, v.global_position.z)
	if next < ROUTE.size() - 1 and pos.distance_to(ROUTE[next]) < 5.0:
		next += 1
	var target: Vector2 = ROUTE[next]
	var to := Vector3(target.x - pos.x, 0, target.y - pos.y)
	var fwd := -v.global_basis.z
	fwd.y = 0
	var angle := fwd.signed_angle_to(to, Vector3.UP)
	var steer := clampf(angle * 2.0, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if steer > 0.05: Input.action_press("steer_left", steer)
	if steer < -0.05: Input.action_press("steer_right", -steer)
	Input.action_press("accelerate", 1.0 if absf(angle) < 0.5 else 0.6)
	if frame % 60 == 0:
		print("t=%5.1f waypoint %d  vehicle (%5.1f %5.1f)  crate (%5.1f %5.1f %5.1f)  upright %.2f%s" % [m.time, next, pos.x, pos.y,
			m.cargo.global_position.x, m.cargo.global_position.y, m.cargo.global_position.z, v.global_basis.y.y,
			("  in trays %.2f m off middle" % _crate_slide(v, m.cargo)) if carry else ""])
	return false


## The middle of the vehicle's trays, in the vehicle's own directions (INF if it has none).
func _tray_middle(v: Vehicle) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for p in v.parts:
		if p.id == "tray":
			sum += p.pos
			n += 1
	return sum / n if n > 0 else Vector3.INF


## How far (sideways/along the vehicle) the crate's middle is from the middle of the trays.
func _crate_slide(v: Vehicle, cargo: RigidBody3D) -> float:
	var d := v.to_local(cargo.global_position) - _tray_middle(v)
	return Vector2(d.x, d.z).length()
