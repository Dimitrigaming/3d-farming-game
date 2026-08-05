extends StaticBody3D

## Which item drops when fully mined
@export var ore_type: String = "stone"
@export var drops_min: int = 2
@export var drops_max: int = 4
## Hits required to advance each stage
@export var hits_per_stage: int = 3
## Tool item_id required to mine (empty = any tool works)
@export var required_tool: String = "pickaxe"
## Scenes for each stage, index 0 = largest, last = smallest
@export var stage_scenes: Array[PackedScene] = []

@onready var _visual: Node3D = $Visual

var _stage: int = 0
var _hits: int = 0

func _ready() -> void:
	add_to_group("interactable")
	_apply_stage()

func _apply_stage() -> void:
	for child in _visual.get_children():
		child.queue_free()
	if _stage < stage_scenes.size() and stage_scenes[_stage] != null:
		var mesh = stage_scenes[_stage].instantiate()
		_visual.add_child(mesh)

func get_click_hint(_inv) -> String:
	if required_tool != "":
		var def = ItemDB.get_item(required_tool)
		var tool_name = def.name if def else required_tool.capitalize()
		return "Mine (%s)" % tool_name
	return "Mine"

func interact() -> void:
	if required_tool != "":
		var equipper = get_tree().get_first_node_in_group("tool_equipper")
		if equipper == null or equipper.current_item_id != required_tool:
			return

	_hits += 1
	if _hits < hits_per_stage:
		return

	_hits = 0
	_stage += 1

	if _stage >= stage_scenes.size():
		Inventory.add_item(ore_type, randi_range(drops_min, drops_max))
		queue_free()
	else:
		_apply_stage()
