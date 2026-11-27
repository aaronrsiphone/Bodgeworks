class_name DeliveryMission
extends Node3D
## Get the cargo into the goal zone as fast as you can.
## Added to the test map by world/main.gd when you start a mission from the garage.
##
## Needs children: Start (Marker3D, where the vehicle appears), Cargo (RigidBody3D),
## Goal (Area3D). Move them around in the editor to make a new delivery mission.

@export var mission_id := "special_delivery"
@export var title := "Special Delivery"
@export_multiline var instructions := "Get the crate into the green zone!"
@export var gold_time := 15.0
@export var silver_time := 25.0
@export var bronze_time := 60.0

@onready var start: Marker3D = $Start
@onready var cargo: RigidBody3D = $Cargo
@onready var goal: Area3D = $Goal

var main: Node # the test map (world/main.gd), set when the mission is added
var time := 0.0
var running := false
var finished := false

var _cargo_start: Transform3D
var _timer_label: Label
var _status_label: RichTextLabel
var _result: RichTextLabel


func _ready() -> void:
	_cargo_start = cargo.global_transform
	goal.body_entered.connect(_on_goal_entered)
	_build_hud()
	_update_status()


func _physics_process(delta: float) -> void:
	if finished or main == null or main.vehicle == null:
		return
	if not running and absf(main.vehicle.throttle) > 0.1:
		running = true # the clock starts when you first drive
	if running:
		time += delta
	_timer_label.text = Game.format_time(time)
	if cargo.global_position.y < -20.0:
		_show_result("[color=#ff8080]The crate fell off the world![/color]\n\n[font_size=20]T  try again     G  garage[/font_size]")
		finished = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_mission"):
		restart()


func restart() -> void:
	cargo.global_transform = _cargo_start
	cargo.linear_velocity = Vector3.ZERO
	cargo.angular_velocity = Vector3.ZERO
	main.spawn_vehicle(main._index)
	time = 0.0
	running = false
	finished = false
	_result.visible = false
	_timer_label.text = Game.format_time(0.0)


func _on_goal_entered(body: Node) -> void:
	if body != cargo or finished:
		return
	finished = true
	running = false
	var tier := Game.tier_for(time, gold_time, silver_time, bronze_time)
	var new_best := Game.record_result(mission_id, time, tier)
	var t := "[font_size=44][b]DELIVERED![/b][/font_size]\n"
	t += "[font_size=30]%s[/font_size]\n" % Game.format_time(time)
	if tier != "":
		t += "[font_size=40][color=#%s][b]%s[/b][/color][/font_size]\n" % [Game.TIER_COLORS[tier].to_html(false), tier.to_upper()]
	else:
		t += "[font_size=24]Too slow for a medal. Bronze is under %s[/font_size]\n" % Game.format_time(bronze_time)
	if tier == "silver":
		t += "Gold is under %s. Can you build something faster?\n" % Game.format_time(gold_time)
	elif tier == "bronze":
		t += "Silver is under %s. Can you build something faster?\n" % Game.format_time(silver_time)
	if new_best:
		t += "[color=#7dff8a]New best time![/color]\n"
	t += "\n[font_size=20]T  try again     G  back to the garage[/font_size]"
	_show_result(t)
	_update_status()


func _show_result(text: String) -> void:
	_result.text = "[center]" + text + "[/center]"
	_result.visible = true


func _update_status() -> void:
	var t := "[b]%s[/b]   %s\n" % [title, instructions]
	t += "[color=#%s]Gold %s[/color]    " % [Game.TIER_COLORS.gold.to_html(false), Game.format_time(gold_time)]
	t += "[color=#%s]Silver %s[/color]    " % [Game.TIER_COLORS.silver.to_html(false), Game.format_time(silver_time)]
	t += "[color=#%s]Bronze %s[/color]" % [Game.TIER_COLORS.bronze.to_html(false), Game.format_time(bronze_time)]
	var best := Game.best(mission_id)
	if not best.is_empty():
		t += "\nYour best: %s" % Game.format_time(float(best.time))
	t += "\n[font_size=15]T  restart mission[/font_size]"
	_status_label.text = "[center]" + t + "[/center]"


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_timer_label = Label.new()
	_timer_label.anchor_left = 0.5
	_timer_label.anchor_right = 0.5
	_timer_label.offset_left = -150
	_timer_label.offset_right = 150
	_timer_label.offset_top = 8
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 40)
	_timer_label.add_theme_constant_override("outline_size", 10)
	_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_timer_label.text = Game.format_time(0.0)
	layer.add_child(_timer_label)

	_status_label = _rich_label(layer, 18)
	_status_label.anchor_left = 0.5
	_status_label.anchor_right = 0.5
	_status_label.offset_left = -400
	_status_label.offset_right = 400
	_status_label.offset_top = 62

	_result = _rich_label(layer, 22)
	_result.anchor_left = 0.5
	_result.anchor_right = 0.5
	_result.anchor_top = 0.5
	_result.anchor_bottom = 0.5
	_result.offset_left = -360
	_result.offset_right = 360
	_result.offset_top = -150
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0, 0, 0, 0.6)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(20)
	_result.add_theme_stylebox_override("normal", panel)
	_result.visible = false


func _rich_label(parent: Node, size: int) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", size)
	l.add_theme_font_size_override("bold_font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	parent.add_child(l)
	return l
