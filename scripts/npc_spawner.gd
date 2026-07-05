extends Marker3D

const NPC_SCENE = preload("res://models/npc.tscn")
const RESPAWN_DELAY: float = 3.0
const MAX_NPCS: int = 6

@export var enabled: bool = true

var _timer: float = 0.0

func _process(delta: float) -> void:
	if not enabled:
		return
	var current = get_tree().get_nodes_in_group("npc").size()
	if current < MAX_NPCS:
		_timer += delta
		if _timer >= RESPAWN_DELAY:
			_timer = 0.0
			_spawn()
	else:
		_timer = 0.0

func _spawn() -> void:
	var npc = NPC_SCENE.instantiate()
	get_tree().current_scene.add_child(npc)
	npc.global_position = global_position
