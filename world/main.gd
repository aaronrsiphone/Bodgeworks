extends Node3D
## The test map: spawns a vehicle from a blueprint and drives it with the player's controls.

## Blueprints you can cycle through with Tab (saved vehicles are added too).
@export var blueprints: Array[String] = [
	"res://data/blueprints/buggy.json",
	"res://data/blueprints/amphibian.json",
]

@onready var spawn: Marker3D = $Spawn
@onready var camera: ChaseCamera = $ChaseCamera
@onready var hud: Label = $HUD/Info

var keys_label: Label
var vehicle: Vehicle
var mission: Node # set when playing a mission (see missions/)
var _entries: Array[Dictionary] = []
var _index := 0


func _ready() -> void:
	InputSetup.ensure_actions()
	# Controls hint lives bottom-left so it never collides with mission text at the top.
	keys_label = hud.duplicate()
	keys_label.anchor_top = 1.0
	keys_label.anchor_bottom = 1.0
	keys_label.offset_top = -70
	keys_label.offset_bottom = -12
	keys_label.add_theme_font_size_override("font_size", 15)
	keys_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hud.get_parent().add_child(keys_label)
	if Game.mission_scene != "" and not Game.blueprint.is_empty():
		# Mission: only your garage build, starting where the mission says.
		mission = load(Game.mission_scene).instantiate()
		mission.main = self
		add_child(mission)
		spawn.global_transform = mission.start.global_transform
		_entries.append(Game.blueprint)
		spawn_vehicle(0)
		return
	# Free driving: whatever is in the garage comes first, then the starters, then saved vehicles.
	if not Game.blueprint.is_empty():
		_entries.append(Game.blueprint)
	var paths := blueprints.duplicate()
	for path in PartCatalog.blueprint_paths():
		if not paths.has(path):
			paths.append(path)
	for path in paths:
		_entries.append(PartCatalog.load_blueprint(path))
	spawn_vehicle(0)


func spawn_vehicle(index: int) -> void:
	_index = wrapi(index, 0, _entries.size())
	if vehicle:
		vehicle.queue_free()
	vehicle = Vehicle.new()
	vehicle.build(_entries[_index])
	vehicle.transform = spawn.transform
	add_child(vehicle)
	camera.target = vehicle
	camera.snap()


func _physics_process(_delta: float) -> void:
	if vehicle == null:
		return
	vehicle.throttle = Input.get_axis("reverse", "accelerate")
	vehicle.steer = Input.get_axis("steer_right", "steer_left")
	vehicle.brake = Input.is_action_pressed("brake")
	if vehicle.global_position.y < -30.0: # fell off the world somehow
		spawn_vehicle(_index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_vehicle"):
		vehicle.request_reset()
	elif event.is_action_pressed("next_vehicle") and mission == null:
		spawn_vehicle(_index + 1)
	elif event.is_action_pressed("garage"):
		Game.go_to_garage()


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var keys := "R  flip upright     G  back to garage" if mission else "R  flip upright     Tab  next vehicle     G  back to garage"
	hud.text = "%s   %d km/h   %d kg" % [vehicle.blueprint_name, roundi(vehicle.speed_kmh()), roundi(vehicle.mass)]
	# Fuel gauge: only for vehicles with fuel tanks, but everyone hears when they run dry.
	if vehicle.fuel_use > 0.0 and vehicle.fuel <= 0.0:
		hud.text += "   OUT OF FUEL! (T restart / G garage)" if mission else "   OUT OF FUEL! (Tab / G to refill)"
	elif vehicle.has_tanks and vehicle.fuel_capacity > 0.0:
		var full := vehicle.fuel / vehicle.fuel_capacity
		var bars := ceili(full * 10.0)
		hud.text += "   Fuel [%s%s] %d%%" % ["|".repeat(bars), ".".repeat(10 - bars), roundi(full * 100.0)]
	keys_label.text = "W/S  drive / reverse     A/D  steer     Space  brake\n" + keys
