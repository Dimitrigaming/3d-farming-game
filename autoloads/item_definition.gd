class_name ItemDefinition
extends Resource

enum ItemType { SEED, CROP, ANIMAL_PRODUCT, PROCESSED, MATERIAL, TOOL }

@export var id: String = ""
@export var name: String = ""
@export var icon: Texture2D
@export var type: ItemType = ItemType.CROP
@export var max_stack: int = 99
@export var sell_price: int = 0
@export var buy_price: int = 0
@export var unlock_level: int = 1
@export var description: String = ""
@export var equip_scene: PackedScene
