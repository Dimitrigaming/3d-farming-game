extends RigidBody3D

var _register: Node3D = null

func _ready() -> void:
	add_to_group("interactable")

func setup(register: Node3D) -> void:
	_register = register

func show_tooltip() -> void:
	pass

func hide_tooltip() -> void:
	pass

func get_click_hint(_player_inventory) -> String:
	return "Scan"

func interact() -> void:
	if _register and is_instance_valid(_register):
		_register.scan_item(self)
