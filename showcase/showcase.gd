extends Node3D
## Shows off the design kit (kit/kit.gd): every part in two rows at the front,
## and the vehicle platforms (kit/platforms.gd) behind them.
##
## Open showcase/showcase.tscn in Godot and press F6 to look round.
## Right-drag or the arrow keys turn the camera, scroll zooms, middle-drag slides.
## Space jumps the camera to the next thing to look at.

## How far apart the parts stand.
const PART_SPACING := 2.6
## How far apart the platforms stand.
const PLATFORM_SPACING := 9.0
## Propellers spin this fast (turns per second).
const SPIN_SPEED := 1.5

var camera: GarageCamera
## [name, centre, camera distance] for each thing Space can jump to.
var stops := []
var stop := 0


func _ready() -> void:
	_build_world()
	_build_parts()
	_build_platforms()
	camera = GarageCamera.new()
	camera.focus = Vector3(0, 0.5, -3)
	camera.distance = 26.0
	camera.yaw = deg_to_rad(-25)
	camera.pitch = deg_to_rad(-25)
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	# Spin every propeller and rotor.
	for s in find_children("Spinner", "", true, false):
		var spinner := s as Node3D
		# Propellers turn round their own Z; a part can say otherwise (the helicopter rotor turns round Y).
		var axis: Vector3 = spinner.get_meta("spin_axis", Vector3.BACK)
		spinner.rotate_object_local(axis, TAU * SPIN_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if camera.handle_input(event):
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		stop = (stop + 1) % stops.size()
		camera.focus = stops[stop][1]
		camera.distance = stops[stop][2]
		camera._apply()


func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#5d8fd6")
	sky_mat.sky_horizon_color = Color("#cfe0f0")
	sky_mat.ground_horizon_color = Color("#cfe0f0")
	sky_mat.ground_bottom_color = Color("#b8c4d0")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true # soft shadows in corners make the bolts and seams pop
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	# A workshop floor with a 1 m grid.
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(200, 200)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = load("res://assets/garage_grid.png")
	floor_mat.uv1_scale = Vector3(200, 200, 1)
	floor_mat.albedo_color = Color("#c9cdd3")
	floor_mat.roughness = 0.9
	Kit.add(self, floor_mesh, floor_mat, Vector3(0, 0, -6))


## Every kit part, two rows of eight, each on a little stand with its name.
func _build_parts() -> void:
	var parts := [
		["Block", Kit.block()], ["Connector", Kit.connector()], ["Beam", Kit.beam(3)],
		["Truss", Kit.truss(3)], ["Plate", Kit.plate(2, 2)], ["Wheel", Kit.wheel()],
		["Pontoon", Kit.pontoon()], ["Engine", Kit.engine()],
		["Propeller", Kit.propeller()], ["Ducted fan", Kit.ducted_fan()],
		["Wing", Kit.wing(2.0, 1.0, 0.7, 0.1, [Kit.YELLOW, Kit.CREAM, Kit.YELLOW, Kit.RED])],
		["Fin", Kit.fin()], ["Tank", Kit.tank()], ["Seat", Kit.seat()],
		["Dome", Kit.dome()], ["Porthole & lamp", _porthole_and_lamp()],
	]
	for i in parts.size():
		var row := i / 8
		var col := i % 8
		var pos := Vector3((col - 3.5) * PART_SPACING, 0.0, 2.0 + row * 3.0)
		var part: Node3D = parts[i][1]
		var height := 0.8 if parts[i][0] != "Dome" else 0.25
		if parts[i][0] in ["Beam", "Truss"]:
			part.scale = Vector3.ONE * 0.7 # long ones, shrunk to fit in a row
		part.position = pos + Vector3(0, height, 0)
		# Turn each part a bit so you see two sides; wheels show their hub instead.
		part.rotation.y = deg_to_rad(60 if parts[i][0] == "Wheel" else -30)
		add_child(part)
		_label(parts[i][0], pos + Vector3(0, 0.05, 1.5))
	stops.append(["parts", Vector3(0, 0.8, 3.5), 14.0])


func _porthole_and_lamp() -> Node3D:
	var n := Kit.group("PortholeAndLamp")
	Platforms.place(n, Kit.porthole(0.3), Vector3(-0.35, 0, 0))
	Platforms.place(n, Kit.lamp(0.18), Vector3(0.45, 0, 0))
	return n


## The vehicle platforms in a row behind the parts.
func _build_platforms() -> void:
	for i in Platforms.ALL.size():
		var id: String = Platforms.ALL[i]
		var pos := Vector3((i - 2) * PLATFORM_SPACING, 0, -8)
		var v := Platforms.create(id)
		v.position = pos
		v.rotation.y = deg_to_rad(-35)
		add_child(v)
		_label(id.capitalize(), pos + Vector3(0, 0.05, 4.2), 1.6)
		stops.append([id, pos + Vector3(0, 1.2, 0), 10.0])


func _label(text: String, pos: Vector3, size := 1.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.006 * size
	l.outline_size = 12
	l.modulate = Color.WHITE
	l.outline_modulate = Color("#2c3038")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)
