class_name Vehicle
extends RigidBody3D
## A vehicle built from a blueprint.
##
## "Compiling" a blueprint: every part becomes a collision box + mesh on this ONE
## rigid body. Mass, centre of mass and inertia are summed from the parts. Then
## every physics tick each part pushes on the body at its own position:
##   wheels     -> raycast suspension, drive, grip
##   propellers -> thrust
##   engines    -> a POWER budget that the wheels and propellers share
##   wings      -> lift and drag from the air flowing over them
##   everything -> buoyancy and drag when it is under water
## Parts wired to an accessory button (1/2/3) also do something when it's pressed:
##   springs    -> kick the ground or a crate
## Pushing at the part's position (not the middle) is what makes off-centre
## thrust turn you and heavy parts tip you.
##
## Fuel: engines burn fuel while you hold the throttle (more throttle = more fuel).
## When the fuel runs out, wheels and propellers stop pushing. A new vehicle
## (respawn, mission restart, back to the garage) always starts with a full tank.

const CELL := 1.0 # metres per grid cell
# Physics layers (named in Project Settings > Layer Names > 3D Physics).
const LAYER_WORLD := 1 # ground, ramps, walls
const LAYER_PROPS := 2 # crates and cargo
const LAYER_VEHICLES := 4
const GRAVITY := 9.8
const AIR_DRAG := 0.4
const WATER_DRAG_UP := 300.0 # strong: stops bobbing and bouncing out
const WATER_DRAG_FORWARD := 40.0 # weak: so propellers can push you along
const WATER_DRAG_SIDE := 200.0 # like a keel: you carve turns instead of sliding sideways
# Wings (per-wing numbers like area and stall angle live in data/parts.json).
const AIR_DENSITY := 10.0 # kg per m3. Real air is 1.2; ours is much thicker so heavy wooden planes can fly.
const WING_SLOPE := 5.0 # how fast lift grows as the nose tips up (per radian, about 0.09 per degree)
const WING_DRAG := 0.02 # drag of the wing slicing edge-on through the air
const WING_INDUCED := 0.05 # extra drag that comes with making lift (lift is never free)
const WING_STALLED := 0.8 # lift after a stall, like a flat board held in the wind

# Set these from outside (the player's controls).
var throttle := 0.0 # -1 reverse .. +1 forward
var steer := 0.0 # -1 right .. +1 left
var brake := false

var blueprint_name := ""
var parts: Array[Dictionary] = []
var wheels: Array[Dictionary] = []
var thrusters: Array[Dictionary] = []
var wings: Array[Dictionary] = []
var engine_force := 0.0 # the most push all engines together give at a standstill (N)
var engine_power := 0.0 # how much push they can keep up as you go faster (W = N x m/s)
var has_seat := false
var fuel := 0.0 # fuel left
var fuel_capacity := 0.0 # fuel when full
var fuel_use := 0.0 # fuel burned per second at full throttle (all engines together)
var has_tanks := false # false = running on the little reserve under the seat
## Accessory buttons: button number (1-3) -> the parts wired to it.
var buttons := {}

var _steer_angle := 0.0
var _spring := 0.0
var _damper := 0.0
var _reset_requested := false


## Builds the vehicle's parts from a blueprint dictionary (see data/blueprints).
func build(blueprint: Dictionary) -> void:
	blueprint_name = blueprint.get("name", "Vehicle")
	name = blueprint_name
	collision_layer = LAYER_VEHICLES
	collision_mask = LAYER_WORLD | LAYER_PROPS | LAYER_VEHICLES
	# Slippery body: things you push slide along it instead of dragging the nose up.
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.2

	var total_mass := 0.0
	var weighted := Vector3.ZERO
	for entry in blueprint.get("parts", []):
		var def := PartCatalog.get_part(entry.get("part", ""))
		if def.is_empty():
			continue
		var cell: Array = entry.get("pos", [0, 0, 0])
		var p := {
			"id": entry["part"],
			"def": def,
			"pos": Vector3(cell[0], cell[1], cell[2]) * CELL,
			"basis": PartCatalog.rot_basis(int(entry.get("rot", 0))),
			"button": int(entry.get("button", 0)), # 0 = not wired to a button
			"mass": float(def.get("mass", 10)),
			"buoyancy": float(def.get("buoyancy", 0)),
		}
		_add_boxes(p)
		parts.append(p)
		total_mass += p.mass
		weighted += (p.pos + p.middle) * p.mass

	if parts.is_empty():
		push_error("Blueprint '%s' has no parts" % blueprint_name)
		return

	# Mass properties: summed from the parts.
	var com := weighted / total_mass
	# Shift everything so the vehicle's origin sits under its centre of mass,
	# wherever it was built on the garage grid.
	var shift := Vector3(com.x, 0.0, com.z)
	for p in parts:
		p.pos -= shift
	com -= shift
	mass = total_mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = com
	# Inertia (how hard it is to spin): every box adds its own spin resistance,
	# plus more the further it is from the centre of mass.
	var inertia_sum := Vector3.ZERO
	for p in parts:
		for b in p.boxes:
			var m: float = p.mass * b.share
			var s: Vector3 = b.size
			var d: Vector3 = p.pos + b.offset - com
			inertia_sum += Vector3(
				m * (s.y * s.y + s.z * s.z) / 12.0 + m * (d.y * d.y + d.z * d.z),
				m * (s.x * s.x + s.z * s.z) / 12.0 + m * (d.x * d.x + d.z * d.z),
				m * (s.x * s.x + s.y * s.y) / 12.0 + m * (d.x * d.x + d.y * d.y))
	inertia = inertia_sum

	for p in parts:
		_add_part(p, com)

	var f := fuel_for(parts.map(func(p): return p.def))
	fuel_capacity = f.capacity
	fuel_use = f.use
	has_tanks = f.tanks > 0
	fuel = fuel_capacity

	# Self-tuning suspension: soft enough to soak up bumps, stiff enough to carry the weight.
	if not wheels.is_empty():
		var travel: float = wheels[0].travel
		var load_per_wheel := total_mass * GRAVITY / wheels.size()
		_spring = load_per_wheel / (travel * 0.45)
		_damper = 2.0 * 0.5 * sqrt(_spring * total_mass / wheels.size())

	if not has_seat:
		push_warning("'%s' has no seat, so nobody can drive it." % blueprint_name)
	if engine_power == 0.0:
		push_warning("'%s' has no engine, so wheels and propellers won't push." % blueprint_name)


## Works out the boxes a part is made of (from "shape" in parts.json), turned the
## way the part faces. Thin parts like plates are just smaller boxes. Stores:
##   p.boxes   [{size, offset, share}], share = the part of its mass in that box
##   p.middle  where its weight is, from the middle of its cell
##   p.height  how tall it is, for working out how much of it is under water
func _add_boxes(p: Dictionary) -> void:
	var boxes: Array[Dictionary] = []
	var volume := 0.0
	for b in PartCatalog.shape_boxes(p.def):
		var size: Vector3 = (p.basis * b.size).abs() * CELL # turned 90 degrees, x and z swap
		boxes.append({"size": size, "offset": p.basis * b.offset * CELL, "volume": size.x * size.y * size.z})
		volume += size.x * size.y * size.z
	var middle := Vector3.ZERO
	var low := INF
	var high := -INF
	for b in boxes:
		b.share = b.volume / volume # bigger boxes get more of the weight
		middle += b.offset * b.share
		low = minf(low, b.offset.y - b.size.y / 2.0)
		high = maxf(high, b.offset.y + b.size.y / 2.0)
	p.boxes = boxes
	p.middle = middle
	p.height = high - low


func _add_part(p: Dictionary, com: Vector3) -> void:
	var def: Dictionary = p.def
	if def.has("wheel"):
		var w: Dictionary = def.wheel
		var visual := PartVisuals.create(p.id, def)
		visual.position = p.pos
		add_child(visual)
		wheels.append({
			"pos": p.pos,
			"radius": float(w.radius),
			"travel": float(w.travel),
			"grip": float(w.get("grip", 1.0)),
			"steers": p.pos.z < com.z - 0.1, # wheels in front of the middle steer
			"visual": visual,
			"spin": 0.0,
			"grounded": false,
			"hit": {},
			"ray_from": Vector3.ZERO,
		})
		return # wheels touch the ground with rays, not collision boxes

	# One collision box per box in the part's shape (a whole cell if it has no shape).
	# A touch smaller than the real size so neighbouring parts don't overlap.
	for b in p.boxes:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = (b.size - Vector3.ONE * 0.02).max(Vector3.ONE * 0.02)
		shape.shape = box
		shape.position = p.pos + b.offset
		add_child(shape)

	var root := PartVisuals.create(p.id, def)
	root.position = p.pos
	root.basis = p.basis
	add_child(root)
	p["root"] = root
	var spinner := root.get_node_or_null("Spinner")
	if spinner:
		p["spinner"] = spinner

	if def.has("seat"):
		has_seat = true
	if def.has("engine"):
		engine_force += float(def.engine.force)
		engine_power += float(def.engine.get("power", 0))
	if def.has("thrust"):
		p["thrust"] = float(def.thrust.force)
		p["swivel"] = deg_to_rad(float(def.thrust.get("steer", 0)))
		p["air"] = float(def.thrust.get("air", 1.0))
		p["water"] = float(def.thrust.get("water", 1.0))
		p["grip"] = 0.0 # how well it can push right now, set every tick
		thrusters.append(p)
	if def.has("wing"):
		p["area"] = float(def.wing.get("area", 1.0))
		p["lift"] = float(def.wing.get("lift", 1.0))
		p["stall"] = deg_to_rad(float(def.wing.get("stall", 15)))
		p["camber"] = float(def.wing.get("camber", 0.0))
		wings.append(p)
	if def.has("spring"):
		p["cooldown_left"] = 0.0 # seconds until it can kick again
		p["kick_time"] = 99.0 # seconds since it last kicked (drives the animation)
	if p.button > 0 and PartCatalog.uses_button(def):
		if not buttons.has(p.button):
			buttons[p.button] = []
		buttons[p.button].append(p)


# --- accessory buttons -------------------------------------------------------
# main.gd calls press_button(n) when you press 1/2/3. Every part wired to that
# button gets activated in the next physics tick. To add a new kind of
# button part: add its behaviour name to PartCatalog.BUTTON_BEHAVIOURS and
# write an _activate_<name>(part) function below. That's all.

var _pressed: Array[int] = []


## Press accessory button n (1-3). Safe to call any time; the work happens in the physics tick.
func press_button(n: int) -> void:
	if buttons.has(n) and n not in _pressed:
		_pressed.append(n)


## What the buttons do, for the HUD: "1 Spring x2" and so on.
func button_summary() -> Array[String]:
	var out: Array[String] = []
	var keys := buttons.keys()
	keys.sort()
	for n in keys:
		var names := {}
		for p in buttons[n]:
			var part_name: String = p.def.get("name", p.id)
			names[part_name] = names.get(part_name, 0) + 1
		var bits: Array[String] = []
		for part_name in names:
			bits.append(part_name if names[part_name] == 1 else "%s x%d" % [part_name, names[part_name]])
		out.append("%d  %s" % [n, ", ".join(bits)])
	return out


func _run_buttons(delta: float) -> void:
	for n in _pressed:
		for p in buttons[n]:
			for behaviour in PartCatalog.BUTTON_BEHAVIOURS:
				if p.def.has(behaviour):
					call("_activate_" + behaviour, p)
	_pressed.clear()
	for p in parts:
		if p.def.has("spring"):
			_animate_spring(p, delta)


## Spring: shoot the foot out along the part's facing. If it hits the ground,
## the vehicle gets shoved the other way (point it down to jump). If it hits a
## crate, the crate gets kicked and the vehicle feels the kick back.
func _activate_spring(p: Dictionary) -> void:
	if p.cooldown_left > 0.0:
		return
	var s: Dictionary = p.def.spring
	p.cooldown_left = float(s.get("cooldown", 1.0))
	p.kick_time = 0.0
	var at := to_global(p.pos)
	var dir: Vector3 = global_basis * (p.basis * Vector3.FORWARD)
	# Look from the middle of the part to past its face, as far as the foot reaches.
	var query := PhysicsRayQueryParameters3D.create(at, at + dir * (CELL * 0.5 + float(s.get("reach", 1.0))))
	query.collision_mask = LAYER_WORLD | LAYER_PROPS | LAYER_VEHICLES
	query.exclude = [get_rid()] # don't kick ourselves
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return # kicked thin air: looks fun, does nothing
	var impulse := float(s.get("impulse", 4000))
	var other = hit.collider
	if other is RigidBody3D:
		# Equal and opposite, but a light crate can only fly so fast,
		# otherwise a 40 kg crate would leave at 100 m/s.
		impulse = minf(impulse, other.mass * float(s.get("kick_speed", 12)))
		other.apply_impulse(dir * impulse, hit.position - other.global_position)
	apply_impulse(-dir * impulse, at - global_position)


func _animate_spring(p: Dictionary, delta: float) -> void:
	p.cooldown_left = maxf(p.cooldown_left - delta, 0.0)
	p.kick_time += delta
	# Shoot out fast (0.08 s), then slowly pull back in (0.3 s).
	var out := 0.0
	if p.kick_time < 0.08:
		out = p.kick_time / 0.08
	elif p.kick_time < 0.38:
		out = 1.0 - (p.kick_time - 0.08) / 0.3
	var stretch: float = out * float(p.def.spring.get("reach", 1.0)) * 0.6
	var foot: Node3D = p.root.get_node_or_null("Foot")
	var coil: Node3D = p.root.get_node_or_null("Coil")
	if foot:
		foot.position.z = -0.38 - stretch
	if coil:
		coil.scale.z = 1.0 + stretch / 0.55


func _physics_process(delta: float) -> void:
	if parts.is_empty():
		return
	var up := global_basis.y
	var forward := -global_basis.z
	var com_global := to_global(center_of_mass)
	var speed := linear_velocity.dot(forward)
	var powered := engine_power > 0.0 and has_seat and fuel > 0.0
	if powered:
		# Burn fuel in proportion to how hard you press the throttle.
		fuel = maxf(fuel - fuel_use * absf(throttle) * delta, 0.0)

	# Steering: less lock at high speed so you don't flip instantly.
	var max_steer := deg_to_rad(32.0) / (1.0 + absf(speed) * 0.06)
	_steer_angle = move_toward(_steer_angle, steer * max_steer, delta * 2.5)

	# --- The power budget ---
	# Power = push x speed. So the faster you go, the less push the engines can
	# give, and at some speed that push only just beats drag: that's your top speed.
	# At low speed the push is capped at engine_force so you don't launch off.
	var drive_total := 0.0
	if powered and throttle != 0.0:
		# Pushing against the way you're moving (braking with reverse) gets full push.
		var going_with := absf(speed) if signf(throttle) == signf(speed) else 0.0
		drive_total = minf(engine_force, engine_power / maxf(going_with, 0.1)) * throttle

	# Every wheel on the ground and every propeller shares that one budget,
	# so ten propellers on one engine don't give ten times the push.
	# A propeller's share ("weight") is how well it can push right now:
	# its "water" number under water, its "air" number out of the water.
	# A water propeller is (air 0, water 1); an air propeller is the other way round.
	var weight_total := 0.0
	for w in wheels:
		w.grounded = _wheel_ray(w).size() > 0
		if w.grounded:
			weight_total += 1.0
	for t in thrusters:
		t.grip = lerpf(t.air, t.water, submerged_at(to_global(t.pos)))
		weight_total += t.grip
	var push_per_weight := drive_total / weight_total if weight_total > 0.0 else 0.0

	_apply_wheels(delta, up, com_global, push_per_weight)
	_run_buttons(delta)

	# Propellers push along their facing direction, at their position.
	# They swivel when you steer, like an outboard motor. One behind the middle
	# swivels the opposite way to one in front, so steering always turns the right way.
	for t in thrusters:
		var at := to_global(t.pos)
		# Its share of the power, but never more than the propeller itself can push
		# ("force" in parts.json), times how well it works where it is (air or water).
		var cap: float = t.thrust * t.grip
		var push: float = clampf(push_per_weight * t.grip, -cap, cap)
		var behind: bool = t.pos.z > center_of_mass.z
		var swivel: float = t.swivel * steer * (-1.0 if behind else 1.0)
		var aim: Basis = Basis(Vector3.UP, swivel) * t.basis
		t.root.basis = aim
		var dir: Vector3 = global_basis * (aim * Vector3.FORWARD)
		apply_force(dir * push, at - global_position)
		if t.has("spinner"):
			t.spinner.rotate_z(throttle * delta * 25.0 if powered else 0.0)

	_apply_wings(com_global)
	_apply_water(com_global)
	apply_central_force(-linear_velocity * linear_velocity.length() * AIR_DRAG)


## Casts the wheel's suspension ray. Returns the hit (empty if the wheel is in the air).
func _wheel_ray(w: Dictionary) -> Dictionary:
	var up := global_basis.y
	var from := to_global(w.pos) + up * 0.5 # start a bit high so we still hit after a hard landing
	var reach: float = 0.5 + w.radius + w.travel
	var query := PhysicsRayQueryParameters3D.create(from, from - up * reach)
	query.collision_mask = LAYER_WORLD # wheels ride on the ground, never on crates
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	w.hit = hit
	w.ray_from = from
	return hit


## drive_per_wheel: each grounded wheel's share of the engine push (N).
func _apply_wheels(delta: float, up: Vector3, com_global: Vector3, drive_per_wheel: float) -> void:
	if wheels.is_empty():
		return
	var mass_per_wheel := mass / wheels.size()

	for w in wheels:
		var hit: Dictionary = w.hit # cast at the start of this tick
		var from: Vector3 = w.ray_from
		var dist_from_mount: float = w.radius + w.travel
		if w.grounded:
			dist_from_mount = from.distance_to(hit.position) - 0.5
			var contact: Vector3 = hit.position
			var normal: Vector3 = hit.normal
			var point_vel := linear_velocity + angular_velocity.cross(contact - com_global)

			# Suspension spring + damper.
			var compression: float = w.radius + w.travel - dist_from_mount
			var load := maxf(_spring * compression - _damper * point_vel.dot(up), 0.0)
			apply_force(up * load, contact - global_position)

			# Tyre: drive forwards, grip sideways, limited by how hard it's pressed down.
			var fwd := (-global_basis.z).rotated(up, _steer_angle if w.steers else 0.0)
			fwd = (fwd - normal * fwd.dot(normal)).normalized()
			var right := fwd.cross(normal)
			var v_long := point_vel.dot(fwd)
			var v_side := point_vel.dot(right)

			var long_force := drive_per_wheel - v_long * 15.0 # rolling resistance
			if brake:
				long_force = -v_long * mass_per_wheel / delta * 0.5
			var side_force := -v_side * mass_per_wheel / delta * 0.6
			var tyre := fwd * long_force + right * side_force
			tyre = tyre.limit_length(load * w.grip)
			# Push at axle height, not the ground, so the car doesn't wheelie or tip so easily.
			var axle: Vector3 = contact + normal * w.radius
			apply_force(tyre, axle - global_position)

			w.spin -= v_long / w.radius * delta
		elif absf(throttle) > 0.0 and engine_power > 0.0 and has_seat:
			w.spin -= throttle * 20.0 * delta # spin in the air for fun

		# Wheel visuals follow the suspension, steering and rolling.
		var vis: Node3D = w.visual
		vis.position = w.pos - Vector3.UP * (dist_from_mount - w.radius)
		vis.basis = Basis(Vector3.UP, _steer_angle if w.steers else 0.0) * Basis(Vector3.RIGHT, w.spin)


## Wings: lift and drag from the air flowing over each wing, pushed at the wing's
## own position. So wings in front of the middle lift the nose, wings at the back
## (a tail) keep the nose pointing where you're going, like the feathers on a dart.
func _apply_wings(com_global: Vector3) -> void:
	for wg in wings:
		var at := to_global(wg.pos)
		# Air only: under water the wing just acts like any other part (water drag).
		var dry := 1.0 - submerged_at(at)
		# How fast this wing moves through the air. Spinning counts too, so a
		# wing far from the middle feels more wind when you roll or pitch.
		var vel := linear_velocity + angular_velocity.cross(at - com_global)
		var speed := vel.length()
		if dry <= 0.0 or speed < 0.5:
			continue
		var flow_dir := vel / speed # the way the wing moves (the air comes the other way)
		var normal: Vector3 = global_basis * (wg.basis * Vector3.UP) # wings lie flat: up is out of the wing
		# Angle of attack: how steeply the air hits the wing from below (+) or above (-).
		var alpha := asin(clampf(-flow_dir.dot(normal), -1.0, 1.0))
		var cl: float = _lift_coefficient(alpha, wg.stall, wg.camber) * wg.lift
		# A flat board pushed sideways through the air has lots of drag (sin^2 part).
		var cd: float = WING_DRAG + WING_INDUCED * cl * cl + sin(alpha) * sin(alpha)
		var q: float = 0.5 * AIR_DENSITY * speed * speed * wg.area * dry # "wind pressure" on this wing
		# Lift is at right angles to the airflow, on the wing's "up" side.
		var lift_dir := normal - flow_dir * normal.dot(flow_dir)
		var force: Vector3 = -flow_dir * q * cd
		if lift_dir.length_squared() > 1e-6:
			force += lift_dir.normalized() * q * cl
		apply_force(force, at - global_position)


## How much lift a wing makes at a given angle of attack (radians).
## Rises in a straight line, until the stall angle: there the air stops
## following the wing and most of the lift suddenly goes away.
## camber is the lift it makes when perfectly level (a curved wing lifts even when flat).
func _lift_coefficient(alpha: float, stall: float, camber: float) -> float:
	if absf(alpha) <= stall:
		return camber + WING_SLOPE * alpha
	return WING_STALLED * sin(2.0 * alpha)


## How much of a part this tall, centred at this point, is under water: 0 (dry) to 1 (fully under).
func submerged_at(point: Vector3, height := CELL) -> float:
	var most := 0.0
	for water in get_tree().get_nodes_in_group("water"):
		var depth: float = water.depth_at(point) # how far below the surface the point is
		most = maxf(most, clampf(depth / height + 0.5, 0.0, 1.0))
	return most


func _apply_water(com_global: Vector3) -> void:
	for p in parts:
		var at := to_global(p.pos + p.middle)
		var submerged := submerged_at(at, p.height)
		if submerged <= 0.0:
			continue
		var lift: float = p.buoyancy * GRAVITY * submerged
		var point_vel := linear_velocity + angular_velocity.cross(at - com_global)
		var v := global_basis.inverse() * point_vel # velocity in the vehicle's own directions
		var drag := global_basis * Vector3(v.x * WATER_DRAG_SIDE, v.y * WATER_DRAG_UP, v.z * WATER_DRAG_FORWARD)
		apply_force(Vector3.UP * lift - drag * submerged, at - global_position)


## Flip the vehicle upright where it is (press R).
func request_reset() -> void:
	_reset_requested = true


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _reset_requested:
		return
	_reset_requested = false
	var flat_fwd := -state.transform.basis.z
	flat_fwd.y = 0.0
	if flat_fwd.length() < 0.1:
		flat_fwd = Vector3.FORWARD
	var t := Transform3D(Basis.looking_at(flat_fwd.normalized(), Vector3.UP), state.transform.origin + Vector3.UP * 2.0)
	state.transform = t
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO


## Adds up the fuel numbers for a list of part definitions (from parts.json).
## Shared with the garage, so its "Fuel: N s" stat matches what really happens.
## Returns {capacity, use, tanks}.
static func fuel_for(defs: Array) -> Dictionary:
	var capacity := 0.0
	var reserve := 0.0
	var use := 0.0
	var tanks := 0
	for def in defs:
		if def.has("fuel"):
			capacity += float(def.fuel.get("capacity", 0))
			tanks += 1
		if def.has("seat"):
			reserve = maxf(reserve, float(def.seat.get("reserve_fuel", 0)))
		if def.has("engine"):
			use += float(def.engine.get("fuel_use", 0))
	if tanks == 0:
		capacity = reserve # no tank: you only get the little reserve can
	return {"capacity": capacity, "use": use, "tanks": tanks}


## How many seconds of full throttle the fuel lasts (INF if the engines burn nothing).
static func fuel_seconds(capacity: float, use: float) -> float:
	return INF if use <= 0.0 else capacity / use


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6
