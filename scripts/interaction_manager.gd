extends RayCast3D

@onready var player_inventory: Node = get_node("../../../PlayerInventory")
@onready var hud = get_node("../../../HUD")
@onready var build_mode = get_node("../../../BuildMode")

var current_target = null

const LMB_HOLD_THRESHOLD: float = 0.6
const MMB_MAX_CHARGE: float = 1.5
const MMB_MIN_SPEED: float = 3.0
const SHELF_HOLD_INTERVAL: float = 0.18

var _lmb_held: bool = false
var _lmb_hold_time: float = 0.0
var _mmb_held: bool = false
var _mmb_hold_time: float = 0.0
var _shelf_lmb_active: bool = false
var _shelf_lmb_was_active: bool = false
var _shelf_lmb_timer: float = 0.0
var _shelf_rmb_active: bool = false
var _shelf_rmb_timer: float = 0.0

func _process(delta: float) -> void:
	var hit = get_collider()
	# Layer-2 ray passes through normal geometry to detect counter items
	var hit2 = _cast_layer2_ray()
	if hit2 != null:
		hit = hit2
	var interactable = _find_interactable(hit)

	if interactable:
		if interactable != current_target:
			if current_target:
				current_target.hide_tooltip()
				if current_target.has_method("on_look_away"):
					current_target.on_look_away()
			current_target = interactable
			current_target.show_tooltip()
			_shelf_lmb_timer = 0.0
			_shelf_rmb_timer = 0.0
		if current_target.has_method("on_aimed_at"):
			current_target.on_aimed_at(player_inventory)
		if current_target.has_method("set_aim_point"):
			current_target.set_aim_point(get_collision_point())
	else:
		if current_target:
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

	_update_hud()

func _is_product_shelf(target) -> bool:
	return target != null and target.has_method("get_retrieve_hint")

func _cast_layer2_ray():
	var space = get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + (-global_transform.basis.z * 4.0),
		2  # layer 2 only — passes through layer-1 geometry
	)
	var result = space.intersect_ray(ray)
	return result.get("collider") if result else null

func _find_interactable(hit) -> Node:
	if hit == null:
		return null
	if hit.is_in_group("interactable"):
		return hit
	if hit.get_parent() and hit.get_parent().is_in_group("interactable"):
		return hit.get_parent()
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
			hints.append("[MMB] Throw — %d%%" % pct)
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
				var prefix = "[LMB/Hold]" if _is_product_shelf(current_target) else "[Click]"
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
				elif not build_mode.active and _is_product_shelf(current_target):
					current_target.interact()
					_shelf_lmb_active = true
					_shelf_lmb_was_active = true
					_shelf_lmb_timer = 0.0
			else:
				_shelf_lmb_active = false
				if not build_mode.active and _lmb_hold_time < LMB_HOLD_THRESHOLD and not _shelf_lmb_was_active:
					if current_target and current_target.has_method("try_trash"):
						current_target.try_trash(player_inventory)
					elif current_target and current_target.has_method("get_collectable_item_type"):
						var item_type: String = current_target.get_collectable_item_type()
						if item_type != "" and player_inventory.collect_item(item_type, current_target.global_position):
							current_target.clear_print()
					elif current_target and current_target.has_method("interact"):
						current_target.interact()
				_shelf_lmb_was_active = false
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
