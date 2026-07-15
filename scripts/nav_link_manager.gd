extends Node3D

const BLOCK_SIZE := 4.0
const WALL_MASK := 4

var _grid_links: Dictionary = {}
var _star_links: Dictionary = {}
var _origin: Node3D

func _ready() -> void:
	await get_tree().physics_frame
	_origin = get_tree().get_first_node_in_group("nav_link_origin")
	if not _origin:
		push_warning("NavLinkManager: no nav_link_origin group node found")
		return
	_build_links()
	_refresh_all()

func _build_links() -> void:
	var blocks = get_tree().get_nodes_in_group("interior_block")
	var pos_set: Dictionary = {}
	for block in blocks:
		pos_set[_key(block.global_position)] = block.global_position

	for block in blocks:
		var pos = block.global_position

		for dir in [Vector3(BLOCK_SIZE, 0, 0), Vector3(-BLOCK_SIZE, 0, 0),
					Vector3(0, 0, BLOCK_SIZE), Vector3(0, 0, -BLOCK_SIZE)]:
			var neighbor_pos = pos + dir
			if not pos_set.has(_key(neighbor_pos)):
				continue
			var lkey = _link_key(pos, neighbor_pos)
			if not _grid_links.has(lkey):
				_grid_links[lkey] = _make_link(pos, neighbor_pos)

		var skey = _key(pos)
		if not _star_links.has(skey):
			_star_links[skey] = _make_link(_origin.global_position, pos)

func _refresh_all() -> void:
	var space = get_world_3d().direct_space_state
	for link in _grid_links.values():
		link.enabled = _ray_clear(space, to_global(link.start_position), to_global(link.end_position))
	for link in _star_links.values():
		link.enabled = _ray_clear(space, to_global(link.start_position), to_global(link.end_position))

func refresh_at(removed_pos: Vector3) -> void:
	await get_tree().physics_frame
	var space = get_world_3d().direct_space_state

	for dir in [Vector3(BLOCK_SIZE, 0, 0), Vector3(-BLOCK_SIZE, 0, 0),
				Vector3(0, 0, BLOCK_SIZE), Vector3(0, 0, -BLOCK_SIZE)]:
		var lkey = _link_key(removed_pos, removed_pos + dir)
		if _grid_links.has(lkey):
			var link: NavigationLink3D = _grid_links[lkey]
			link.enabled = _ray_clear(space, to_global(link.start_position), to_global(link.end_position))

	for link in _star_links.values():
		link.enabled = _ray_clear(space, to_global(link.start_position), to_global(link.end_position))

func _ray_clear(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var query = PhysicsRayQueryParameters3D.create(from, to, WALL_MASK)
	return space.intersect_ray(query).is_empty()

func _make_link(from: Vector3, to: Vector3) -> NavigationLink3D:
	var link = NavigationLink3D.new()
	link.bidirectional = true
	add_child(link)
	link.enabled = false
	link.start_position = to_local(from)
	link.end_position = to_local(to)
	return link

func _key(pos: Vector3) -> String:
	return "%d,%d" % [roundi(pos.x), roundi(pos.z)]

func _link_key(a: Vector3, b: Vector3) -> String:
	var ka = _key(a)
	var kb = _key(b)
	return ka + "-" + kb if ka < kb else kb + "-" + ka
