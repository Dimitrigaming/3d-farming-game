class_name ItemDefinition
extends Resource

enum ItemType { SEED, CROP, ANIMAL_PRODUCT, PROCESSED, MATERIAL, TOOL, TREE, FURNITURE }

@export var id: String = ""
@export var name: String = ""
@export var icon: Texture2D
@export var type: ItemType = ItemType.CROP
@export var max_stack: int = 99
@export var sell_price: int = 0
@export var buy_price: int = 0
@export var unlock_level: int = 1
enum Subcategory { NONE, LOG, PLANK, STONE, ORE, INGOT, GRAIN, VEGETABLE, FRUIT, DAIRY, EGG, MEAT }
@export var subcategory: Subcategory = Subcategory.NONE
@export var description: String = ""
@export var equip_scene: PackedScene
@export var place_scene: PackedScene

# Tool stats — leave at defaults for non-tool items
@export var tool_category: String = ""  # "pickaxe", "axe", "hoe", etc.
@export var mining_damage: int = 0      # damage dealt per swing to a mining node
@export var max_durability: int = 0     # 0 = unbreakable
