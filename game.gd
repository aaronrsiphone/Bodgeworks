extends Node
## Global game state (autoload, reachable from anywhere as `Game`).
## Carries the vehicle you're building between the garage and the test map.

const GARAGE_SCENE := "res://garage/garage.tscn"
const TEST_MAP_SCENE := "res://world/test_map.tscn"

## The blueprint currently in the garage. Empty until you build something.
var blueprint: Dictionary = {}


func _ready() -> void:
	InputSetup.ensure_actions()


func test_drive(bp: Dictionary) -> void:
	blueprint = bp
	get_tree().change_scene_to_file(TEST_MAP_SCENE)


func go_to_garage() -> void:
	get_tree().change_scene_to_file(GARAGE_SCENE)
