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

func _refresh_all() -> void:
	var blocks = get_tree().get_nodes_in_group("interior_block")

	for skey in _entry_links:
		var entry = _entry_links[skey]
		var removed = not _any_block_at(entry["pos"], blocks)
		var adjacent = _xz_dist(entry["pos"], _origin.global_position) < 15.0
		entry["link"].enabled = removed and adjacent

	for entry in _chain_links:
		var a_clear = not _any_block_at(entry["pos_a"], blocks)
		var b_clear = not _any_block_at(entry["pos_b"], blocks)
		entry["link"].enabled = a_clear and b_clear

func _any_block_at(pos: Vector3, blocks: Array) -> bool:
	for block in blocks:
		if _xz_dist(block.global_position, pos) < 1.0:
			return true
	return false

func refresh_at(_removed_pos: Vector3) -> void:
	await get_tree().process_frame
	_refresh_all()

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
