extends Node

signal orders_changed
signal products_changed

const MAX_ORDERS: int = 3
const MIN_ORDER_INTERVAL: float = 120.0
const MAX_ORDER_INTERVAL: float = 300.0
const MIN_DEADLINE: float = 300.0
const MAX_DEADLINE: float = 600.0
const MIN_AMOUNT: int = 3
const MAX_AMOUNT: int = 10

var enabled_products: Array[String] = []
var active_orders: Array[Dictionary] = []

var _next_order_timer: float = 0.0

func _ready() -> void:
	_next_order_timer = randf_range(MIN_ORDER_INTERVAL, MAX_ORDER_INTERVAL)

func _process(delta: float) -> void:
	var changed = false

	# Count down deadlines
	for order in active_orders:
		order["time_remaining"] -= delta
		if order["time_remaining"] <= 0.0:
			order["time_remaining"] = 0.0
			changed = true

	# Remove expired orders
	var before = active_orders.size()
	active_orders = active_orders.filter(func(o): return o["time_remaining"] > 0.0)
	if active_orders.size() != before:
		changed = true

	# Generate new order
	if active_orders.size() < MAX_ORDERS and not enabled_products.is_empty():
		_next_order_timer -= delta
		if _next_order_timer <= 0.0:
			_generate_order()
			_next_order_timer = randf_range(MIN_ORDER_INTERVAL, MAX_ORDER_INTERVAL)
			changed = true

	if changed:
		orders_changed.emit()

func _generate_order() -> void:
	var pool = enabled_products.duplicate()
	pool.shuffle()
	var item_id: String = pool[0]
	var def = ItemDB.get_item(item_id)
	if def == null:
		return
	var amount = randi_range(MIN_AMOUNT, MAX_AMOUNT)
	var reward = def.sell_price * amount * 1.5
	active_orders.append({
		"item_id": item_id,
		"amount": amount,
		"time_remaining": randf_range(MIN_DEADLINE, MAX_DEADLINE),
		"reward": reward,
	})

func set_product_enabled(item_id: String, enabled: bool) -> void:
	if enabled:
		if not item_id in enabled_products:
			enabled_products.append(item_id)
	else:
		enabled_products.erase(item_id)
	products_changed.emit()

func try_fulfill_order(order: Dictionary) -> bool:
	var crate = get_tree().get_first_node_in_group("delivery_crate")
	if crate == null:
		return false
	var needed: String = order["item_id"]
	var amount: int = order["amount"]
	var total_found: int = 0
	# Count available in crate
	for slot in crate.crate_slots:
		if slot["item_id"] == needed:
			total_found += slot["amount"]
	if total_found < amount:
		return false
	# Remove items from crate
	var to_remove: int = amount
	for i in crate.crate_slots.size():
		if to_remove <= 0:
			break
		if crate.crate_slots[i]["item_id"] == needed:
			var take = min(crate.crate_slots[i]["amount"], to_remove)
			crate.crate_slots[i]["amount"] -= take
			to_remove -= take
			if crate.crate_slots[i]["amount"] <= 0:
				crate.crate_slots[i] = {"item_id": "", "amount": 0}
	crate.refresh_ui()
	# Pay reward
	GameState.add_money(order["reward"])
	active_orders.erase(order)
	_next_order_timer = randf_range(MIN_ORDER_INTERVAL, MAX_ORDER_INTERVAL)
	orders_changed.emit()
	return true

func get_sellable_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item in ItemDB.all_items():
		if item.sell_price > 0 and item.type != ItemDefinition.ItemType.SEED \
				and item.type != ItemDefinition.ItemType.TOOL \
				and item.type != ItemDefinition.ItemType.FURNITURE:
			result.append(item)
	result.sort_custom(func(a, b): return a.name < b.name)
	return result
