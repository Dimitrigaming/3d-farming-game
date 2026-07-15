extends Node3D

const BLOCK_SIZE := 4.0

var _entry_links: Dictionary = {}  # block_key -> {link, pos}
var _chain_links: Array = []       # [{link, pos_a, pos_b}]

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
		var skey = _key(pos)

		if not _entry_links.has(skey):
			_entry_links[skey] = {"link": _make_link(_origin.global_position, pos), "pos": pos}

		for dir in [Vector3(BLOCK_SIZE, 0, 0), Vector3(0, 0, BLOCK_SIZE)]:
			var nb = pos + dir
			if not pos_set.has(_key(nb)):
				continue
			var lkey = _pair_key(skey, _key(nb))
			var already = false
			for entry in _chain_links:
				if entry["key"] == lkey:
					already = true
					break
			if not already:
				_chain_links.append({"link": _make_link(pos, nb), "pos_a": pos, "pos_b": nb, "key": lkey})

func _refresh_all(just_removed: Vector3 = Vector3(INF, INF, INF)) -> void:
	var blocks = get_tree().get_nodes_in_group("interior_block")

	# collect all known block positions (present + all that ever existed)
	var all_known: Array = []
	for skey in _entry_links:
		all_known.append(_entry_links[skey]["pos"])

	# find removed blocks that border open floor (seed for flood-fill)
	var removed: Array = []
	for skey in _entry_links:
		var pos = _entry_links[skey]["pos"]
		if not _any_block_at(pos, blocks, just_removed):
			removed.append(pos)

	var reachable = _flood_fill(removed, all_known)

	for skey in _entry_links:
		var entry = _entry_links[skey]
		entry["link"].enabled = _in_set(entry["pos"], reachable)

	for entry in _chain_links:
		entry["link"].enabled = _in_set(entry["pos_a"], reachable) and _in_set(entry["pos_b"], reachable)

func _flood_fill(removed: Array, all_known: Array) -> Array:
	var reachable: Array = []
	var queue: Array = []
	# seed: removed blocks that have at least one neighbor with no block (open floor)
	for pos in removed:
		for dir in [Vector3(BLOCK_SIZE,0,0), Vector3(-BLOCK_SIZE,0,0), Vector3(0,0,BLOCK_SIZE), Vector3(0,0,-BLOCK_SIZE)]:
			if not _in_set(pos + dir, all_known):
				reachable.append(pos)
				queue.append(pos)
				break
	while not queue.is_empty():
		var cur: Vector3 = queue.pop_front()
		for dir in [Vector3(BLOCK_SIZE,0,0), Vector3(-BLOCK_SIZE,0,0), Vector3(0,0,BLOCK_SIZE), Vector3(0,0,-BLOCK_SIZE)]:
			var nb = cur + dir
			if _in_set(nb, reachable):
				continue
			for rpos in removed:
				if _xz_dist(rpos, nb) < 1.0:
					reachable.append(rpos)
					queue.append(rpos)
					break
	return reachable

func _in_set(pos: Vector3, set: Array) -> bool:
	for p in set:
		if _xz_dist(p, pos) < 1.0:
			return true
	return false

func _any_block_at(pos: Vector3, blocks: Array, just_removed: Vector3 = Vector3(INF, INF, INF)) -> bool:
	if _xz_dist(pos, just_removed) < 1.0:
		return false
	for block in blocks:
		if _xz_dist(block.global_position, pos) < 1.0:
			return true
	return false

func refresh_at(removed_pos: Vector3) -> void:
	await get_tree().process_frame
	_refresh_all(removed_pos)

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

func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a
