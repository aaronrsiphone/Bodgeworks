class_name PartCatalog
## Loads the part catalog (data/parts.json) and blueprints (data/blueprints/*.json).
## New parts come from editing the JSON, not from writing code.

const PARTS_PATH := "res://data/parts.json"
const STARTER_DIR := "res://data/blueprints"
const SAVE_DIR := "user://blueprints"

## Behaviours that do something when you press an accessory button (1/2/3).
## A new one needs an entry here plus an _activate_<name>() function in vehicle.gd.
const BUTTON_BEHAVIOURS := ["spring"]
const BUTTON_COUNT := 3 # accessory buttons 1, 2 and 3

static var _parts: Dictionary = {}


## Which way a part faces for a blueprint "rot" value.
##   0-3: turned round in 90 degree steps (0 = forward, 1 = left, 2 = back, 3 = right)
##   4:   pointing down      5: pointing up   (only parts with "can_face_up_down")
static func rot_basis(rot: int) -> Basis:
	match rot:
		4: return Basis(Vector3.RIGHT, -PI / 2.0) # forward (-z) tipped to point at the floor
		5: return Basis(Vector3.RIGHT, PI / 2.0)
	return Basis(Vector3.UP, rot * PI / 2.0)


## How many ways R can turn this part: wheels 1, most parts 4, up/down parts 6.
static func rot_count(def: Dictionary) -> int:
	if def.has("wheel"):
		return 1
	return 6 if def.get("can_face_up_down", false) else 4


## True if pressing a button makes this part do something.
static func uses_button(def: Dictionary) -> bool:
	for b in BUTTON_BEHAVIOURS:
		if def.has(b):
			return true
	return false


static func parts() -> Dictionary:
	if _parts.is_empty():
		_parts = load_json(PARTS_PATH)
		_parts.erase("_comment")
	return _parts


static func get_part(id: String) -> Dictionary:
	var all := parts()
	if not all.has(id):
		push_error("Unknown part '%s'. Is it in %s?" % [id, PARTS_PATH])
		return {}
	return all[id]


static func load_blueprint(path: String) -> Dictionary:
	return load_json(path)


static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read %s" % path)
		return {}
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("%s is not valid JSON (check for a missing comma or bracket)" % path)
		return {}
	return data


## Starter blueprints that ship with the game, then the player's saved ones.
static func blueprint_paths() -> Array[String]:
	var out := _json_files(STARTER_DIR)
	out.append_array(_json_files(SAVE_DIR))
	return out


static func save_blueprint(bp: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file_name: String = str(bp.get("name", "vehicle")).strip_edges().validate_filename()
	if file_name.is_empty():
		file_name = "vehicle"
	var path := SAVE_DIR.path_join(file_name + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not save %s" % path)
		return ""
	f.store_string(JSON.stringify(bp, "  "))
	return path


static func _json_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var names := Array(DirAccess.get_files_at(dir))
	names.sort()
	for n in names:
		if n.ends_with(".json"):
			out.append(dir.path_join(n))
	return out
