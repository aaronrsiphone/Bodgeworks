class_name ChaseCamera
extends Camera3D
## Follows behind the target, smoothly.

@export var target: Node3D
@export var distance := 9.0
@export var height := 3.5
@export var smoothing := 4.0

var _last_back := Vector3.BACK


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var t := target.get_global_transform_interpolated()
	# "Behind" ignores tilt, and keeps the last good direction if we're flipped over.
	var back := t.basis.z
	back.y = 0.0
	if back.length() > 0.3:
		_last_back = back.normalized()
	var focus := t.origin + Vector3.UP * 1.0
	var desired := focus + _last_back * distance + Vector3.UP * height
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))
	look_at(focus)


## Jump straight to the target (after spawning a new vehicle).
func snap() -> void:
	if target:
		global_position = target.global_position + target.global_basis.z * distance + Vector3.UP * height
		look_at(target.global_position + Vector3.UP)
