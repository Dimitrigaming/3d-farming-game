extends StaticBody3D

@export var wood_type: String = "wood"
@export var drops_min: int = 2
@export var drops_max: int = 4
@export var tree_hp: int = 30
## Percentage of tool damage dealt when using the wrong tool (0.0 - 1.0)
@export_range(0.0, 1.0, 0.01) var wrong_tool_percent: float = 0.1
## Tool category required for full damage (e.g. "axe")
@export var required_tool_category: String = "axe"
## Seconds before the tree respawns after being chopped down
@export var respawn_time: float = 30.0
## How far the HP bar orbits from the trunk center, and at what height
@export var hp_bar_radius: float = 0.7
@export var hp_bar_height: float = 1.5
## The tree's visual scene, instantiated fresh under Visual (same pattern as
## mining_node.gd's stage_scenes, just a single entry).
@export var tree_scene: PackedScene

@onready var _visual: Node3D = $Visual
@onready var _progress_bar: ProgressBar = $SubViewport/HealthBar
@onready var _sprite_3d: Sprite3D = $Sprite3D
@onready var _collision: CollisionShape3D = $CollisionShape3D

var _hp: int = 0
var _bar_hide_timer: float = 0.0
const BAR_HIDE_DELAY: float = 10.0

func _ready() -> void:
	add_to_group("interactable")
	_hp = tree_hp
	_apply_tree()
	_sprite_3d.visible = false

func _apply_tree() -> void:
	for child in _visual.get_children():
		child.queue_free()
	if tree_scene != null:
		var mesh = tree_scene.instantiate()
		_visual.add_child(mesh)
	if _progress_bar:
		_progress_bar.value = 100.0

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

func get_click_hint(_inv) -> String:
	return "Chop (%s)" % required_tool_category.capitalize()

func interact() -> void:
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	if equipper == null:
		return
	var inventory = get_tree().get_first_node_in_group("player_inventory_data")
	if inventory == null:
		return
	var perks = get_tree().get_first_node_in_group("player_gathering_perks")

	var damage = 1
	if equipper.current_item_id != "":
		var def = ItemDB.get_item(equipper.current_item_id)
		if def and def.mining_damage > 0:
			if def.tool_category == required_tool_category:
				damage = def.mining_damage
			else:
				damage = max(1, int(def.mining_damage * wrong_tool_percent))
	damage = GatherBonuses.apply_damage(damage, inventory, equipper, perks)

	_hp -= damage
	if equipper.current_slot_index >= 0 and not GatherBonuses.should_spare_durability(inventory, equipper, perks):
		inventory.damage_hotbar_tool(equipper.current_slot_index)
	_update_hp_bar()

	if _hp > 0:
		return

	var amount = GatherBonuses.apply_yield(randi_range(drops_min, drops_max), inventory, equipper, perks)
	inventory.add_item(wood_type, amount)
	GatherBonuses.grant_gather_xp(wood_type, amount)
	GatherBonuses.roll_and_grant_crystal(inventory, perks)
	_despawn()

func _despawn() -> void:
	for child in _visual.get_children():
		child.queue_free()
	_sprite_3d.visible = false
	_collision.disabled = true
	remove_from_group("interactable")
	await get_tree().create_timer(respawn_time).timeout
	_respawn()

func _respawn() -> void:
	_hp = tree_hp
	_collision.disabled = false
	_sprite_3d.visible = false
	add_to_group("interactable")
	_apply_tree()

func _update_hp_bar() -> void:
	if _progress_bar == null or _sprite_3d == null:
		return
	_sprite_3d.visible = true
	_progress_bar.visible = true
	_progress_bar.value = clampf(float(_hp) / float(tree_hp), 0.0, 1.0) * 100.0
	_bar_hide_timer = BAR_HIDE_DELAY
