extends Node3D

## Which recipes this station offers: recipe.station_type == station_type.
@export var station_type: String = "workbench"
## Number of output slots.
@export var output_slot_count: int = 18

const CRAFTING_UI_SCENE = preload("res://ui/crafting_ui.tscn")

## Queue entries: {"recipe_id": String, "count": int}
var queue: Array[Dictionary] = []
## Same shape as Inventory.slots entries, minus durability (output is never a tool).
var output_slots: Array[Dictionary] = []

var _crafting_ui: CanvasLayer = null
var _is_crafting: bool = false
var _craft_progress: float = 0.0  # 0..1, progress of queue[0]
var _craft_tween: Tween = null

signal queue_changed
signal output_changed

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("crafting_station")
	output_slots.resize(output_slot_count)
	for i in output_slot_count:
		output_slots[i] = {"item_id": "", "amount": 0}
	_setup_ui()

func _setup_ui() -> void:
	_crafting_ui = CRAFTING_UI_SCENE.instantiate()
	get_tree().get_root().call_deferred("add_child", _crafting_ui)

func interact() -> void:
	if _crafting_ui:
		_crafting_ui.open_crafting(self)

func get_interact_hint() -> String:
	return "Craft"

## Returns true if the craft was accepted (enough ingredients, valid recipe).
func craft(recipe_id: String, qty: int = 1) -> bool:
	if qty <= 0:
		return false
	var recipe = RecipeDB.get_recipe(recipe_id)
	if recipe == null or recipe.station_type != station_type:
		return false

	for ingredient in recipe.ingredients:
		if not Inventory.has_item(ingredient.item_id, ingredient.amount * qty):
			return false

	for ingredient in recipe.ingredients:
		for i in ingredient.amount * qty:
			Inventory.remove_item(ingredient.item_id, 1)

	for entry in queue:
		if entry["recipe_id"] == recipe_id:
			entry["count"] += qty
			queue_changed.emit()
			_process_queue()
			return true

	queue.append({"recipe_id": recipe_id, "count": qty})
	queue_changed.emit()
	_process_queue()
	return true

func get_craft_progress() -> float:
	return _craft_progress

func _process_queue() -> void:
	if _is_crafting or queue.is_empty():
		return
	var entry = queue[0]
	var recipe = RecipeDB.get_recipe(entry["recipe_id"])
	if recipe == null:
		queue.remove_at(0)
		queue_changed.emit()
		_process_queue()
		return

	_is_crafting = true
	_craft_progress = 0.0

	var duration = max(recipe.craft_time, 0.01)
	_craft_tween = create_tween()
	_craft_tween.tween_method(
		func(p: float): _craft_progress = p; queue_changed.emit(),
		0.0, 1.0, duration
	)
	_craft_tween.tween_callback(_on_craft_complete.bind(recipe))

func _on_craft_complete(recipe: RecipeDefinition) -> void:
	if recipe.craft_time > 0.0:
		_add_to_output(recipe.output_item_id, recipe.output_amount)
	else:
		# Instant recipes skip the output buffer entirely.
		Inventory.add_item(recipe.output_item_id, recipe.output_amount)
	output_changed.emit()

	if not queue.is_empty():
		queue[0]["count"] -= 1
		if queue[0]["count"] <= 0:
			queue.remove_at(0)
	queue_changed.emit()

	_is_crafting = false
	_craft_progress = 0.0
	_process_queue()

func _add_to_output(item_id: String, amount: int) -> bool:
	for slot in output_slots:
		if slot["item_id"] == item_id:
			slot["amount"] += amount
			return true
	for slot in output_slots:
		if slot["item_id"] == "":
			slot["item_id"] = item_id
			slot["amount"] = amount
			return true
	return false  # output full
