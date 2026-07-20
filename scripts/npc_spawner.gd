extends Node3D

const NPC_SCENE = preload("res://models/npc.tscn")

@export var enabled: bool = true
@export var spawn_interval: float = 5.0
@export var max_npcs: int = 10
@export_range(0.0, 1.0) var debug_store_interest: float = 0.0
@export var fixed_destination: NodePath = NodePath("")

var _timer: float = 0.0

func _ready() -> void:
	get_node_or_null("/root/GameLogger").debug("NpcSpawner", "ready interval=%.1fs max=%d" % [spawn_interval, max_npcs])
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
	var destination = _get_destination()
	if destination == null:
		get_node_or_null("/root/GameLogger").warning("NpcSpawner", "no destination found  skipping spawn")
		return
	var npc = NPC_SCENE.instantiate()
	get_node_or_null("/root/GameLogger").debug("NpcSpawner", "spawning NPC %s" % destination.name)
	get_tree().current_scene.add_child(npc)
	var map = get_world_3d().get_navigation_map()
	var snapped = NavigationServer3D.map_get_closest_point(map, global_position)
	npc.global_position = snapped
	if npc.has_method("set_street_destination"):
		npc.set_street_destination.call_deferred(destination.global_position, debug_store_interest)

func _get_destination() -> Node3D:
	if fixed_destination != NodePath(""):
		return get_node_or_null(fixed_destination)
	return _pick_opposite_destination()

func _pick_opposite_destination() -> Node3D:
	var my_side = get_parent()
	if my_side == null:
		return null
	var npc_markers = my_side.get_parent()
	if npc_markers == null:
		return null
	var opposite_name = "Right" if my_side.name == "Left" else "Left"
	var opposite = npc_markers.get_node_or_null(opposite_name)
	if opposite == null or opposite.get_child_count() == 0:
		return null
	return opposite.get_child(randi() % opposite.get_child_count())
