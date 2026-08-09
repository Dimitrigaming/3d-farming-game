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
	var tools = ["hoe", "shovel", "axe", "pickaxe", "hammer", "scythe", "crafting_workbench", "forge"]
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

func add_item(item_id: String, amount: int = 1) -> bool:
	# Try to stack onto existing slot first
	for slot in slots:
		if slot["item_id"] == item_id:
			slot["amount"] += amount
			inventory_changed.emit()
			item_acquired.emit(item_id, amount)
			return true
	# Find empty slot
	for slot in slots:
		if slot["item_id"] == "":
			slot["item_id"] = item_id
			slot["amount"] = amount
			var def = ItemDB.get_item(item_id)
			slot["durability"] = def.max_durability if def and def.max_durability > 0 else -1
			inventory_changed.emit()
			item_acquired.emit(item_id, amount)
			return true
	return false  # inventory full

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

func remove_item(item_id: String, amount: int = 1) -> bool:
	for i in slots.size():
		if slots[i]["item_id"] == item_id:
			slots[i]["amount"] -= amount
			if slots[i]["amount"] <= 0:
				slots[i] = _empty_slot()
			inventory_changed.emit()
			return true
	for i in hotbar_slots.size():
		if hotbar_slots[i]["item_id"] == item_id:
			hotbar_slots[i]["amount"] -= amount
			if hotbar_slots[i]["amount"] <= 0:
				hotbar_slots[i] = _empty_slot()
			inventory_changed.emit()
			return true
	return false

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
	return {"item_id": "", "amount": 0, "durability": -1}
