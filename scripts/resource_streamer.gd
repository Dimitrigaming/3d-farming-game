extends Node

## Central proximity gate for mining/tree nodes' physics bodies. Removing a
## StaticBody3D from the scene tree is what actually unregisters it from
## Jolt -- disabling its CollisionShape3D does not, the body stays
## registered with zero active shapes and still counts toward
## jolt_physics_3d/limits/max_bodies. Nodes register themselves here once
## in _ready() and get toggled in/out of the tree based on distance instead
## of every node running its own distance check every frame.

const ACTIVATE_RANGE: float = 30.0
## Slightly larger than ACTIVATE_RANGE so hovering right at the boundary
## doesn't rapidly attach/detach the same body every check.
const DEACTIVATE_RANGE: float = 33.0
const CHECK_INTERVAL: float = 0.4

var _nodes: Array = []
var _timer: float = 0.0

func register(node: Node) -> void:
	if not _nodes.has(node):
		_nodes.append(node)

func _process(delta: float) -> void:
	_timer += delta
	if _timer < CHECK_INTERVAL:
		return
	_timer = 0.0

	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.is_empty():
		return
	var player_pos: Vector3 = player_nodes[0].global_position

	var stale: Array = []
	for node in _nodes:
		if not is_instance_valid(node):
			stale.append(node)
			continue
		var dist: float = node.global_position.distance_to(player_pos)
		if dist <= ACTIVATE_RANGE:
			node.update_streaming(true)
		elif dist >= DEACTIVATE_RANGE:
			node.update_streaming(false)
	for node in stale:
		_nodes.erase(node)
