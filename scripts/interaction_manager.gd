extends Node3D

@onready var player_inventory: Node = get_node("../../../PlayerInventory")
@onready var inventory: PlayerInventoryData = get_node("../../../PlayerInventoryData")
@onready var hud = get_node("../../../HUD")
@onready var build_mode = get_node("../../../BuildMode")
@onready var _player_body: CharacterBody3D = get_node("../../../")

var current_target = null

const LMB_HOLD_THRESHOLD: float = 0.6
const MMB_MAX_CHARGE: float = 1.5
const MMB_MIN_SPEED: float = 3.0
const SHELF_HOLD_INTERVAL: float = 0.18
const TOOL_HIT_INTERVAL: float = 0.5
## General-purpose interactable targeting range/cone. Proximity+facing based
## rather than raycast-driven -- see _find_best_interactable for why.
const INTERACT_RANGE: float = 4.0
const INTERACT_MAX_ANGLE_DEG: float = 40.0
## Extra angle forgiveness at point-blank range, tapering to zero by
## INTERACT_CLOSE_RANGE meters.
const INTERACT_CLOSE_RANGE: float = 2.0
const INTERACT_CLOSE_BONUS_DEG: float = 45.0
## Height above an interactable's origin used as its effective aim point.
const INTERACT_AIM_HEIGHT: float = 0.6

var _lmb_held: bool = false
var _lmb_hold_time: float = 0.0
var _lmb_confirmed_build: bool = false
var _tool_hold_active: bool = false
var _tool_hold_timer: float = 0.0
var _tool_interacted: bool = false
var _mmb_held: bool = false
var _mmb_hold_time: float = 0.0
var _shelf_lmb_active: bool = false
var _shelf_lmb_was_active: bool = false
var _shelf_lmb_timer: float = 0.0
var _shelf_rmb_active: bool = false
var _shelf_rmb_timer: float = 0.0

func _process(delta: float) -> void:
	var interactable: Node = null
	var aim_point := Vector3.ZERO
	var resolved := false

	# Layer-2 ray passes through normal geometry to detect counter items --
	# takes priority since it's a deliberate, narrow-purpose pick (which
	# exact item on a counter), same as the placement-zone ray below.
	var hit2 = _cast_layer2_ray()
	if hit2 != null:
		interactable = _find_interactable(hit2)
		resolved = true
	elif player_inventory.held_item != null and player_inventory.held_item.has_method("unpack_at"):
		var zone_hit = _cast_placement_zone_ray()
		if zone_hit != null:
			interactable = _find_interactable(zone_hit)
			resolved = true

	if not resolved:
		var found := _find_best_interactable()
		interactable = found.get("node")
		aim_point = found.get("point", Vector3.ZERO)

	if interactable:
		if interactable != current_target:
			if current_target:
				if current_target.has_method("hide_tooltip"):
					current_target.hide_tooltip()
				if current_target.has_method("on_look_away"):
					current_target.on_look_away()
			current_target = interactable
			if current_target.has_method("show_tooltip"):
				current_target.show_tooltip()
			_shelf_lmb_timer = 0.0
			_shelf_rmb_timer = 0.0
		if current_target.has_method("on_aimed_at"):
			current_target.on_aimed_at(player_inventory)
		if current_target.has_method("set_aim_point"):
			current_target.set_aim_point(aim_point)
	else:
		if current_target:
			if current_target.has_method("hide_tooltip"):
				current_target.hide_tooltip()
			if current_target.has_method("on_look_away"):
				current_target.on_look_away()
			current_target = null

	if _mmb_held and player_inventory.held_item != null and player_inventory.held_item is RigidBody3D:
		_mmb_hold_time += delta

	if _lmb_held and not build_mode.active and current_target != null and current_target.has_method("get_move_hint") and player_inventory.held_item == null:
		_lmb_hold_time += delta
		if _lmb_hold_time >= LMB_HOLD_THRESHOLD:
			_lmb_held = false
			build_mode.enter(current_target)
			current_target = null

	if _shelf_lmb_active:
		_shelf_lmb_timer += delta
		if _shelf_lmb_timer >= SHELF_HOLD_INTERVAL:
			_shelf_lmb_timer = 0.0
			if current_target and _is_product_shelf(current_target):
				current_target.interact()

	if _shelf_rmb_active:
		_shelf_rmb_timer += delta
		if _shelf_rmb_timer >= SHELF_HOLD_INTERVAL:
			_shelf_rmb_timer = 0.0
			if current_target and _is_product_shelf(current_target):
				current_target.retrieve_print(player_inventory)

	if _tool_hold_active:
		_tool_hold_timer += delta
		if _tool_hold_timer >= _current_tool_hit_interval():
			_tool_hold_timer = 0.0
			_swing_and_hit(current_target)

	_update_hud()

func _is_product_shelf(target) -> bool:
	return target != null and target.has_method("get_retrieve_hint")

func _is_chest(target) -> bool:
	return target != null and target.is_in_group("chest")

func _current_tool_hit_interval() -> float:
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	var perks = get_tree().get_first_node_in_group("player_gathering_perks")
	return GatherBonuses.apply_speed_interval(TOOL_HIT_INTERVAL, inventory, equipper, perks)

## Starts the swing animation and, if a target is given, defers the actual
## interact() call until the swing visually reaches its peak (swing_hit).
func _swing_and_hit(target) -> bool:
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if equipper == null or not equipper.has_method("play_swing"):
		return true
	if equipper.has_method("can_swing") and not equipper.can_swing():
		return false
	equipper.play_swing()
	if target and target.has_method("interact") and equipper.has_signal("swing_hit"):
		equipper.swing_hit.connect(func():
			if is_instance_valid(target) and target.has_method("interact"):
				target.interact()
		, CONNECT_ONE_SHOT)
	return true

func _cast_placement_zone_ray():
	var space = get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + (-global_transform.basis.z * 4.0),
		8  # layer 4 only -- placement zones
	)
	ray.collide_with_areas = true
	ray.collide_with_bodies = false
	var result = space.intersect_ray(ray)
	if not result:
		return null
	var col = result.get("collider")
	if col == null:
		return null
	return col.get_parent() if col is Area3D else col

func _cast_layer2_ray():
	var space = get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + (-global_transform.basis.z * 4.0),
		2  # layer 2 only -- passes through layer-1 geometry
	)
	var result = space.intersect_ray(ray)
	return result.get("collider") if result else null

## Picks the best general interactable to target by proximity + facing
## instead of a raycast: every "interactable" within INTERACT_RANGE and
## INTERACT_MAX_ANGLE_DEG of where the camera is looking is scored (most
## centered wins, distance as a tiebreaker), and the winner is confirmed
## with one line-of-sight raycast so you can't reach through a wall.
## Selection no longer depends on your resting position lining up with a
## collision shape's exact boundary -- that's what made mining nodes (and
## then chests/shops, once we noticed) unreliable to hit while standing
## still but fine while walking toward them: the physical StaticBody a
## player rests against and the ray's target were literally the same shape.
## Proximity+angle math is continuous regardless of whether you're moving,
## so that whole class of flakiness goes away without needing a second,
## non-blocking collider on every interactable.
func _find_best_interactable() -> Dictionary:
	var cam_pos: Vector3 = global_position
	var cam_forward: Vector3 = -global_transform.basis.z
	var up := Vector3(0, INTERACT_AIM_HEIGHT, 0)

	var best: Node = null
	var best_score := -INF
	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Node3D):
			continue
		# Most props (mining nodes, trees, chests) have their origin at
		# ground level, not at the visual mass a player naturally looks at --
		# aiming at the raw origin makes the angle check fail while standing
		# close or looking slightly down/up at something you're clearly
		# looking at.
		var aim_point: Vector3 = node.global_position + up
		var to_node: Vector3 = aim_point - cam_pos
		var dist := to_node.length()
		if dist < 0.001 or dist > INTERACT_RANGE:
			continue
		var angle_cos := cam_forward.dot(to_node / dist)
		# Large objects (boulders, trees) subtend a much wider angle up
		# close than a fixed cone around their origin implies -- relax the
		# cone as distance shrinks, tapering back to the base cone by
		# INTERACT_CLOSE_RANGE meters.
		var close_bonus_deg := clampf((INTERACT_CLOSE_RANGE - dist) / INTERACT_CLOSE_RANGE, 0.0, 1.0) * INTERACT_CLOSE_BONUS_DEG
		var min_angle_cos := cos(deg_to_rad(INTERACT_MAX_ANGLE_DEG + close_bonus_deg))
		if angle_cos < min_angle_cos:
			continue
		var score := angle_cos - dist * 0.05
		if score > best_score:
			best_score = score
			best = node

	if best == null:
		return {}

	# Confirm nothing solid sits between the camera and the candidate, and
	# grab a real hit point for anything (shelves) that needs to know which
	# specific spot you're looking at, not just which object. hit_from_inside
	# matters here too -- standing right up against (or inside) a large
	# object's own collision shape shouldn't count as "blocked". Exclude the
	# player's own body -- the camera sits essentially inside its collision
	# capsule, so an unexcluded ray on the same layer hits the player itself
	# before it ever reaches the candidate.
	var aim_target: Vector3 = best.global_position + up
	var space = get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(cam_pos, aim_target, 1, [_player_body.get_rid()])
	ray.hit_from_inside = true
	var result = space.intersect_ray(ray)
	var resolved_best: Node = best.get_meta("interact_owner") if best.has_meta("interact_owner") else best
	if result:
		if _find_interactable(result["collider"]) != resolved_best:
			return {}
		return {"node": resolved_best, "point": result["position"]}
	return {"node": resolved_best, "point": aim_target}

## Some interactables (e.g. a shop NPC's own physics body, see
## store_market_stall.gd) tag themselves with an "interact_owner" meta
## pointing at a different node that actually implements interact() --
## resolve that redirect here so every caller gets the right target.
func _find_interactable(hit) -> Node:
	if hit == null:
		return null
	var node = hit
	for i in range(8):
		if node.is_in_group("interactable"):
			if node.has_meta("interact_owner"):
				return node.get_meta("interact_owner")
			return node
		if node.get_parent() == null:
			break
		node = node.get_parent()
	return null

func _update_hud() -> void:
	var hints: Array[String] = []

	if build_mode.active:
		hints.append("[LMB] Place")
		hints.append("[Scroll] Rotate")
		var snap_label = "ON" if build_mode.grid_snap else "OFF"
		hints.append("[Y] Grid: %s" % snap_label)
		hints.append("[RMB] Cancel")
		hud.set_hints(hints)
		return

	var held = player_inventory.held_item

	if held and held is RigidBody3D:
		if _mmb_held:
			var pct = int(clamp(_mmb_hold_time / MMB_MAX_CHARGE, 0.0, 1.0) * 100)
			hints.append("[MMB] Throw -- %d%%" % pct)
		else:
			hints.append("[MMB] Throw")

	if held:
		if held.has_method("get_unpack_hint"):
			hints.append("[E] %s" % held.get_unpack_hint())
		if held.has_method("_toggle_lid"):
			hints.append("[F] Open/Close")
		var retrieve_hint = ""
		if current_target and current_target.has_method("get_retrieve_hint"):
			retrieve_hint = current_target.get_retrieve_hint()
		if retrieve_hint != "":
			hints.append("[RMB/Hold] %s" % retrieve_hint)
		else:
			var drop_text = "Drop"
			if held.has_method("get_drop_hint"):
				drop_text = held.get_drop_hint()
			hints.append("[RMB] %s" % drop_text)

	if current_target:
		if current_target.has_method("get_click_hint"):
			var click_text: String = current_target.get_click_hint(player_inventory)
			if click_text != "":
				var prefix = "[LMB/Hold]" if (_is_product_shelf(current_target) or current_target.has_method("interact")) else "[Click]"
				hints.append("%s %s" % [prefix, click_text])
		if current_target.has_method("get_pack_hint"):
			var pack_text: String = current_target.get_pack_hint(player_inventory)
			if pack_text != "":
				hints.append("[R] %s" % pack_text)
		if held == null:
			if current_target.has_method("get_move_hint"):
				hints.append("[Hold LMB] %s" % current_target.get_move_hint())
			if current_target.has_method("get_interact_hint"):
				var interact_text: String = current_target.get_interact_hint()
				if interact_text != "":
					hints.append("[E] %s" % interact_text)
			if current_target.has_method("get_lid_hint"):
				hints.append("[F] %s" % current_target.get_lid_hint())

	hud.set_hints(hints)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if build_mode.active:
			pass
		elif current_target:
			current_target.interact()
		elif player_inventory.held_item and player_inventory.held_item.has_method("unpack_at"):
			var unpacked = player_inventory.unpack_held_item()
			if unpacked:
				build_mode.enter(unpacked)

	if event.is_action_pressed("pack_item") and not build_mode.active and current_target and current_target.has_method("pack_away"):
		current_target.pack_away(player_inventory)

	if event.is_action_pressed("drop") and not build_mode.active:
		if not (_is_product_shelf(current_target) and player_inventory.held_item != null):
			player_inventory.place_box()

	if event.is_action_pressed("open_close_box") and not build_mode.active:
		if player_inventory.held_item != null and player_inventory.held_item.has_method("_toggle_lid"):
			player_inventory.held_item._toggle_lid()
		elif current_target and current_target.has_method("_toggle_lid"):
			current_target._toggle_lid()

	if event.is_action_pressed("grid_snap"):
		build_mode.grid_snap = not build_mode.grid_snap

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_lmb_held = true
				if build_mode.active:
					build_mode.exit(true)
					_lmb_confirmed_build = true
				elif not build_mode.active and _is_product_shelf(current_target):
					current_target.interact()
					_shelf_lmb_active = true
					_shelf_lmb_was_active = true
					_shelf_lmb_timer = 0.0
				elif not build_mode.active and _is_chest(current_target):
					# Chests only open via [E] Interact, not left click.
					_tool_interacted = true
				elif not build_mode.active and current_target and current_target.has_method("interact"):
					if current_target.has_method("try_trash"):
						current_target.try_trash(player_inventory)
					elif current_target.has_method("collect_all_prints"):
						current_target.collect_all_prints(player_inventory)
					elif current_target.has_method("get_collectable_item_type"):
						var item_type: String = current_target.get_collectable_item_type()
						if item_type != "" and player_inventory.collect_item(item_type, current_target.global_position):
							current_target.clear_print()
					else:
						_swing_and_hit(current_target)
					_tool_hold_active = true
					_tool_hold_timer = 0.0
					_tool_interacted = true
				else:
					_swing_and_hit(null)
					_tool_hold_active = true
					_tool_hold_timer = 0.0
					_tool_interacted = true
			else:
				_shelf_lmb_active = false
				_tool_hold_active = false
				_tool_hold_timer = 0.0
				if not build_mode.active and not _shelf_lmb_was_active and not _lmb_confirmed_build and not _tool_interacted:
					if current_target and current_target.has_method("try_trash"):
						current_target.try_trash(player_inventory)
					elif current_target and current_target.has_method("collect_all_prints"):
						current_target.collect_all_prints(player_inventory)
					elif current_target and current_target.has_method("get_collectable_item_type"):
						var item_type: String = current_target.get_collectable_item_type()
						if item_type != "" and player_inventory.collect_item(item_type, current_target.global_position):
							current_target.clear_print()
					elif current_target and current_target.has_method("interact"):
						_swing_and_hit(current_target)
				_shelf_lmb_was_active = false
				_lmb_confirmed_build = false
				_tool_interacted = false
				_lmb_held = false
				_lmb_hold_time = 0.0

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if build_mode.active:
					build_mode.exit(false)
				elif _is_product_shelf(current_target) and player_inventory.held_item != null:
					current_target.retrieve_print(player_inventory)
					_shelf_rmb_active = true
					_shelf_rmb_timer = 0.0
				elif _try_deploy_furniture():
					get_viewport().set_input_as_handled()
			else:
				_shelf_rmb_active = false

		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_mmb_held = true
				_mmb_hold_time = 0.0
			else:
				if player_inventory.held_item != null and player_inventory.held_item is RigidBody3D:
					var charge = clamp(_mmb_hold_time / MMB_MAX_CHARGE, 0.0, 1.0)
					var speed = lerpf(MMB_MIN_SPEED, player_inventory.THROW_SPEED_MAX, charge)
					player_inventory.throw_item(speed)
				_mmb_held = false
				_mmb_hold_time = 0.0

		elif build_mode.active and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				build_mode.rotate_ghost(-build_mode.ROTATE_STEP)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				build_mode.rotate_ghost(build_mode.ROTATE_STEP)

func _try_deploy_furniture() -> bool:
	if player_inventory.held_item != null:
		return false
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if equipper == null:
		return false
	var item_id = equipper.current_item_id
	if item_id == "":
		return false
	var def = ItemDB.get_item(item_id)
	if def == null or def.type != ItemDefinition.ItemType.FURNITURE or def.place_scene == null:
		return false
	if not inventory.has_item(item_id):
		return false
	var source_slot_index = equipper.current_slot_index
	inventory.remove_item(item_id)
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.is_empty():
		return false
	var player = player_nodes[0].get_parent()
	var forward = -player.global_transform.basis.z
	var spawn_pos = player.global_position + forward * 1.2
	spawn_pos.y = player.global_position.y
	var item = def.place_scene.instantiate()
	get_tree().current_scene.add_child(item)
	item.global_position = spawn_pos
	item.rotation.y = player.rotation.y + deg_to_rad(def.place_rotation_offset)
	build_mode.enter(item, item_id, source_slot_index)
	return true
