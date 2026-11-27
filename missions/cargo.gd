extends RigidBody3D
## A crate you deliver. It's wooden, so it floats.

@export var size := 1.2
@export var buoyancy := 130.0 # kg it can hold up under water (more than its mass = floats)


func _physics_process(_delta: float) -> void:
	for water in get_tree().get_nodes_in_group("water"):
		var depth: float = water.depth_at(global_position)
		var submerged := clampf(depth / size + 0.5, 0.0, 1.0)
		if submerged <= 0.0:
			continue
		apply_central_force(Vector3.UP * buoyancy * 9.8 * submerged - linear_velocity * 60.0 * submerged)
		apply_torque(-angular_velocity * 40.0 * submerged)
