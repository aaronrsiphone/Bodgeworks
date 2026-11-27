extends Node3D
## A pyramid of crates to smash through. Change rows in the Inspector.

@export_range(1, 8) var rows := 4:
	set(value):
		rows = value
		if is_inside_tree():
			_build()

const CRATE := preload("res://world/crate.tscn")


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	for row in rows:
		var count := rows - row
		for i in count:
			var crate := CRATE.instantiate()
			crate.position = Vector3(i - (count - 1) / 2.0, 0.5 + row, 0) * 1.02
			add_child(crate)
