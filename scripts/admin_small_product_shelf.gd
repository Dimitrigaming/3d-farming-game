extends "res://scripts/small_product_shelf.gd"

var _spawn_timer: float = 0.0

func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= 1.0:
		_spawn_timer = 0.0
		add_print("Default Model")
