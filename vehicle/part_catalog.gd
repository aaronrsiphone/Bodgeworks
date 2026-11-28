class_name PartCatalog
## Loads the part catalog (data/parts.json) and blueprints (data/blueprints/*.json).
## New parts come from editing the JSON, not from writing code.

const PARTS_PATH := "res://data/parts.json"
const STARTER_DIR := "res://data/blueprints"
const SAVE_DIR := "user://blueprints"

static var _parts: Dictionary = {}


static func parts() -> Dictionary:
	if _parts.is_empty():
		_parts = load_json(PARTS_PATH)
		# Keys starting with "_" are notes for people, not parts.
		for key in _parts.keys():
			if str(key).begins_with("_"):
				_parts.erase(key)
	return _parts


static func get_part(id: String) -> Dictionary:
	var all := parts()
	if not all.has(id):
		push_error("Unknown part '%s'. Is it in %s?" % [id, PARTS_PATH])
		return {}
	return all[id]


## The boxes a part is made of, in the part's own directions (before it's turned).
## Each is {"size": Vector3, "offset": Vector3} in metres, offset from the middle
## of the cell. A part without "shape" in parts.json is one whole cell. "shape"
## can be one box ({"size": ..., "offset": ...}) or a list of them.
static func shape_boxes(def: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shape = def.get("shape", null)
	var list: Array = []
	if shape is Dictionary:
		list = [shape]
	elif shape is Array:
		list = shape
	for b in list:
		var s: Array = b.get("size", [1, 1, 1])
		var o: Array = b.get("offset", [0, 0, 0])
		out.append({"size": Vector3(s[0], s[1], s[2]), "offset": Vector3(o[0], o[1], o[2])})
	if out.is_empty():
		out.append({"size": Vector3.ONE, "offset": Vector3.ZERO})
	return out


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
