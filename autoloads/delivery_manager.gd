extends Node

signal orders_changed
signal products_changed

const MAX_ORDERS: int = 10
const MIN_ORDER_INTERVAL: float = 10.0
const MAX_ORDER_INTERVAL: float = 10.0
const MIN_DEADLINE: float = 300.0
const MAX_DEADLINE: float = 600.0
const MIN_AMOUNT: int = 3
const MAX_AMOUNT: int = 10

# product_settings: { item_id -> { "enabled": bool, "price": float } }
var product_settings: Dictionary = {}
var active_orders: Array[Dictionary] = []

var _next_order_timer: float = 0.0

func _ready() -> void:
	_next_order_timer = 5.0

func _process(delta: float) -> void:
	var changed = false

	for order in active_orders:
		order["time_remaining"] -= delta
		if order["time_remaining"] <= 0.0:
			order["time_remaining"] = 0.0
			changed = true

	var before = active_orders.size()
	active_orders = active_orders.filter(func(o): return o["time_remaining"] > 0.0)
	if active_orders.size() != before:
		changed = true

	if active_orders.size() < MAX_ORDERS:
		_next_order_timer -= delta
		if _next_order_timer <= 0.0:
			if _get_enabled_ids().size() > 0:
				_generate_order()
				changed = true
			_next_order_timer = randf_range(MIN_ORDER_INTERVAL, MAX_ORDER_INTERVAL)

	if changed:
		orders_changed.emit()

func _get_enabled_ids() -> Array[String]:
	var result: Array[String] = []
	for id in product_settings:
		if product_settings[id]["enabled"]:
			result.append(id)
	return result

func _ensure_settings(item_id: String) -> void:
	if not item_id in product_settings:
		var def = ItemDB.get_item(item_id)
		product_settings[item_id] = {
			"enabled": false,
			"price": float(def.sell_price) if def else 1.0,
		}

func is_product_enabled(item_id: String) -> bool:
	return product_settings.get(item_id, {}).get("enabled", false)

func get_product_price(item_id: String) -> float:
	_ensure_settings(item_id)
	return product_settings[item_id]["price"]

func set_product_enabled(item_id: String, enabled: bool) -> void:
	_ensure_settings(item_id)
	product_settings[item_id]["enabled"] = enabled
	products_changed.emit()

func set_product_price(item_id: String, price: float) -> void:
	_ensure_settings(item_id)
	product_settings[item_id]["price"] = maxf(0.01, snappedf(price, 0.01))
	products_changed.emit()

func get_demand_percent(item_id: String) -> float:
	var def = ItemDB.get_item(item_id)
	if def == null or def.sell_price <= 0:
		return 0.0
	var market = float(def.sell_price)
	var player = get_product_price(item_id)
	return clampf(pow(market / player, 1.5) * 100.0, 5.0, 100.0)

func _generate_order() -> void:
	var pool = _get_enabled_ids()
	pool.shuffle()
	var item_id: String = pool[0]
	var def = ItemDB.get_item(item_id)
	if def == null:
		return
	var amount = randi_range(MIN_AMOUNT, MAX_AMOUNT)
	var player_price = get_product_price(item_id)
	var reward = player_price * amount
	active_orders.append({
		"item_id": item_id,
		"amount": amount,
		"time_remaining": randf_range(MIN_DEADLINE, MAX_DEADLINE),
		"reward": reward,
	})

## Fulfills an order from the shared delivery crate first, falling back to
## the player's own inventory for whatever the crate is short on.
func try_fulfill_order(order: Dictionary) -> bool:
	var crate = get_tree().get_first_node_in_group("delivery_crate")
	var inventory = get_tree().get_first_node_in_group("player_inventory_data")
	var needed: String = order["item_id"]
	var amount: int = order["amount"]

	var crate_found: int = 0
	if crate:
		for slot in crate.chest_slots:
			if slot["item_id"] == needed:
				crate_found += slot["amount"]
	var from_crate: int = min(crate_found, amount)
	var from_inventory: int = amount - from_crate

	if from_inventory > 0 and (inventory == null or not inventory.has_item(needed, from_inventory)):
		return false  # crate + inventory together still can't cover it

	if from_crate > 0:
		var to_remove: int = from_crate
		for i in crate.chest_slots.size():
			if to_remove <= 0:
				break
			if crate.chest_slots[i]["item_id"] == needed:
				var take = min(crate.chest_slots[i]["amount"], to_remove)
				crate.chest_slots[i]["amount"] -= take
				to_remove -= take
				if crate.chest_slots[i]["amount"] <= 0:
					crate.chest_slots[i] = {"item_id": "", "amount": 0}
		crate.refresh_ui()

	if from_inventory > 0:
		inventory.remove_item(needed, from_inventory)

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
