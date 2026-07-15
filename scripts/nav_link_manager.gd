extends Node3D

const BLOCK_SIZE := 4.0

var _entry_links: Dictionary = {}  # block_key -> NavigationLink3D
var _chain_links: Dictionary = {}  # "keyA|keyB" -> {link, key_a, key_b}

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
			_entry_links[skey] = _make_link(_origin.global_position, pos)

		for dir in [Vector3(BLOCK_SIZE, 0, 0), Vector3(0, 0, BLOCK_SIZE)]:
			var nb = pos + dir
			var nkey = _key(nb)
			if not pos_set.has(nkey):
				continue
			var lkey = _pair_key(skey, nkey)
			if not _chain_links.has(lkey):
				_chain_links[lkey] = {
					"link": _make_link(pos, nb),
					"key_a": skey,
					"key_b": nkey,
				}

func _refresh_all() -> void:
	var blocks_in_scene: Dictionary = {}
	for block in get_tree().get_nodes_in_group("interior_block"):
		blocks_in_scene[_key(block.global_position)] = true

	for skey in _entry_links:
		var removed = not blocks_in_scene.has(skey)
		var link: NavigationLink3D = _entry_links[skey]
		var block_pos = to_global(link.end_position)
		var adjacent = _xz_dist(block_pos, _origin.global_position) < BLOCK_SIZE * 1.5
		link.enabled = removed and adjacent

	for lkey in _chain_links:
		var entry = _chain_links[lkey]
		var both_removed = not blocks_in_scene.has(entry["key_a"]) \
						and not blocks_in_scene.has(entry["key_b"])
		entry["link"].enabled = both_removed

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
