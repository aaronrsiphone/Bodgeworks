extends Node3D
## The garage: build vehicles out of parts like Lego.
##
##   Left click   place the see-through "ghost" part
##   Right click  remove the part under the mouse
##   Right drag   turn the camera      Scroll  zoom      Middle drag  slide
##   1-9          pick a part          R       rotate the part
##   Ctrl+Z       undo                 G       test drive

const BUDGET := 60 # most parts a vehicle can have
const LIMIT := 12 # how far from the middle you can build (in cells)
const FLOOR_Y := -0.5 # the floor is the bottom of the y = 0 cells

@onready var camera: GarageCamera = $Camera
@onready var build_root: Node3D = $Build

## Vector3i cell -> {"part": id, "rot": 0-3, "node": StaticBody3D}
var parts := {}
var part_ids: Array[String] = []
var selected := ""
var rot := 0

var _undo: Array = []
var _ghost: Node3D
var _ghost_cell := Vector3i.ZERO
var _ghost_ok := false
var _ghost_reason := ""
var _right_down := false

var _info: RichTextLabel
var _name_edit: LineEdit
var _load_menu: OptionButton
var _part_buttons := {}
var _toast: Label
var _toast_time := 0.0
var _bad_material: StandardMaterial3D


func _ready() -> void:
	_bad_material = StandardMaterial3D.new()
	_bad_material.albedo_color = Color(1, 0.2, 0.2, 0.45)
	_bad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for id in PartCatalog.parts().keys():
		part_ids.append(id)
	_build_ui()

	if Game.blueprint.is_empty():
		_load_blueprint(PartCatalog.load_blueprint("res://data/blueprints/buggy.json"))
		_name_edit.text = "My Vehicle"
		_changed()
	else:
		_load_blueprint(Game.blueprint)
	_select(part_ids[0])


# --- building --------------------------------------------------------------

func place(cell: Vector3i, id: String, r := 0) -> void:
	var def := PartCatalog.get_part(id)
	if def.has("wheel"):
		r = 0 # wheels always face forward
	var body := StaticBody3D.new()
	body.position = Vector3(cell)
	body.set_meta("cell", cell)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	var visual := PartVisuals.create(id, def)
	visual.basis = Basis(Vector3.UP, r * PI / 2.0)
	body.add_child(visual)
	build_root.add_child(body)
	parts[cell] = {"part": id, "rot": r, "node": body}


func remove(cell: Vector3i) -> void:
	if parts.has(cell):
		parts[cell].node.queue_free()
		parts.erase(cell)


func clear() -> void:
	for cell in parts.keys():
		remove(cell)


## Why a part can't go in this cell, or "" if it can.
func why_not(cell: Vector3i) -> String:
	if parts.has(cell):
		return "There's already a part there"
	if cell.y < 0:
		return "Can't build under the floor"
	if absi(cell.x) > LIMIT or absi(cell.z) > LIMIT or cell.y > LIMIT:
		return "Too far from the middle"
	if parts.size() >= BUDGET:
		return "Part budget is full (%d)" % BUDGET
	if not parts.is_empty() and not _touches_build(cell):
		return "Parts have to touch your vehicle"
	return ""


func _touches_build(cell: Vector3i) -> bool:
	for d in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
		if parts.has(cell + d):
			return true
	return false


func to_blueprint() -> Dictionary:
	var list := []
	for cell in parts:
		list.append({"part": parts[cell].part, "pos": [cell.x, cell.y, cell.z], "rot": parts[cell].rot})
	var vehicle_name := _name_edit.text.strip_edges()
	return {"name": vehicle_name if vehicle_name != "" else "My Vehicle", "parts": list}


func _load_blueprint(bp: Dictionary) -> void:
	clear()
	for entry in bp.get("parts", []):
		var p: Array = entry.get("pos", [0, 0, 0])
		place(Vector3i(int(p[0]), int(p[1]), int(p[2])), entry.get("part", "block"), int(entry.get("rot", 0)))
	_name_edit.text = bp.get("name", "My Vehicle")
	_changed()


func _snapshot() -> void:
	_undo.append(to_blueprint())
	if _undo.size() > 100:
		_undo.pop_front()


func undo() -> void:
	if _undo.is_empty():
		_say("Nothing to undo")
		return
	_load_blueprint(_undo.pop_back())


func _changed() -> void:
	Game.blueprint = to_blueprint()
	_update_info()
	_update_ghost()


# --- mouse and keys --------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus() # stop typing in the name box when you click the world

	if camera.handle_input(event):
		_update_ghost()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_place()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_right_down = true
				camera.dragging = false
			elif _right_down:
				_right_down = false
				if not camera.dragging: # a click, not a camera drag
					_try_remove()
	elif event is InputEventMouseMotion:
		_update_ghost()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and event.ctrl_pressed:
			undo()
		elif event.keycode == KEY_R:
			rot = (rot + 1) % 4
			_update_ghost()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var i: int = event.keycode - KEY_1
			if i < part_ids.size():
				_select(part_ids[i])
		elif event.is_action("garage") or event.keycode == KEY_ENTER:
			_test_drive()


func _try_place() -> void:
	_update_ghost()
	if _ghost == null or not _ghost.visible:
		return
	if not _ghost_ok:
		_say(_ghost_reason)
		return
	_snapshot()
	place(_ghost_cell, selected, rot)
	_changed()


func _try_remove() -> void:
	var hit := _pick()
	if hit.has("part_cell"):
		_snapshot()
		remove(hit.part_cell)
		_changed()


## What's under the mouse: the part it's over (if any) and the cell a new part would go in.
func _pick() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("cell"):
		var cell: Vector3i = hit.collider.get_meta("cell")
		return {"part_cell": cell, "place_cell": cell + _face(hit.normal)}
	if dir.y < -0.01: # aim at the floor
		var p := from + dir * ((FLOOR_Y - from.y) / dir.y)
		return {"place_cell": Vector3i(roundi(p.x), 0, roundi(p.z))}
	return {}


## Turn a surface normal into the direction of the face it points out of.
func _face(n: Vector3) -> Vector3i:
	var a := n.abs()
	if a.x >= a.y and a.x >= a.z:
		return Vector3i(signi(roundi(n.x)), 0, 0)
	if a.y >= a.z:
		return Vector3i(0, signi(roundi(n.y)), 0)
	return Vector3i(0, 0, signi(roundi(n.z)))


func _update_ghost() -> void:
	if _ghost == null:
		return
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var hit := {} if over_ui else _pick()
	if not hit.has("place_cell"):
		_ghost.visible = false
		return
	_ghost.visible = true
	_ghost_cell = hit.place_cell
	_ghost.position = Vector3(_ghost_cell)
	var r := 0 if PartCatalog.get_part(selected).has("wheel") else rot
	_ghost.basis = Basis(Vector3.UP, r * PI / 2.0)
	_ghost_reason = why_not(_ghost_cell)
	_ghost_ok = _ghost_reason == ""
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mi.get_meta("ghost_material") if _ghost_ok else _bad_material


func _select(id: String) -> void:
	selected = id
	if _ghost:
		_ghost.queue_free()
	_ghost = PartVisuals.create(id, PartCatalog.get_part(id))
	# See-through copy of each piece's colour.
	for mi in _ghost.find_children("*", "MeshInstance3D", true, false):
		var m: StandardMaterial3D = mi.mesh.material.duplicate()
		m.albedo_color.a = 0.5
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.set_meta("ghost_material", m)
	add_child(_ghost)
	for pid in _part_buttons:
		_part_buttons[pid].button_pressed = pid == id
	_update_ghost()


func _start_mission(id: String) -> void:
	if parts.is_empty():
		_say("Build something first!")
		return
	Game.start_mission(to_blueprint(), id)


func _medal_icon(color: Color) -> ImageTexture:
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		for x in 22:
			if Vector2(x - 10.5, y - 10.5).length() <= 10.0:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func _test_drive() -> void:
	if parts.is_empty():
		_say("Build something first!")
		return
	Game.test_drive(to_blueprint())


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)


# --- info panel ------------------------------------------------------------

func _update_info() -> void:
	var mass := 0.0
	var buoyancy := 0.0
	var count := {}
	var defs := []
	for cell in parts:
		var id: String = parts[cell].part
		var def := PartCatalog.get_part(id)
		defs.append(def)
		mass += float(def.get("mass", 0))
		buoyancy += float(def.get("buoyancy", 0))
		for behaviour in ["seat", "engine", "wheel", "thrust"]:
			if def.has(behaviour):
				count[behaviour] = count.get(behaviour, 0) + 1

	var t := "[font_size=24][b]%s[/b][/font_size]\n" % _name_edit.text
	t += "Parts: %d / %d     Weight: %d kg\n" % [parts.size(), BUDGET, roundi(mass)]
	if parts.size() > 0:
		t += ("[color=#7fd4ff]Floats in water[/color]\n" if buoyancy > mass else "[color=#b0b0b0]Sinks in water[/color]\n")
	if parts.is_empty():
		t += "[color=#ffd070]Click the floor to start building![/color]\n"
	else:
		if not count.has("seat"):
			t += "[color=#ff8080]No seat: nobody can drive it![/color]\n"
		if not count.has("engine"):
			t += "[color=#ff8080]No engine: it won't go![/color]\n"
		var f := Vehicle.fuel_for(defs)
		var secs := Vehicle.fuel_seconds(f.capacity, f.use)
		if f.use > 0.0:
			t += "Fuel: %d s at full throttle%s\n" % [roundi(secs), "" if f.tanks > 0 else " (seat reserve; add a Fuel Tank for more)"]
		if not count.has("wheel") and not count.has("thrust"):
			t += "[color=#ff8080]No wheels or propellers: it can't move![/color]\n"
	_info.text = t


func _say(text: String) -> void:
	_toast.text = text
	_toast_time = 2.5


# --- on-screen buttons -----------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 18
	ui.theme = theme
	layer.add_child(ui)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.position = Vector2(16, 12)
	_info.size = Vector2(460, 200)
	_info.add_theme_constant_override("outline_size", 6)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	ui.add_child(_info)

	# Top right: name, save, load, undo, clear, drive.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_END
	top.anchor_left = 1.0
	top.anchor_right = 1.0
	top.offset_left = -900
	top.offset_right = -16
	top.offset_top = 12
	top.offset_bottom = 52
	ui.add_child(top)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Vehicle name"
	_name_edit.custom_minimum_size.x = 180
	_name_edit.text_changed.connect(func(_t): _update_info())
	_name_edit.text_submitted.connect(func(_t): _name_edit.release_focus())
	top.add_child(_name_edit)
	_button(top, "Save", _save)
	_load_menu = OptionButton.new()
	_load_menu.focus_mode = Control.FOCUS_NONE
	_load_menu.item_selected.connect(_on_load_selected)
	top.add_child(_load_menu)
	_refresh_load_menu()
	_button(top, "Undo", undo)
	_button(top, "Clear", func():
		_snapshot()
		clear()
		_changed())
	var drive := _button(top, "  Test Drive! (G)  ", _test_drive)
	drive.add_theme_color_override("font_color", Color("#7dff8a"))

	# Right side: missions, with your best medal.
	var missions := VBoxContainer.new()
	missions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	missions.anchor_left = 1.0
	missions.anchor_right = 1.0
	missions.offset_left = -300
	missions.offset_right = -16
	missions.offset_top = 64
	ui.add_child(missions)
	var heading := Label.new()
	heading.text = "Missions"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_constant_override("outline_size", 6)
	heading.add_theme_color_override("font_outline_color", Color.BLACK)
	missions.add_child(heading)
	for m in Game.MISSIONS:
		var b := _button(missions, m.name, _start_mission.bind(m.id))
		b.custom_minimum_size.y = 44
		var best := Game.best(m.id)
		if not best.is_empty():
			b.text += "   %s" % Game.format_time(float(best.time))
			if best.tier != "":
				b.icon = _medal_icon(Game.TIER_COLORS[best.tier])

	# Bottom: one button per part.
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_top = -64
	bar.offset_bottom = -16
	ui.add_child(bar)
	for i in part_ids.size():
		var id := part_ids[i]
		var def := PartCatalog.get_part(id)
		var b := _button(bar, "%d  %s" % [i + 1, def.get("name", id)], _select.bind(id))
		b.toggle_mode = true
		b.icon = PartVisuals.icon(def)
		b.custom_minimum_size.y = 44
		_part_buttons[id] = b

	var help := Label.new()
	help.text = "Left click: add part     Right click: remove     Right drag: turn camera     Scroll: zoom     R: rotate     Ctrl+Z: undo"
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.anchor_right = 1.0
	help.offset_top = -96
	help.offset_bottom = -70
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_constant_override("outline_size", 5)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	ui.add_child(help)

	_toast = Label.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.anchor_top = 0.5
	_toast.anchor_bottom = 0.5
	_toast.offset_top = 120
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", Color("#ffd070"))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.modulate.a = 0.0
	ui.add_child(_toast)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE # so Space / arrows don't press buttons
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _save() -> void:
	var path := PartCatalog.save_blueprint(to_blueprint())
	if path != "":
		_say("Saved \"%s\"" % _name_edit.text)
		_refresh_load_menu()


func _refresh_load_menu() -> void:
	_load_menu.clear()
	_load_menu.add_item("Load...")
	for path in PartCatalog.blueprint_paths():
		var bp := PartCatalog.load_blueprint(path)
		var tag := "" if path.begins_with("user://") else "  (starter)"
		_load_menu.add_item(str(bp.get("name", path.get_file())) + tag)
		_load_menu.set_item_metadata(_load_menu.item_count - 1, path)
	_load_menu.select(0)


func _on_load_selected(index: int) -> void:
	if index == 0:
		return
	_snapshot()
	_load_blueprint(PartCatalog.load_blueprint(_load_menu.get_item_metadata(index)))
	_load_menu.select(0)
	_say("Loaded \"%s\"" % _name_edit.text)
