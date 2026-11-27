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

var vehicle: Vehicle
var _entries: Array[Dictionary] = []
var _index := 0


func _ready() -> void:
	InputSetup.ensure_actions()
	# Whatever is in the garage comes first, then the starters, then saved vehicles.
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
	elif event.is_action_pressed("next_vehicle"):
		spawn_vehicle(_index + 1)
	elif event.is_action_pressed("garage"):
		Game.go_to_garage()


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	hud.text = "%s   %d km/h   %d kg\n\nW/S  drive / reverse     A/D  steer     Space  brake\nR  flip upright     Tab  next vehicle     G  back to garage" % [
		vehicle.blueprint_name, roundi(vehicle.speed_kmh()), roundi(vehicle.mass)]
