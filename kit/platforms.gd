class_name Platforms
## Starter vehicle platforms, snapped together from the design kit (kit/kit.gd).
## Each one is a base to build on: a land rover, a submarine, a plane, a
## helicopter and a boat. They face forward along -Z, wheels/keel on y = 0.
##
## These are looks only for now (no physics). To make one drivable it needs a
## matching blueprint in data/blueprints/.

const ALL := ["rover", "submarine", "plane", "helicopter", "boat"]


## Builds a platform by name (one of ALL).
static func create(id: String) -> Node3D:
	match id:
		"rover": return rover()
		"submarine": return submarine()
		"plane": return plane()
		"helicopter": return helicopter()
		"boat": return boat()
	push_error("no platform called " + id)
	return Node3D.new()


## Puts `part` on `parent` at `pos`, turned by `basis`. Returns the part.
static func place(parent: Node3D, part: Node3D, pos := Vector3.ZERO, basis := Basis.IDENTITY) -> Node3D:
	part.transform = Transform3D(basis, pos)
	parent.add_child(part)
	return part


## A yaw turn: degrees round the up axis.
static func yaw(degrees: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(degrees))


## Land rover: a plate floor on two beams, four big wheels, seat, engine, roll bar.
static func rover() -> Node3D:
	var v := Kit.group("Rover")
	var axle_y := 0.55
	place(v, Kit.plate(2, 4), Vector3(0, axle_y + 0.12, 0))
	for x: float in [-1.0, 1.0]:
		place(v, Kit.beam(4), Vector3(x * 1.2, axle_y, 0), yaw(90))
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.4, 1.4]:
			place(v, Kit.wheel(0.55, 0.44), Vector3(x * 1.72, axle_y, z))
			Kit.rbox(v, Vector3(0.22, 0.18, 0.18), Kit.GREY, Vector3(x * 1.47, axle_y, z), 0.04) # axle stub
	place(v, Kit.seat(), Vector3(0, axle_y + 0.68, 0.15))
	place(v, Kit.engine(), Vector3(0, axle_y + 0.68, 1.45))
	# Roll bar: grey square tubes behind the seat.
	for x: float in [-1.0, 1.0]:
		Kit.rbox(v, Vector3(0.12, 1.3, 0.12), Kit.GREY, Vector3(x * 0.8, axle_y + 0.85, 0.7), 0.03)
		Kit.rbox(v, Vector3(0.12, 0.12, 0.9), Kit.GREY, Vector3(x * 0.8, axle_y + 1.32, 0.3), 0.03, Basis(Vector3.RIGHT, -0.55))
	Kit.rbox(v, Vector3(1.72, 0.12, 0.12), Kit.GREY, Vector3(0, axle_y + 1.5, 0.7), 0.03)
	# Steering wheel.
	var wheel_ring := TorusMesh.new()
	wheel_ring.inner_radius = 0.17
	wheel_ring.outer_radius = 0.22
	Kit.add(v, wheel_ring, Kit.paint(Kit.DARK), Vector3(0, axle_y + 0.95, -0.42), Basis(Vector3.RIGHT, deg_to_rad(60)))
	Kit.rbox(v, Vector3(0.08, 0.08, 0.4), Kit.GREY, Vector3(0, axle_y + 0.78, -0.55), 0.02, Basis(Vector3.RIGHT, deg_to_rad(-30)))
	# Front bumper with hazard stripes, and two headlights.
	Kit.rbox(v, Vector3(2.2, 0.32, 0.22), Kit.DARK, Vector3(0, axle_y, -2.15), 0.06)
	for i in 7:
		Kit.rbox(v, Vector3(0.16, 0.3, 0.06), Kit.YELLOW, Vector3(-0.9 + i * 0.3, axle_y, -2.27), 0.02, Basis(Vector3.BACK, 0.5))
	for x: float in [-0.6, 0.6]:
		place(v, Kit.lamp(0.13), Vector3(x, axle_y + 0.35, -2.0))
	return v


## Submarine: a yellow hull with a glass nose dome, conning tower and periscope,
## portholes, tail fins and a ducted propeller.
static func submarine() -> Node3D:
	var v := Kit.group("Submarine")
	var y := 1.05 # hull centre height
	var r := 0.95
	# Hull outline, spun round its length: thin tail, fat middle, round nose.
	var hull := PackedVector2Array([Vector2(0, -2.55), Vector2(0.32, -2.55)])
	for k in 9:
		var t := float(k) / 8
		hull.append(Vector2(0.4 + (r - 0.4) * (0.5 - 0.5 * cos(PI * t)), lerpf(-2.45, -1.0, t)))
	for k in 13:
		var a := 0.5 * PI * k / 12
		hull.append(Vector2(r * cos(a), 1.3 + 1.15 * sin(a)))
	Kit.turned(v, hull, Kit.YELLOW, Vector3(0, y, 0), Vector3.FORWARD, 36)
	# Orange bands.
	for z: float in [-0.07, 0.78]: # between the portholes
		Kit.turned(v, KitMesh.ring_profile(r + 0.005, 0.05, 0.22, 0.02), Kit.ORANGE, Vector3(0, y, z), Vector3.FORWARD, 36)
	# Glass bubble over the cockpit, near the nose.
	place(v, Kit.dome(0.62), Vector3(0, y + 0.6, -1.25), Basis(Vector3.RIGHT, deg_to_rad(-25)))
	# Conning tower with a lamp and periscope.
	Kit.rbox(v, Vector3(0.8, 0.75, 1.2), Kit.YELLOW, Vector3(0, y + 1.05, 0.55), 0.18)
	Kit.rbox(v, Vector3(0.86, 0.12, 1.26), Kit.GREY, Vector3(0, y + 1.42, 0.55), 0.04)
	place(v, Kit.lamp(0.13), Vector3(0, y + 1.05, -0.08))
	for s: float in [-1.0, 1.0]:
		Kit.hardpoint(v, Vector3(s * 0.4, y + 1.05, 0.55), Vector3(s, 0, 0), 0.3)
	Kit.turned(v, KitMesh.cylinder_profile(0.07, 0.8, 0.02), Kit.GREY, Vector3(0.2, y + 1.85, 0.85))
	Kit.turned(v, KitMesh.cylinder_profile(0.07, 0.35, 0.02), Kit.GREY, Vector3(0.2, y + 2.22, 0.72), Vector3.FORWARD)
	place(v, Kit.porthole(0.07, Vector3.FORWARD), Vector3(0.2, y + 2.22, 0.54))
	# Portholes along both sides.
	for s: float in [-1.0, 1.0]:
		for z: float in [-0.5, 0.35, 1.2]:
			var n := Vector3(s, 0, 0)
			place(v, Kit.porthole(0.2, n), Vector3(s * (r - 0.02), y + 0.05, z))
	# Tail fins: up, down and both sides, all orange.
	for i in 4:
		var turn := Basis(Vector3.BACK, i * PI / 2)
		var f := Kit.fin(0.9, 1.0, 0.55, 0.45, [Kit.ORANGE, Kit.ORANGE.lightened(0.25), Kit.ORANGE])
		place(v, f, Vector3(0, y, 1.85) + turn * Vector3(0, 0.35, 0), turn)
	# Ducted propeller behind the tail.
	place(v, _bare_fan(0.55), Vector3(0, y, 2.9))
	# Headlights on the nose, and a grey keel to sit on.
	for x: float in [-0.42, 0.42]:
		place(v, Kit.lamp(0.14), Vector3(x, y - 0.4, -2.0))
	Kit.rbox(v, Vector3(0.36, 0.22, 2.6), Kit.GREY, Vector3(0, y - r + 0.02, 0.0), 0.06)
	for z: float in [-0.8, 0.0, 0.8]:
		Kit.hardpoint(v, Vector3(0.18, y - r + 0.02, z), Vector3.RIGHT, 0.18)
	return v


## A ducted fan without its top mount (for the submarine's tail).
static func _bare_fan(radius: float) -> Node3D:
	var n := Kit.group("DuctedFan")
	Kit.turned(n, KitMesh.ring_profile(radius + 0.06, 0.12, 0.45, 0.05), Kit.ORANGE, Vector3.ZERO, Vector3.BACK, 32)
	n.add_child(Kit.propeller(radius - 0.04, 5, Kit.GREY, Kit.ORANGE))
	for s: float in [-1.0, 1.0]:
		Kit.rbox(n, Vector3(0.05, radius * 2, 0.06), Kit.GREY, Vector3(0, 0, 0.1), 0.02, Basis(Vector3.BACK, s * PI / 4))
	return n


## Plane: a yellow fuselage, striped wings with red tips, a blue tailplane, a red
## fin, a red engine and propeller at the nose, and three wheels.
static func plane() -> Node3D:
	var v := Kit.group("Plane")
	var y := 1.15
	# Fuselage: a rounded square swept front to back, getting thinner at the tail.
	var body := KitMesh.rounded_rect(1.0, 1.0, 0.38, 4)
	var slices := [ # [z, width, height, lift]
		[-1.8, 0.95, 0.95, 0.0], [-1.0, 1.15, 1.2, 0.05], [0.6, 1.05, 1.1, 0.05],
		[2.4, 0.5, 0.6, 0.25], [3.1, 0.32, 0.4, 0.3],
	]
	var sections := []
	for s: Array in slices:
		sections.append(Transform3D(Basis(Vector3(s[1], 0, 0), Vector3(0, s[2], 0), Vector3.BACK), Vector3(0, y + s[3], s[0])))
	Kit.add(v, KitMesh.loft(body, sections), Kit.paint(Kit.YELLOW))
	# Red engine cowling and propeller.
	Kit.turned(v, KitMesh.cylinder_profile(0.5, 0.5, 0.15), Kit.RED, Vector3(0, y, -2.0), Vector3.FORWARD, 28)
	for i in 6:
		var a := TAU * i / 6
		Kit.bolt(v, Vector3(cos(a) * 0.38, y + sin(a) * 0.38, -2.26), Vector3.FORWARD, 0.03)
	place(v, Kit.propeller(1.0, 3, Kit.DARK, Kit.RED), Vector3(0, y, -2.35))
	# Cockpit canopy.
	var canopy := place(v, Kit.dome(0.48), Vector3(0, y + 0.55, -0.45))
	canopy.scale = Vector3(1.0, 0.9, 1.7)
	# Wings, low on the body, red tips.
	var wing_bands := [Kit.YELLOW, Kit.CREAM, Kit.YELLOW, Kit.CREAM, Kit.YELLOW, Kit.RED]
	for s: float in [-1.0, 1.0]:
		place(v, Kit.wing(3.5, 1.25, 0.8, 0.05, wing_bands, s), Vector3(s * 0.45, y - 0.3, -0.7))
	# Tail: blue tailplane both sides, red fin on top.
	for s: float in [-1.0, 1.0]:
		place(v, Kit.wing(1.3, 0.75, 0.45, 0.25, [Kit.BLUE, Kit.CREAM, Kit.BLUE], s, 0.12, 0.0), Vector3(s * 0.12, y + 0.3, 2.65))
	place(v, Kit.fin(1.1, 0.85, 0.45, 0.6), Vector3(0, y + 0.35, 2.6))
	# Landing gear: two main wheels under the wings, one small at the tail.
	for s: float in [-1.0, 1.0]:
		Kit.rbox(v, Vector3(0.1, 0.65, 0.14), Kit.GREY, Vector3(s * 0.95, y - 0.72, -0.7), 0.03, Basis(Vector3.BACK, s * 0.25))
		place(v, Kit.wheel(0.36, 0.26), Vector3(s * 1.1, 0.36, -0.7))
	Kit.rbox(v, Vector3(0.08, 1.0, 0.1), Kit.GREY, Vector3(0, 0.75, 2.8), 0.02, Basis(Vector3.RIGHT, 0.15))
	place(v, Kit.wheel(0.16, 0.12), Vector3(0, 0.18, 2.85))
	return v


## Helicopter: an orange cabin with a glass bubble front, truss tail boom, tail
## rotor, main rotor and grey skids.
static func helicopter() -> Node3D:
	var v := Kit.group("Helicopter")
	var y := 1.35
	var body := KitMesh.rounded_rect(1.0, 1.0, 0.4, 4)
	var slices := [ # [z, width, height, lift]
		[-0.8, 1.3, 1.25, -0.05], [0.9, 1.45, 1.4, 0.0], [1.5, 0.9, 0.85, 0.2],
	]
	var sections := []
	for s: Array in slices:
		sections.append(Transform3D(Basis(Vector3(s[1], 0, 0), Vector3(0, s[2], 0), Vector3.BACK), Vector3(0, y + s[3], s[0])))
	Kit.add(v, KitMesh.loft(body, sections), Kit.paint(Kit.ORANGE))
	# Cream stripe round the middle, and a bubble nose.
	Kit.rbox(v, Vector3(1.47, 0.2, 1.4), Kit.CREAM, Vector3(0, y - 0.1, 0.15), 0.05)
	var bubble := place(v, Kit.dome(0.68), Vector3(0, y - 0.02, -0.8), Kit.align_y(Vector3.FORWARD))
	bubble.scale = Vector3(1.0, 1.15, 0.95)
	for x: float in [-0.42, 0.42]:
		place(v, Kit.lamp(0.11), Vector3(x, y - 0.55, -1.05))
	# Engine housing and rotor mast on top.
	Kit.rbox(v, Vector3(0.9, 0.4, 1.2), Kit.GREY, Vector3(0, y + 0.85, 0.5), 0.1)
	Kit.turned(v, KitMesh.cylinder_profile(0.12, 0.5, 0.03), Kit.DARK, Vector3(0, y + 1.25, 0.35))
	var rotor := Kit.group("Spinner", v, Vector3(0, y + 1.52, 0.35))
	rotor.set_meta("spin_axis", Vector3.UP) # a rotor spins flat, not like a propeller
	Kit.rbox(rotor, Vector3(0.5, 0.16, 0.5), Kit.GREY, Vector3.ZERO, 0.05)
	Kit.rbox(rotor, Vector3(0.22, 0.1, 0.22), Kit.YELLOW, Vector3(0, 0.12, 0), 0.03)
	for s: float in [-1.0, 1.0]:
		Kit.rbox(rotor, Vector3(2.3, 0.06, 0.3), Kit.GREY, Vector3(s * 1.35, 0, 0), 0.025)
		Kit.rbox(rotor, Vector3(0.45, 0.07, 0.31), Kit.YELLOW, Vector3(s * 2.3, 0, 0), 0.025)
	# Tail boom: an orange truss reaching back, with a fin and a tail rotor.
	var boom := Kit.truss(3, Kit.ORANGE)
	place(v, boom, Vector3(0, y + 0.25, 3.0), yaw(90))
	boom.scale = Vector3(1.0, 0.7, 0.8)
	place(v, Kit.fin(0.9, 0.7, 0.4, 0.5, [Kit.ORANGE, Kit.CREAM, Kit.ORANGE]), Vector3(0, y + 0.45, 4.25))
	place(v, Kit.propeller(0.5, 2, Kit.GREY, Kit.YELLOW), Vector3(0.22, y + 0.8, 4.45), yaw(90))
	# Skids: two grey tubes with yellow legs.
	for s: float in [-1.0, 1.0]:
		Kit.rbox(v, Vector3(0.12, 0.12, 2.6), Kit.GREY, Vector3(s * 0.85, 0.08, 0.2), 0.05)
		Kit.rbox(v, Vector3(0.12, 0.12, 0.4), Kit.GREY, Vector3(s * 0.85, 0.2, -1.22), 0.05, Basis(Vector3.RIGHT, 0.6))
		for z: float in [-0.45, 0.85]:
			Kit.rbox(v, Vector3(0.12, 0.85, 0.14), Kit.YELLOW, Vector3(s * 0.75, 0.5, z), 0.04, Basis(Vector3.BACK, s * 0.3))
	return v


## Boat: a catamaran with two floats, a deck, a seat, an engine, and a water
## propeller under the back.
static func boat() -> Node3D:
	var v := Kit.group("Boat")
	var y := 0.45
	for x: float in [-1.0, 1.0]:
		place(v, Kit.pontoon(3.4, 0.45), Vector3(x * 1.05, y, 0))
	place(v, Kit.plate(3, 3), Vector3(0, y + 0.62, 0))
	for x: float in [-1.0, 1.0]:
		place(v, Kit.beam(3), Vector3(x * 1.05, y + 0.47, 0), yaw(90)).scale = Vector3(1.0, 0.6, 0.8)
	place(v, Kit.seat(), Vector3(0, y + 1.2, 0.2))
	place(v, Kit.engine(), Vector3(0, y + 1.2, 1.1))
	# Outboard leg reaching down to a blue water propeller.
	Kit.rbox(v, Vector3(0.22, 1.0, 0.22), Kit.GREY, Vector3(0, y + 0.3, 1.75), 0.05)
	place(v, Kit.propeller(0.36, 3, Kit.BLUE), Vector3(0, y - 0.15, 1.95), yaw(180))
	# Front rail and a lamp.
	for x: float in [-0.9, 0.0, 0.9]:
		Kit.rbox(v, Vector3(0.08, 0.5, 0.08), Kit.GREY, Vector3(x, y + 0.92, -1.35), 0.02)
	Kit.rbox(v, Vector3(1.9, 0.08, 0.08), Kit.GREY, Vector3(0, y + 1.17, -1.35), 0.02)
	place(v, Kit.lamp(0.13), Vector3(0, y + 0.85, -1.5))
	return v
