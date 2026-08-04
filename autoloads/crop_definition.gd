class_name CropDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var seed_item_id: String = ""
@export var yield_item_id: String = ""
@export var yield_amount: int = 1
@export var base_grow_speed: float = 60.0
@export var water_speed_multiplier: float = 1.5
@export var can_regrow: bool = false
@export var regrow_stages: int = 1
@export var is_tree: bool = false
@export var chop_wood_yield: int = 3
@export var growth_stages: Array[PackedScene] = []
