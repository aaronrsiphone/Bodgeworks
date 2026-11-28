extends SceneTree
## An autopilot plays Special Delivery: drives through waypoints around the pond
## pushing the crate, and reports the time and medal. Exits 1 if it doesn't
## finish within 90 s, or finishes slower than silver.
## godot --headless --path . --script res://tests/mission_test.gd -- res://tests/blueprints/forklift.json

const ROUTE := [Vector2(14, -10), Vector2(18, 12), Vector2(25, 20), Vector2(55, 20), Vector2(63, 12), Vector2(85, -10)]

var frame := 0
var next := 0
var game: Node


var path := "res://tests/blueprints/forklift.json"
var started := false
var shot_dir := "" # optional 2nd argument: save screenshots here (needs a display)
var done_frame := -1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
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
	if frame == 240 and shot_dir != "":
		root.get_viewport().get_texture().get_image().save_png(shot_dir.path_join("mission_01_pushing.png"))
	if m.finished and shot_dir != "" and done_frame < 0:
		done_frame = frame
	if m.finished and (shot_dir == "" or frame >= done_frame + 30):
		if shot_dir != "":
			root.get_viewport().get_texture().get_image().save_png(shot_dir.path_join("mission_02_delivered.png"))
		var tier: String = game.tier_for(m.time, m.gold_time, m.silver_time, m.bronze_time)
		var ok := tier == "gold" or tier == "silver"
		print("RESULT mission %s: %s  finished at %s  tier=%s (silver is %s)  crate=%s" % [path.get_file(), "PASS" if ok else "FAIL",
			game.format_time(m.time), tier, game.format_time(m.silver_time), m.cargo.global_position])
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
		print("t=%5.1f waypoint %d  vehicle (%5.1f %5.1f)  crate (%5.1f %5.1f %5.1f)  upright %.2f" % [m.time, next, pos.x, pos.y,
			m.cargo.global_position.x, m.cargo.global_position.y, m.cargo.global_position.z, v.global_basis.y.y])
	return false
