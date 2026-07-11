extends "res://scripts/small_product_shelf.gd"

const PRINT_MODEL_ADMIN = preload("res://models/default_model.tscn")

var _spawn_timer: float = 0.0

func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= 1.0:
		_spawn_timer = 0.0
		_spawn_print()

func _spawn_print() -> void:
	var zone = _first_available_zone("Default Model")
	if zone == null:
		return
	var model = PRINT_MODEL_ADMIN.instantiate()
	get_tree().current_scene.add_child(model)
	var spawn = get_node_or_null("ProductSpawn")
	model.global_position = spawn.global_position if spawn else global_position
	add_print("Default Model", model)
