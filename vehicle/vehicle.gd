class_name Vehicle
extends RigidBody3D
## A vehicle built from a blueprint.
##
## "Compiling" a blueprint: every part becomes a collision box + mesh on this ONE
## rigid body. Mass, centre of mass and inertia are summed from the parts. Then
## every physics tick each part pushes on the body at its own position:
##   wheels     -> raycast suspension, drive, grip
##   propellers -> thrust
##   everything -> buoyancy and drag when it is under water
## Pushing at the part's position (not the middle) is what makes off-centre
## thrust turn you and heavy parts tip you.

const CELL := 1.0 # metres per grid cell
const GRAVITY := 9.8
const AIR_DRAG := 0.4
const WATER_DRAG_UP := 300.0 # strong: stops bobbing and bouncing out
const WATER_DRAG_FLAT := 40.0 # weak: so propellers can push you along

# Set these from outside (the player's controls).
var throttle := 0.0 # -1 reverse .. +1 forward
var steer := 0.0 # -1 right .. +1 left
var brake := false

var blueprint_name := ""
var parts: Array[Dictionary] = []
var wheels: Array[Dictionary] = []
var thrusters: Array[Dictionary] = []
var engine_force := 0.0
var top_speed := 0.0
var has_seat := false

var _steer_angle := 0.0
var _spring := 0.0
var _damper := 0.0
var _reset_requested := false


## Builds the vehicle's parts from a blueprint dictionary (see data/blueprints).
func build(blueprint: Dictionary) -> void:
	blueprint_name = blueprint.get("name", "Vehicle")
	name = blueprint_name

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
			"basis": Basis(Vector3.UP, int(entry.get("rot", 0)) * PI / 2.0),
			"mass": float(def.get("mass", 10)),
			"buoyancy": float(def.get("buoyancy", 0)),
		}
		parts.append(p)
		total_mass += p.mass
		weighted += p.pos * p.mass

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
	var inertia_sum := Vector3.ZERO
	for p in parts:
		var d: Vector3 = p.pos - com
		var box: float = p.mass * (CELL * CELL) / 6.0 # solid cube
		inertia_sum += Vector3(
			box + p.mass * (d.y * d.y + d.z * d.z),
			box + p.mass * (d.x * d.x + d.z * d.z),
			box + p.mass * (d.x * d.x + d.y * d.y))
	inertia = inertia_sum

	for p in parts:
		_add_part(p, com)

	# Self-tuning suspension: soft enough to soak up bumps, stiff enough to carry the weight.
	if not wheels.is_empty():
		var travel: float = wheels[0].travel
		var load_per_wheel := total_mass * GRAVITY / wheels.size()
		_spring = load_per_wheel / (travel * 0.45)
		_damper = 2.0 * 0.5 * sqrt(_spring * total_mass / wheels.size())

	if not has_seat:
		push_warning("'%s' has no seat, so nobody can drive it." % blueprint_name)
	if engine_force == 0.0:
		push_warning("'%s' has no engine, so wheels and propellers won't push." % blueprint_name)


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
		})
		return # wheels touch the ground with rays, not collision boxes

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * CELL * 0.98
	shape.shape = box
	shape.position = p.pos
	add_child(shape)

	var root := PartVisuals.create(p.id, def)
	root.position = p.pos
	root.basis = p.basis
	add_child(root)
	var spinner := root.get_node_or_null("Spinner")
	if spinner:
		p["spinner"] = spinner

	if def.has("seat"):
		has_seat = true
	if def.has("engine"):
		engine_force += float(def.engine.force)
		top_speed = max(top_speed, float(def.engine.get("top_speed", 25)))
	if def.has("thrust"):
		p["thrust"] = float(def.thrust.force)
		thrusters.append(p)


func _physics_process(delta: float) -> void:
	if parts.is_empty():
		return
	var up := global_basis.y
	var forward := -global_basis.z
	var com_global := to_global(center_of_mass)
	var speed := linear_velocity.dot(forward)
	var powered := engine_force > 0.0 and has_seat

	# Engines give less push as you approach top speed.
	var taper := 1.0
	if powered and signf(throttle) == signf(speed):
		taper = clampf(1.0 - absf(speed) / top_speed, 0.0, 1.0)

	# Steering: less lock at high speed so you don't flip instantly.
	var max_steer := deg_to_rad(32.0) / (1.0 + absf(speed) * 0.06)
	_steer_angle = move_toward(_steer_angle, steer * max_steer, delta * 2.5)

	_apply_wheels(delta, up, com_global, taper if powered else 0.0)

	# Propellers push along their facing direction, at their position.
	for t in thrusters:
		var push: float = t.thrust * throttle * (taper if powered else 0.0)
		var dir: Vector3 = global_basis * (t.basis * Vector3.FORWARD)
		var at := to_global(t.pos)
		apply_force(dir * push, at - global_position)
		if t.has("spinner"):
			t.spinner.rotate_z(throttle * delta * 25.0 if powered else 0.0)

	_apply_water(com_global)
	apply_central_force(-linear_velocity * linear_velocity.length() * AIR_DRAG)


func _apply_wheels(delta: float, up: Vector3, com_global: Vector3, drive: float) -> void:
	if wheels.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var mass_per_wheel := mass / wheels.size()
	var drive_per_wheel := engine_force * throttle * drive / wheels.size()

	for w in wheels:
		var mount := to_global(w.pos)
		var from := mount + up * 0.5 # start a bit high so we still hit after a hard landing
		var reach: float = 0.5 + w.radius + w.travel
		var query := PhysicsRayQueryParameters3D.create(from, from - up * reach)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)

		var dist_from_mount: float = w.radius + w.travel
		w.grounded = not hit.is_empty()
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
		elif absf(throttle) > 0.0 and drive > 0.0:
			w.spin -= throttle * 20.0 * delta # spin in the air for fun

		# Wheel visuals follow the suspension, steering and rolling.
		var vis: Node3D = w.visual
		vis.position = w.pos - Vector3.UP * (dist_from_mount - w.radius)
		vis.basis = Basis(Vector3.UP, _steer_angle if w.steers else 0.0) * Basis(Vector3.RIGHT, w.spin)


func _apply_water(com_global: Vector3) -> void:
	for water in get_tree().get_nodes_in_group("water"):
		for p in parts:
			var at := to_global(p.pos)
			var depth: float = water.depth_at(at) # how far below the surface the part's middle is
			var submerged := clampf(depth / CELL + 0.5, 0.0, 1.0)
			if submerged <= 0.0:
				continue
			var lift: float = p.buoyancy * GRAVITY * submerged
			var point_vel := linear_velocity + angular_velocity.cross(at - com_global)
			var v_up := Vector3.UP * point_vel.y
			var drag := v_up * WATER_DRAG_UP + (point_vel - v_up) * WATER_DRAG_FLAT
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


func speed_kmh() -> float:
	return linear_velocity.length() * 3.6
