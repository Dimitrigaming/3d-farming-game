extends Node3D

const BLOCK_SIZE := 4.0

var _star_links: Dictionary = {}  # block_key -> {link, target}
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
	for block in get_tree().get_nodes_in_group("interior_block"):
		var pos = block.global_position
		var skey = _key(pos)
		if not _star_links.has(skey):
			_star_links[skey] = {
				"link": _make_link(_origin.global_position, pos),
				"target": pos,
			}

func _refresh_all() -> void:
	var reachable = _flood_fill_reachable()
	for skey in _star_links:
		_star_links[skey]["link"].enabled = reachable.has(skey)

func refresh_at(_removed_pos: Vector3) -> void:
	await get_tree().process_frame
	_refresh_all()

# Flood-fill through removed block positions starting from NavLinkStart.
# Only block positions that are contiguously connected (no walls between) are reachable.
func _flood_fill_reachable() -> Dictionary:
	var blocks_in_scene: Dictionary = {}
	for block in get_tree().get_nodes_in_group("interior_block"):
		blocks_in_scene[_key(block.global_position)] = true

	# All positions that once had a block but no longer do
	var removed: Dictionary = {}
	for skey in _star_links:
		if not blocks_in_scene.has(skey):
			removed[skey] = _star_links[skey]["target"]

	# Seed flood fill: removed blocks adjacent to NavLinkStart
	var reachable: Dictionary = {}
	var queue: Array = []
	for skey in removed:
		var pos: Vector3 = removed[skey]
		if _xz_dist(pos, _origin.global_position) < BLOCK_SIZE * 1.5:
			reachable[skey] = pos
			queue.append(pos)

	# Expand through adjacent removed blocks
	while queue.size() > 0:
		var current: Vector3 = queue.pop_front()
		for dir in [Vector3(BLOCK_SIZE, 0, 0), Vector3(-BLOCK_SIZE, 0, 0),
					Vector3(0, 0, BLOCK_SIZE), Vector3(0, 0, -BLOCK_SIZE)]:
			var nb = current + dir
			var nkey = _key(nb)
			if removed.has(nkey) and not reachable.has(nkey):
				reachable[nkey] = nb
				queue.append(nb)

	return reachable

func _xz_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

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
