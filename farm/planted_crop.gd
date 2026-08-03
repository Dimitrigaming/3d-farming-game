class_name PlantedCrop
extends Node3D

var crop_def: CropDefinition = null
var stage: int = 0
var _timer: float = 0.0
var _model: Node3D = null

func setup(def: CropDefinition) -> void:
	crop_def = def
	_set_stage(0)

func _process(delta: float) -> void:
	if crop_def == null:
		return
	if stage >= crop_def.growth_stages.size() - 1:
		return
	_timer += delta
	if _timer >= crop_def.base_grow_speed:
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

func harvest() -> String:
	if crop_def == null:
		return ""
	return crop_def.yield_item_id
