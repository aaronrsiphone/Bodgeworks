@tool
class_name Water
extends Node3D
## A rectangle of water. Put this node AT the water surface; size is the
## width (x) and length (z) of the pond. Vehicles float on anything inside it.

@export var size := Vector2(30, 40):
	set(value):
		size = value
		_update_mesh()

var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("water")
	_update_mesh()


## How far below the surface a point is (negative = above), or -INF if outside the pond.
func depth_at(point: Vector3) -> float:
	var local := to_local(point)
	if absf(local.x) > size.x / 2.0 or absf(local.z) > size.y / 2.0:
		return -INF
	return -local.y


func _update_mesh() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.45, 0.8, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.1
		mat.metallic_specular = 0.8
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mesh.material_override = mat
	var plane := PlaneMesh.new()
	plane.size = size
	_mesh.mesh = plane
