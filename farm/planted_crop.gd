class_name PlantedCrop
extends Area3D

## Aim-at-the-plant hitbox, not a tile lookup -- the player's raycast has
## to actually land on the crop's own collider (collide_with_areas is on)
## instead of resolving whichever crop sits on the ground tile it hit.
const HITBOX_SIZE := Vector3(0.8, 1.2, 0.8)
const HITBOX_CENTER_Y := 0.6

var crop_def: CropDefinition = null
var stage: int = 0
## Farm grid cell this crop is planted in -- set by farm_grid.gd right
## after instantiation, used to route harvest/chop back through the grid.
var cell: Vector3i = Vector3i.ZERO
var _timer: float = 0.0
var _model: Node3D = null

func _ready() -> void:
	add_to_group("planted_crop")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = HITBOX_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, HITBOX_CENTER_Y, 0.0)
	add_child(shape)

func setup(def: CropDefinition) -> void:
	crop_def = def
	_set_stage(0)

func _process(delta: float) -> void:
	if crop_def == null:
		return
	if stage >= crop_def.growth_stages.size() - 1:
		return
	var stages_to_grow: int = crop_def.growth_stages.size() - 1
	var time_per_stage: float = crop_def.base_grow_speed / max(stages_to_grow, 1)
	_timer += delta
	if _timer >= time_per_stage:
		_timer = 0.0
		_set_stage(stage + 1)

func _set_stage(new_stage: int) -> void:
	stage = new_stage
	if _model:
		_model.queue_free()
		_model = null
	if crop_def == null or stage >= crop_def.growth_stages.size():
		return
	var packed: PackedScene = crop_def.growth_stages[stage]
	if packed:
		_model = packed.instantiate()
		add_child(_model)

func is_ready_to_harvest() -> bool:
	if crop_def == null:
		return false
	return stage >= crop_def.growth_stages.size() - 1

func harvest(tool_id: String = "") -> Dictionary:
	if crop_def == null:
		return {}
	var bonus: int = 0
	if crop_def.harvest_tools.size() > 0 and tool_id == crop_def.harvest_tools[0]:
		bonus = crop_def.primary_yield_bonus
	if crop_def.can_regrow and crop_def.regrow_stages > 0:
		_set_stage(max(0, stage - crop_def.regrow_stages))
		_timer = 0.0
	return {"item_id": crop_def.yield_item_id, "amount": crop_def.yield_amount + bonus}

func chop() -> Dictionary:
	if crop_def == null:
		return {}
	return {"item_id": crop_def.chop_yield_item_id, "amount": crop_def.chop_wood_yield}
