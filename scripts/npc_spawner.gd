extends Node3D

const NPC_SCENE = preload("res://models/npc.tscn")

@export var enabled: bool = true
@export var spawn_interval: float = 5.0
@export var max_npcs: int = 10
## 0.0 = no interest, 1.0 = guaranteed entry. Overrides calculated interest for testing.
@export_range(0.0, 1.0) var debug_store_interest: float = 0.0

var _timer: float = 0.0

func _ready() -> void:
	_timer = -randf_range(0.0, spawn_interval)

func _process(delta: float) -> void:
	if not enabled:
		return
	var current = get_tree().get_nodes_in_group("npc").size()
	if current >= max_npcs:
		_timer = 0.0
		return
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn()

func _spawn() -> void:
	var path = _find_nearest_walking_path()
	if path == null:
		return
	var npc = NPC_SCENE.instantiate()
	get_tree().current_scene.add_child(npc)
	npc.global_position = global_position
	if npc.has_method("assign_path"):
		npc.assign_path(path, debug_store_interest)

func _find_nearest_walking_path() -> Node3D:
	var best: Node3D = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("walking_path"):
		var d = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best
