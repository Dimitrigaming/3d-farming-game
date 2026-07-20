extends Node3D

enum PlacementRoom { ANYWHERE, SHOP_ONLY, PRODUCTION_ONLY }
@export var placement_room: PlacementRoom = PlacementRoom.ANYWHERE

const PACKING_CRATE_SCENE = preload("res://models/packing_crate.tscn")
const OWN_SCENE = preload("res://models/small_station.tscn")

@onready var _detection_zone: Area3D = $DetectionZone

func _ready() -> void:
	add_to_group("interactable")

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_move_hint() -> String:
	return "Move"

func get_move_passengers() -> Array:
	return _get_printers()

func get_interact_hint() -> String:
	for printer in _get_printers():
		if not printer.is_printing and not printer.print_finished:
			return "Start All Printers"
	return ""

func interact() -> void:
	for printer in _get_printers():
		printer.start_print()

func get_click_hint(_player_inventory) -> String:
	for printer in _get_printers():
		if printer.print_finished:
			return "Collect Prints"
	return ""

func collect_all_prints(player_inventory) -> void:
	for printer in _get_printers():
		if printer.print_finished:
			var item_type = printer.get_collectable_item_type()
			if item_type != "":
				player_inventory.collect_item(item_type, printer.global_position)
				printer.clear_print()

func get_pack_hint(player_inventory) -> String:
	if player_inventory.held_item == null:
		return "Pack Away"
	return ""

func pack_away(player_inventory) -> void:
	if player_inventory.held_item != null:
		return
	var crate = PACKING_CRATE_SCENE.instantiate()
	get_tree().current_scene.add_child(crate)
	crate.pack("Small Station", OWN_SCENE)
	player_inventory.pick_up_item(crate)
	queue_free()

func _get_printers() -> Array:
	var printers = []
	for body in _detection_zone.get_overlapping_bodies():
		var node = body.get_parent() if body is StaticBody3D else body
		if node and node.has_method("start_print"):
			printers.append(node)
	return printers
