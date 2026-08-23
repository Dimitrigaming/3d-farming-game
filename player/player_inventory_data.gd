class_name PlayerInventoryData
extends Node

## Per-player inventory/hotbar state. Was previously a global `Inventory`
## autoload; moved onto the player so each player owns their own inventory
## (multiplayer foundation — see plan "Per-Player Refactor").

const SLOT_COUNT = 36
const HOTBAR_SIZE = 9

var slots: Array[Dictionary] = []
var hotbar_slots: Array[Dictionary] = []

signal inventory_changed
signal item_acquired(item_id: String, amount: int)

func _ready() -> void:
	add_to_group("player_inventory_data")
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = _empty_slot()
	hotbar_slots.resize(HOTBAR_SIZE)
	for i in HOTBAR_SIZE:
		hotbar_slots[i] = _empty_slot()
	_give_starter_tools()

func _give_starter_tools() -> void:
	var tools = ["hoe_rusty", "shovel_rusty", "axe_rusty", "pickaxe_rusty", "hammer_rusty", "scythe_rusty", "crafting_workbench", "forge"]
	for i in tools.size():
		var slot = hotbar_slots[i]
		slot["item_id"] = tools[i]
		slot["amount"] = 1
	add_item("wood", 99)
	add_item("stone", 99)
	add_item("copper_ore", 99)
	add_item("iron_ore", 99)
	add_item("coal_ore", 99)
	inventory_changed.emit()

func add_item(item_id: String, amount: int = 1, extra_data: Dictionary = {}) -> bool:
	var def = ItemDB.get_item(item_id)
	var max_stack = def.max_stack if def and def.max_stack > 0 else 99
	var remaining = amount
	var placed_any = false

	# Per-instance data (e.g. rolled crystal tier/stat) forces its own slot --
	# never stacks onto an existing slot even if the item_id matches.
	if extra_data.is_empty():
		# Top up any existing slots that still have room, capped at max_stack.
		for slot in slots:
			if remaining <= 0:
				break
			if slot["item_id"] == item_id and slot["amount"] < max_stack:
				var space = max_stack - slot["amount"]
				var take = min(space, remaining)
				slot["amount"] += take
				remaining -= take
				placed_any = true

	# Spill any leftover into empty slots, capped at max_stack per slot.
	while remaining > 0:
		var free_slot = null
		for slot in slots:
			if slot["item_id"] == "":
				free_slot = slot
				break
		if free_slot == null:
			break  # inventory full
		var take = min(max_stack, remaining)
		free_slot["item_id"] = item_id
		free_slot["amount"] = take
		free_slot["durability"] = def.max_durability if def and def.max_durability > 0 else -1
		for key in extra_data:
			free_slot[key] = extra_data[key]
		remaining -= take
		placed_any = true

	if placed_any:
		inventory_changed.emit()
		item_acquired.emit(item_id, amount - remaining)
	return placed_any

func damage_tool(slot_index: int) -> void:
	var slot = slots[slot_index]
	if slot["item_id"] == "" or slot["durability"] == -1:
		return
	slot["durability"] -= 1
	if slot["durability"] <= 0:
		slots[slot_index] = _empty_slot()
	inventory_changed.emit()

func damage_hotbar_tool(slot_index: int) -> void:
	var slot = hotbar_slots[slot_index]
	if slot["item_id"] == "" or slot["durability"] == -1:
		return
	slot["durability"] -= 1
	if slot["durability"] <= 0:
		hotbar_slots[slot_index] = _empty_slot()
	inventory_changed.emit()

## Removes up to `amount` total across every matching stack (inventory then
## hotbar), not just the first one -- previously this only touched the first
## matching slot, which could under-remove (or silently "succeed" without
## actually removing everything) whenever a stack was split across slots.
func remove_item(item_id: String, amount: int = 1) -> bool:
	var remaining = amount
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i]["item_id"] == item_id:
			var take = min(slots[i]["amount"], remaining)
			slots[i]["amount"] -= take
			remaining -= take
			if slots[i]["amount"] <= 0:
				slots[i] = _empty_slot()
	for i in hotbar_slots.size():
		if remaining <= 0:
			break
		if hotbar_slots[i]["item_id"] == item_id:
			var take = min(hotbar_slots[i]["amount"], remaining)
			hotbar_slots[i]["amount"] -= take
			remaining -= take
			if hotbar_slots[i]["amount"] <= 0:
				hotbar_slots[i] = _empty_slot()
	if remaining < amount:
		inventory_changed.emit()
	return remaining == 0

func has_item(item_id: String, amount: int = 1) -> bool:
	var total := 0
	for slot in slots:
		if slot["item_id"] == item_id:
			total += slot["amount"]
	for slot in hotbar_slots:
		if slot["item_id"] == item_id:
			total += slot["amount"]
	return total >= amount

func swap_slots(a: int, b: int) -> void:
	var tmp = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	inventory_changed.emit()

func _empty_slot() -> Dictionary:
	return {"item_id": "", "amount": 0, "durability": -1, "sockets": []}
