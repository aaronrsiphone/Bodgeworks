class_name GarageCamera
extends Camera3D
## Orbits around a point. Right-drag to turn, scroll to zoom, middle-drag to slide.
## Arrow keys / Q E also turn, for when there's no mouse.

@export var focus := Vector3(0.5, 0.5, 1.0)
@export var distance := 12.0
@export var yaw := deg_to_rad(-35.0)
@export var pitch := deg_to_rad(-30.0)

var dragging := false
var _pan := false


func _ready() -> void:
	_apply()


func _process(delta: float) -> void:
	var turn := Input.get_axis("ui_left", "ui_right")
	var tilt := Input.get_axis("ui_down", "ui_up")
	if Input.is_key_pressed(KEY_Q): turn -= 1.0
	if Input.is_key_pressed(KEY_E): turn += 1.0
	if turn != 0.0 or tilt != 0.0:
		yaw -= turn * delta * 2.0
		pitch = clampf(pitch + tilt * delta * 1.5, deg_to_rad(-85), deg_to_rad(-5))
		_apply()


## Returns true if it used the event.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(distance * 0.9, 3.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(distance * 1.1, 40.0)
			MOUSE_BUTTON_MIDDLE:
				_pan = event.pressed
			_:
				return false
		_apply()
		return true
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and event.relative.length() > 0.0:
			dragging = true
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch - event.relative.y * 0.008, deg_to_rad(-85), deg_to_rad(-5))
			_apply()
			return true
		if _pan:
			var right := global_basis.x
			var fwd := Vector3(global_basis.z.x, 0, global_basis.z.z).normalized()
			focus += (-right * event.relative.x + -fwd * event.relative.y) * distance * 0.002
			_apply()
			return true
	return false


func _apply() -> void:
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	global_position = focus + dir * distance
	look_at(focus)
