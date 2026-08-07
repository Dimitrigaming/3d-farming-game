extends StaticBody3D

@export var ore_type: String = "stone"
@export var drops_min: int = 2
@export var drops_max: int = 4
## HP shared across all stages; resets each time a stage advances
@export var stage_hp: int = 10
## Percentage of tool damage dealt when using the wrong tool (0.0 - 1.0)
@export_range(0.0, 1.0, 0.01) var wrong_tool_percent: float = 0.1
## Tool category required for full damage (e.g. "pickaxe")
@export var required_tool_category: String = "pickaxe"
## Scenes for each stage, index 0 = largest/full, last = nearly depleted
@export var stage_scenes: Array[PackedScene] = []
## Seconds before the node respawns after being fully mined
@export var respawn_time: float = 20.0
## How far the HP bar orbits from the node center, and at what height
@export var hp_bar_radius: float = 0.9
@export var hp_bar_height: float = 1.1

@onready var _visual: Node3D = $Visual
@onready var _progress_bar: ProgressBar = $SubViewport/HealthBar
@onready var _sprite_3d: Sprite3D = $Sprite3D
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _stage: int = 0
var _hp: int = 0
var _bar_hide_timer: float = 0.0
const BAR_HIDE_DELAY: float = 10.0

func _ready() -> void:
	add_to_group("interactable")
	_hp = stage_hp
	_apply_stage()
	_sprite_3d.visible = false

func _process(delta: float) -> void:
	if _sprite_3d.visible:
		_bar_hide_timer -= delta
		if _bar_hide_timer <= 0.0:
			_sprite_3d.visible = false
		_update_hp_bar_position()

func _update_hp_bar_position() -> void:
	var cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	var dir = cam.global_position - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	_sprite_3d.global_position = global_position + Vector3(0, hp_bar_height, 0) + dir * hp_bar_radius

func _apply_stage() -> void:
	for child in _visual.get_children():
		child.queue_free()
	if _stage < stage_scenes.size() and stage_scenes[_stage] != null:
		var mesh = stage_scenes[_stage].instantiate()
		_visual.add_child(mesh)
	if _progress_bar:
		_progress_bar.value = 100.0

func get_click_hint(_inv) -> String:
	return "Mine (%s)" % required_tool_category.capitalize()

func interact() -> void:
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if equipper == null:
		return

	var damage = 1
	if equipper.current_item_id != "":
		var def = ItemDB.get_item(equipper.current_item_id)
		if def and def.mining_damage > 0:
			if def.tool_category == required_tool_category:
				damage = def.mining_damage
			else:
				damage = max(1, int(def.mining_damage * wrong_tool_percent))

	_hp -= damage
	if equipper.current_slot_index >= 0:
		Inventory.damage_hotbar_tool(equipper.current_slot_index)
	_update_hp_bar()

	if _hp > 0:
		return

	Inventory.add_item(ore_type, randi_range(drops_min, drops_max))
	_stage += 1
	if _stage >= stage_scenes.size():
		_despawn()
	else:
		_hp = stage_hp
		_apply_stage()

func _despawn() -> void:
	_visual.visible = false
	_sprite_3d.visible = false
	_collision.disabled = true
	remove_from_group("interactable")
	await get_tree().create_timer(respawn_time).timeout
	_respawn()

func _respawn() -> void:
	_stage = 0
	_hp = stage_hp
	_visual.visible = true
	_collision.disabled = false
	_sprite_3d.visible = false
	add_to_group("interactable")
	_apply_stage()

func _update_hp_bar() -> void:
	if _progress_bar == null or _sprite_3d == null:
		return
	_sprite_3d.visible = true
	_progress_bar.visible = true
	_progress_bar.value = clampf(float(_hp) / float(stage_hp), 0.0, 1.0) * 100.0
	_bar_hide_timer = BAR_HIDE_DELAY
