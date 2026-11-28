class_name Kit
## The Bodgeworks design kit: the look from docs/concept-art, built from code.
##
## The design language, in short:
##   - chunky, toy-like parts with soft rounded edges
##   - grey square "hardpoints" (a socket and four bolts) wherever parts join
##   - colour says what a part does (see the colours below)
##
## Every part here is a function that returns a Node3D, centred on its grid
## cell (1 cell = 1 m), facing forward along -Z with +Y up, like the game's parts.
## kit/platforms.gd snaps them together into whole vehicles.
## showcase/showcase.tscn shows them all (open it and press F6).

# --- Colours: what a part does -------------------------------------------------------
const YELLOW := Color("#f2b233") # structure: holds things together
const BLUE := Color("#2f78d0")   # air and water surfaces, propellers
const RED := Color("#d9432f")    # propulsion: engines, thrust
const GREY := Color("#7a828e")   # mechanisms: hardpoints, mounts, moving bits
# Helpers for details and trim.
const STEEL := Color("#a9b0ba")  # bolts, rims
const DARK := Color("#2c3038")   # holes, frames
const TYRE := Color("#2a2a2d")
const CREAM := Color("#efe6d2")  # stripes
const ORANGE := Color("#e8762b") # accents, fins, springs

static var _materials := {}
static var _box_meshes := {}


# --- Materials -----------------------------------------------------------------------

## A slightly shiny painted-plastic look in `color`. Shared, so many parts are cheap.
static func paint(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.55
		# Greys are metal: a bit shinier.
		if color.s < 0.15:
			m.metallic = 0.35
			m.roughness = 0.45
		_materials[key] = m
	return _materials[key]


## See-through blue glass for cockpits and portholes.
static func glass() -> StandardMaterial3D:
	if not _materials.has("glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.68, 0.86, 1.0, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic_specular = 1.0
		m.cull_mode = BaseMaterial3D.CULL_DISABLED # see the inside of the dome too
		_materials["glass"] = m
	return _materials["glass"]


## A warm glowing lens for lamps.
static func glow() -> StandardMaterial3D:
	if not _materials.has("glow"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#fff2c0")
		m.emission_enabled = true
		m.emission = Color("#ffd98a")
		m.emission_energy_multiplier = 2.5
		_materials["glow"] = m
	return _materials["glow"]


# --- Building blocks: put a mesh on a parent -----------------------------------------

## Adds `mesh` to `parent` with `material`, at `pos`, turned by `basis`.
static func add(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.transform = Transform3D(basis, pos)
	parent.add_child(mi)
	return mi


## A rounded box. Boxes of the same size share one mesh.
static func rbox(parent: Node3D, size: Vector3, color: Color, pos := Vector3.ZERO, radius := 0.06, basis := Basis.IDENTITY) -> MeshInstance3D:
	var key := "%s/%s" % [size, radius]
	if not _box_meshes.has(key):
		_box_meshes[key] = KitMesh.rounded_box(size, radius)
	return add(parent, _box_meshes[key], paint(color), pos, basis)


## A lathe shape (see KitMesh.lathe) whose axis points along `axis`.
static func turned(parent: Node3D, profile: PackedVector2Array, color: Color, pos := Vector3.ZERO, axis := Vector3.UP, segments := 24) -> MeshInstance3D:
	return add(parent, KitMesh.lathe(profile, segments), paint(color), pos, align_y(axis))


## A turn that points +Y along `dir`. Lathe shapes and Godot cylinders stand on Y,
## so this is how we lay them along any direction.
static func align_y(dir: Vector3) -> Basis:
	dir = dir.normalized()
	if dir.dot(Vector3.UP) > 0.9999:
		return Basis.IDENTITY
	if dir.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, dir))


## A new empty node to hold a part's pieces.
static func group(part_name: String, parent: Node3D = null, pos := Vector3.ZERO, basis := Basis.IDENTITY) -> Node3D:
	var n := Node3D.new()
	n.name = part_name
	n.transform = Transform3D(basis, pos)
	if parent:
		parent.add_child(n)
	return n


# --- Small details: these are what make it look like Bodgeworks ------------------------

## A six-sided steel bolt head sitting on a surface at `pos`, facing `normal`.
static func bolt(parent: Node3D, pos: Vector3, normal: Vector3, size := 0.035) -> void:
	var m := CylinderMesh.new()
	m.top_radius = size
	m.bottom_radius = size
	m.height = size * 1.2
	m.radial_segments = 6 # six sides: a hex bolt
	m.rings = 1
	add(parent, m, paint(STEEL), pos, align_y(normal))


## A round socket (a dark hole with a steel rim), where a peg could plug in.
static func socket(parent: Node3D, pos: Vector3, normal: Vector3, r := 0.09) -> void:
	var rim := TorusMesh.new()
	rim.inner_radius = r
	rim.outer_radius = r + 0.035
	rim.rings = 16
	rim.ring_segments = 6
	add(parent, rim, paint(STEEL), pos, align_y(normal))
	var hole := CylinderMesh.new()
	hole.top_radius = r
	hole.bottom_radius = r
	hole.height = 0.02
	hole.radial_segments = 16
	add(parent, hole, paint(DARK), pos + normal * 0.002, align_y(normal))


## The standard hardpoint: a grey square plate with a socket and four corner bolts.
## Put one wherever two parts join. `pos` is on the surface, `normal` points out of it.
static func hardpoint(parent: Node3D, pos: Vector3, normal: Vector3, size := 0.42) -> void:
	var b := align_y(normal)
	rbox(parent, Vector3(size, 0.06, size), GREY, pos + normal * 0.015, 0.025, b)
	socket(parent, pos + normal * 0.045, normal, size * 0.2)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var off := b.x * corner.x * size * 0.34 + b.z * corner.y * size * 0.34
		bolt(parent, pos + normal * 0.045 + off, normal, 0.025)


# --- Parts ---------------------------------------------------------------------------
# Each makes one part, centred on its cell. Sizes in metres.

## Yellow structure block with a hardpoint on every face.
static func block() -> Node3D:
	var n := group("Block")
	rbox(n, Vector3.ONE * 0.96, YELLOW, Vector3.ZERO, 0.1)
	for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		hardpoint(n, d * 0.48, d)
	return n


## A small grey connector cube with a socket on every face (joins beams together).
static func connector() -> Node3D:
	var n := group("Connector")
	rbox(n, Vector3.ONE * 0.5, GREY, Vector3.ZERO, 0.08)
	for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		socket(n, d * 0.25, d, 0.1)
	return n


## A yellow beam `cells` long (along X) with a hole in each cell and grey end caps.
static func beam(cells := 3, color := YELLOW) -> Node3D:
	var n := group("Beam")
	var length := float(cells)
	rbox(n, Vector3(length - 0.2, 0.42, 0.42), color, Vector3.ZERO, 0.07)
	for i in cells:
		var x := -length * 0.5 + 0.5 + i
		for d: Vector3 in [Vector3.UP, Vector3.FORWARD, Vector3.BACK]:
			socket(n, Vector3(x, 0, 0) + d * 0.21, d, 0.1)
	for s: float in [-1.0, 1.0]:
		rbox(n, Vector3(0.16, 0.48, 0.48), GREY, Vector3(s * (length * 0.5 - 0.1), 0, 0), 0.05)
		hardpoint(n, Vector3(s * length * 0.5, 0, 0), Vector3(s, 0, 0), 0.36)
	return n


## A light blue truss girder `cells` long (along X): two rails and zig-zag struts.
static func truss(cells := 3, color := BLUE) -> Node3D:
	var n := group("Truss")
	var length := float(cells)
	var h := 0.62
	for y: float in [-h * 0.5, h * 0.5]:
		rbox(n, Vector3(length - 0.1, 0.14, 0.16), color, Vector3(0, y, 0), 0.04)
	for s: float in [-1.0, 1.0]:
		rbox(n, Vector3(0.14, h + 0.14, 0.18), color, Vector3(s * (length * 0.5 - 0.12), 0, 0), 0.04)
		hardpoint(n, Vector3(s * length * 0.5 - s * 0.05, 0, 0), Vector3(s, 0, 0), 0.3)
	# Diagonals: one V per cell.
	var bays := cells * 2
	var step := (length - 0.24) / bays
	for i in bays:
		var x0 := -length * 0.5 + 0.12 + i * step
		var y0 := -h * 0.5 if i % 2 == 0 else h * 0.5
		var a := Vector3(x0, y0, 0)
		var b := Vector3(x0 + step, -y0, 0)
		var mid := (a + b) * 0.5
		var along := (b - a)
		rbox(n, Vector3(along.length() + 0.06, 0.09, 0.1), color, mid, 0.03, Basis(Vector3.BACK, atan2(along.y, along.x)))
	return n


## A grey floor plate `w` by `d` cells, with holes and yellow corner caps.
static func plate(w := 2, d := 2) -> Node3D:
	var n := group("Plate")
	rbox(n, Vector3(w - 0.04, 0.12, d - 0.04), GREY, Vector3.ZERO, 0.04)
	for i in w * 2:
		for j in d * 2:
			var p := Vector3(-w * 0.5 + 0.25 + i * 0.5, 0.06, -d * 0.5 + 0.25 + j * 0.5)
			var hole := CylinderMesh.new()
			hole.top_radius = 0.07
			hole.bottom_radius = 0.07
			hole.height = 0.01
			hole.radial_segments = 12
			add(n, hole, paint(DARK), p)
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			rbox(n, Vector3(0.26, 0.18, 0.26), YELLOW, Vector3(cx * (w * 0.5 - 0.13), 0.01, cz * (d * 0.5 - 0.13)), 0.05)
	return n


## A chunky wheel: knobbly tyre, yellow hub, bolts. Its axle runs along X.
static func wheel(radius := 0.5, width := 0.42) -> Node3D:
	var n := group("Wheel")
	var side := align_y(Vector3.RIGHT)
	var tread := 0.07
	var ro := radius - tread
	var ri := radius * 0.52
	add(n, KitMesh.lathe(KitMesh.ring_profile((ri + ro) * 0.5, ro - ri, width, 0.1), 32), paint(TYRE), Vector3.ZERO, side)
	# Knobbly tread blocks round the tyre, alternating left and right.
	var count := int(radius * 30)
	for i in count:
		var a := TAU * i / count
		var radial := Vector3(0, cos(a), sin(a))
		var x := width * 0.2 * (1 if i % 2 == 0 else -1)
		rbox(n, Vector3(width * 0.55, tread * 1.6, 0.13 * radius / 0.5), TYRE, Vector3(x, 0, 0) + radial * (ro + tread * 0.3), 0.03, Basis(Vector3.RIGHT, a))
	# Hub and centre cap.
	add(n, KitMesh.lathe(KitMesh.cylinder_profile(ri * 1.03, width * 0.8, 0.05), 24), paint(YELLOW), Vector3.ZERO, side)
	add(n, KitMesh.lathe(KitMesh.cylinder_profile(ri * 0.38, width * 0.95, 0.04), 16), paint(GREY), Vector3.ZERO, side)
	for s: float in [-1.0, 1.0]:
		for i in 5:
			var a := TAU * i / 5
			bolt(n, Vector3(s * width * 0.4, cos(a) * ri * 0.66, sin(a) * ri * 0.66), Vector3(s, 0, 0), 0.03)
	return n


## A yellow float (pontoon) `length` long along Z, with grey straps and mounts on top.
static func pontoon(length := 2.4, radius := 0.42) -> Node3D:
	var n := group("Pontoon")
	turned(n, KitMesh.cylinder_profile(radius, length, radius * 0.95, 8), YELLOW, Vector3.ZERO, Vector3.BACK, 28)
	for z: float in [-length * 0.25, length * 0.25]:
		turned(n, KitMesh.ring_profile(radius + 0.01, 0.06, 0.16, 0.025), GREY, Vector3(0, 0, z), Vector3.BACK, 28)
		rbox(n, Vector3(0.42, 0.14, 0.36), GREY, Vector3(0, radius + 0.03, z), 0.04)
		socket(n, Vector3(0, radius + 0.1, z), Vector3.UP, 0.08)
	return n


## A propeller that pushes along -Z: a hub and `blades` twisted blades.
## The blades are in a child called "Spinner" (the game and the showcase spin it
## round its Z axis, or round its "spin_axis" meta if it has one).
static func propeller(radius := 0.6, blades := 3, color := BLUE, hub_color := GREY) -> Node3D:
	var n := group("Propeller")
	var spinner := group("Spinner", n)
	# Pointed hub (spinner cone) facing forward.
	var hub := PackedVector2Array()
	var hr := maxf(0.1, radius * 0.17)
	for k in 9:
		var a := 0.5 * PI * k / 8
		hub.append(Vector2(hr * cos(a), -hr * 0.6 + hr * 1.5 * sin(a)))
	hub.insert(0, Vector2(0, -hr * 0.6))
	turned(spinner, hub, hub_color, Vector3.ZERO, Vector3.FORWARD, 20)
	# One blade, then copies turned round the hub.
	var foil := KitMesh.airfoil(1.0, 0.2, 0.04, 8)
	var sections := []
	var steps := 5
	for k in steps + 1:
		var t := float(k) / steps
		var r := lerpf(hr * 0.6, radius, t)
		var chord := lerpf(radius * 0.42, radius * 0.26, t) * (0.6 if k == steps else 1.0)
		var pitch := deg_to_rad(lerpf(55, 20, t)) # twisted: steep near the hub, flatter at the tip
		var cd := Vector3(0, cos(pitch), sin(pitch)) * chord
		var td := Vector3(0, -sin(pitch), cos(pitch)) * chord
		sections.append(Transform3D(Basis(cd, td, Vector3.RIGHT), Vector3(r, 0, 0)))
	var blade_mesh := KitMesh.loft(foil, sections)
	for i in blades:
		add(spinner, blade_mesh, paint(color), Vector3.ZERO, Basis(Vector3.BACK, TAU * i / blades))
	return n


## A ducted fan: a propeller inside a ring, with a mount on top.
static func ducted_fan(radius := 0.48, color := BLUE) -> Node3D:
	var n := group("DuctedFan")
	turned(n, KitMesh.ring_profile(radius + 0.06, 0.12, 0.5, 0.05), color, Vector3.ZERO, Vector3.BACK, 32)
	var prop := propeller(radius - 0.04, 5, color.lightened(0.15), GREY)
	n.add_child(prop)
	for s: float in [-1.0, 1.0]: # stator arms holding the hub
		rbox(n, Vector3(0.05, radius * 2, 0.06), GREY, Vector3(0, 0, 0.12), 0.02, Basis(Vector3.BACK, s * PI / 4))
	rbox(n, Vector3(0.36, 0.2, 0.36), GREY, Vector3(0, radius + 0.17, 0), 0.04)
	hardpoint(n, Vector3(0, radius + 0.27, 0), Vector3.UP, 0.32)
	return n


## A red engine block on a grey base, with cylinder heads, vents and exhaust pipes.
static func engine() -> Node3D:
	var n := group("Engine")
	rbox(n, Vector3(0.92, 0.16, 0.9), GREY, Vector3(0, -0.38, 0), 0.04)
	rbox(n, Vector3(0.7, 0.5, 0.78), RED, Vector3(0, -0.04, 0), 0.1)
	rbox(n, Vector3(0.56, 0.12, 0.62), RED.darkened(0.15), Vector3(0, 0.25, 0), 0.05)
	for s: float in [-1.0, 1.0]:
		rbox(n, Vector3(0.14, 0.34, 0.66), GREY, Vector3(s * 0.4, 0.0, 0), 0.04)
		for z: float in [-0.22, 0.0, 0.22]:
			bolt(n, Vector3(s * 0.47, 0.08, z), Vector3(s, 0, 0), 0.03)
	for i in 3: # vents on the front
		rbox(n, Vector3(0.5, 0.05, 0.04), DARK, Vector3(0, -0.15 + i * 0.1, -0.39), 0.015)
	for x: float in [-0.14, 0.14]: # exhaust pipes out of the top at the back
		turned(n, KitMesh.cylinder_profile(0.06, 0.36, 0.02), STEEL, Vector3(x, 0.4, 0.28))
		turned(n, KitMesh.ring_profile(0.06, 0.03, 0.05, 0.01), DARK, Vector3(x, 0.58, 0.28))
	return n


## A wing reaching `span` metres along +X (or -X with side = -1). Its chord (front
## to back) shrinks from `root_chord` to `tip_chord`, and `sweep` slides the tip back
## (metres per metre of span). `stripes` colours it in bands from root to tip.
static func wing(span := 3.0, root_chord := 1.0, tip_chord := 0.7, sweep := 0.0, stripes: Array = [YELLOW, CREAM, YELLOW, CREAM, YELLOW], side := 1.0, thickness := 0.14, camber := 0.03) -> Node3D:
	var n := group("Wing")
	var foil := KitMesh.airfoil(1.0, thickness, camber)
	var bands := stripes.size()
	for b in bands:
		var sections := []
		for k in 2:
			var t := float(b + k) / bands
			var chord := lerpf(root_chord, tip_chord, t)
			var x := span * t
			sections.append(Transform3D(Basis(Vector3(0, 0, chord), Vector3(0, chord, 0), Vector3(side, 0, 0)), Vector3(side * x, 0, sweep * x)))
		add(n, KitMesh.loft(foil, sections), paint(stripes[b]))
	# Grey root block where it bolts on.
	var root_h := root_chord * thickness * 1.5
	rbox(n, Vector3(0.24, root_h, root_chord * 0.8), GREY, Vector3(side * 0.08, 0.0, 0), 0.03)
	socket(n, Vector3(side * -0.04, 0, -root_chord * 0.15), Vector3(-side, 0, 0), minf(0.07, root_h * 0.35))
	socket(n, Vector3(side * -0.04, 0, root_chord * 0.15), Vector3(-side, 0, 0), minf(0.07, root_h * 0.35))
	return n


## An upright tail fin (a symmetric wing standing on +Y).
static func fin(height := 1.0, root_chord := 0.9, tip_chord := 0.5, sweep := 0.4, stripes: Array = [RED, CREAM, RED]) -> Node3D:
	var n := group("Fin")
	var w := wing(height, root_chord, tip_chord, sweep, stripes, 1.0, 0.12, 0.0)
	w.transform.basis = Basis(Vector3.BACK, PI / 2) # turn the span from +X to +Y
	n.add_child(w)
	return n


## A tank (fuel, air or ballast) lying along X, with yellow bands and a valve on top.
static func tank(length := 1.6, radius := 0.4, color := BLUE.darkened(0.2)) -> Node3D:
	var n := group("Tank")
	turned(n, KitMesh.cylinder_profile(radius, length, radius * 0.7, 6), color, Vector3.ZERO, Vector3.RIGHT, 28)
	for x: float in [-length * 0.3, length * 0.3]:
		turned(n, KitMesh.ring_profile(radius + 0.005, 0.05, 0.14, 0.02), YELLOW, Vector3(x, 0, 0), Vector3.RIGHT, 28)
	turned(n, KitMesh.cylinder_profile(0.06, 0.22, 0.02), STEEL, Vector3(0, radius + 0.06, 0))
	turned(n, KitMesh.cylinder_profile(0.12, 0.06, 0.02), RED, Vector3(0, radius + 0.18, 0))
	return n


## The driver's seat: red cushions on a dark frame.
static func seat() -> Node3D:
	var n := group("Seat")
	rbox(n, Vector3(0.82, 0.14, 0.82), DARK, Vector3(0, -0.4, 0), 0.04)
	rbox(n, Vector3(0.7, 0.2, 0.68), RED, Vector3(0, -0.24, -0.02), 0.08)
	rbox(n, Vector3(0.7, 0.72, 0.18), RED, Vector3(0, 0.12, 0.32), 0.08, Basis(Vector3.RIGHT, -0.12))
	rbox(n, Vector3(0.42, 0.2, 0.15), RED, Vector3(0, 0.6, 0.36), 0.06)
	for s: float in [-1.0, 1.0]:
		rbox(n, Vector3(0.12, 0.3, 0.7), DARK, Vector3(s * 0.38, -0.2, 0.0), 0.04)
	return n


## A glass dome (cockpit canopy) with a grey rim, opening downwards.
static func dome(radius := 0.6) -> Node3D:
	var n := group("Dome")
	var p := PackedVector2Array()
	for k in 13:
		var a := 0.5 * PI * k / 12
		p.append(Vector2(radius * cos(a), radius * sin(a)))
	add(n, KitMesh.lathe(p, 32), glass())
	turned(n, KitMesh.ring_profile(radius, 0.08, 0.08, 0.03), GREY, Vector3.ZERO, Vector3.UP, 32)
	return n


## A round porthole window, facing `normal`.
static func porthole(radius := 0.2, normal := Vector3.BACK) -> Node3D:
	var n := group("Porthole")
	turned(n, KitMesh.ring_profile(radius, 0.08, 0.07, 0.025), STEEL, Vector3.ZERO, normal, 24)
	var disc := CylinderMesh.new()
	disc.top_radius = radius - 0.03
	disc.bottom_radius = radius - 0.03
	disc.height = 0.02
	add(n, disc, glass(), Vector3.ZERO, align_y(normal))
	return n


## A lamp: grey housing with a glowing lens, shining along -Z.
static func lamp(radius := 0.14) -> Node3D:
	var n := group("Lamp")
	turned(n, KitMesh.cylinder_profile(radius, radius * 1.4, radius * 0.3), GREY, Vector3(0, 0, radius * 0.2), Vector3.FORWARD, 16)
	var lens := SphereMesh.new()
	lens.radius = radius * 0.82
	lens.height = radius * 0.7
	add(n, lens, glow(), Vector3(0, 0, -radius * 0.5))
	return n
