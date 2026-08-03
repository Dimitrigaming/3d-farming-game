extends Node

const SLOT_COUNT = 45
const HOTBAR_START = 36
const HOTBAR_SIZE = 9

var slots: Array[Dictionary] = []

signal inventory_changed

func _ready() -> void:
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = _empty_slot()

func add_item(item_id: String, amount: int = 1) -> bool:
	# Try to stack onto existing slot first
	for slot in slots:
		if slot["item_id"] == item_id:
			slot["amount"] += amount
			inventory_changed.emit()
			return true
	# Find empty slot
	for slot in slots:
		if slot["item_id"] == "":
			slot["item_id"] = item_id
			slot["amount"] = amount
			inventory_changed.emit()
			return true
	return false  # inventory full

func remove_item(item_id: String, amount: int = 1) -> bool:
	for i in slots.size():
		if slots[i]["item_id"] == item_id:
			slots[i]["amount"] -= amount
			if slots[i]["amount"] <= 0:
				slots[i] = _empty_slot()
			inventory_changed.emit()
			return true
	return false

func has_item(item_id: String, amount: int = 1) -> bool:
	var total := 0
	for slot in slots:
		if slot["item_id"] == item_id:
			total += slot["amount"]
	return total >= amount

func swap_slots(a: int, b: int) -> void:
	var tmp = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	inventory_changed.emit()

func _empty_slot() -> Dictionary:
	return {"item_id": "", "amount": 0}
