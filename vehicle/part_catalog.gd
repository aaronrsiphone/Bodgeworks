class_name PartCatalog
## Loads the part catalog (data/parts.json) and blueprints (data/blueprints/*.json).
## New parts come from editing the JSON, not from writing code.

const PARTS_PATH := "res://data/parts.json"

static var _parts: Dictionary = {}


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
