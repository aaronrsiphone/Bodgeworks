extends Node
## Global game state (autoload, reachable from anywhere as `Game`).
## Carries your build between the garage and the test map, knows the missions,
## and keeps the save file (best times).

const GARAGE_SCENE := "res://garage/garage.tscn"
const TEST_MAP_SCENE := "res://world/test_map.tscn"
const SAVE_PATH := "user://save.json"

const MISSIONS := [
	{"id": "special_delivery", "name": "Special Delivery", "scene": "res://missions/special_delivery.tscn"},
]

const TIER_COLORS := {"gold": Color("#ffd700"), "silver": Color("#d0d6de"), "bronze": Color("#d08a4a")}

## The blueprint currently in the garage. Empty until you build something.
var blueprint: Dictionary = {}
## The mission scene to play in the test map, or "" for free driving.
var mission_scene := ""
var save := {"missions": {}}
## False keeps results in memory only (tools that stage results set this).
var persist := true


func _ready() -> void:
	InputSetup.ensure_actions()
	var data := PartCatalog.load_json(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else {}
	if data.has("missions"):
		save = data


func test_drive(bp: Dictionary) -> void:
	blueprint = bp
	mission_scene = ""
	get_tree().change_scene_to_file(TEST_MAP_SCENE)


func start_mission(bp: Dictionary, id: String) -> void:
	blueprint = bp
	for m in MISSIONS:
		if m.id == id:
			mission_scene = m.scene
	get_tree().change_scene_to_file(TEST_MAP_SCENE)


func go_to_garage() -> void:
	get_tree().change_scene_to_file(GARAGE_SCENE)


## "gold", "silver", "bronze" or "" for a time. Faster is better.
static func tier_for(time: float, gold: float, silver: float, bronze: float) -> String:
	if time <= gold: return "gold"
	if time <= silver: return "silver"
	if time <= bronze: return "bronze"
	return ""


static func format_time(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]


func best(id: String) -> Dictionary:
	return save.missions.get(id, {})


## Saves the result if it's a new best. Returns true if it was.
func record_result(id: String, time: float, tier: String) -> bool:
	var old := best(id)
	if not old.is_empty() and float(old.time) <= time:
		return false
	save.missions[id] = {"time": time, "tier": tier, "vehicle": blueprint.get("name", "")}
	if not persist:
		return true
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save, "  "))
	return true
