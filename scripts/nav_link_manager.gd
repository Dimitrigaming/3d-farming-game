extends Node3D

const BLOCK_SIZE := 4.0

# Stores {link_key -> {link, pos_a, pos_b}}
var _grid_links: Dictionary = {}
# Stores {block_key -> {link, target_pos}}
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
			var nb = pos + dir
			if not pos_set.has(_key(nb)):
				continue
			var lkey = _link_key(pos, nb)
			if not _grid_links.has(lkey):
				_grid_links[lkey] = {
					"link": _make_link(pos, nb),
					"pos_a": pos,
					"pos_b": nb,
				}

		var skey = _key(pos)
		if not _star_links.has(skey):
			_star_links[skey] = {
				"link": _make_link(_origin.global_position, pos),
				"target": pos,
			}

func _refresh_all() -> void:
	var blocks = get_tree().get_nodes_in_group("interior_block")
	for entry in _grid_links.values():
		entry["link"].enabled = _grid_clear(entry["pos_a"], entry["pos_b"], blocks)
	for entry in _star_links.values():
		entry["link"].enabled = _star_clear(_origin.global_position, entry["target"], blocks)

func refresh_at(_removed_pos: Vector3) -> void:
	await get_tree().process_frame
	_refresh_all()

# A grid link between A and B is open when neither block still exists
func _grid_clear(pos_a: Vector3, pos_b: Vector3, blocks: Array) -> bool:
	for block in blocks:
		var bp = block.global_position
		if _xz_dist(bp, pos_a) < 1.0 or _xz_dist(bp, pos_b) < 1.0:
			return false
	return true

# A star link to target is open when no remaining block is near the straight line
func _star_clear(from: Vector3, target: Vector3, blocks: Array) -> bool:
	for block in blocks:
		if _xz_dist_to_segment(block.global_position, from, target) < BLOCK_SIZE * 0.6:
			return false
	return true

func _xz_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _xz_dist_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var p = Vector2(point.x, point.z)
	var av = Vector2(a.x, a.z)
	var bv = Vector2(b.x, b.z)
	var ab = bv - av
	var len_sq = ab.length_squared()
	if len_sq == 0.0:
		return p.distance_to(av)
	var t = clampf((p - av).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(av + ab * t)

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
