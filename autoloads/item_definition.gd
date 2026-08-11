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
## Uniform scale applied to equip_scene when held in hand. Lets place_scene
## be reused directly as equip_scene without a separate scaled-down duplicate.
@export var equip_scale: float = 1.0
@export var place_scene: PackedScene
## Degrees added on top of the player's facing when freshly deployed, to
## compensate for place_scene's model being authored with its front along
## +Z instead of the usual -Z forward convention.
@export var place_rotation_offset: float = 0.0

# Tool stats — leave at defaults for non-tool items
@export var tool_category: String = ""  # "pickaxe", "axe", "hoe", etc.
@export var mining_damage: int = 0      # damage dealt per swing to a mining node
@export var max_durability: int = 0     # 0 = unbreakable
@export var socket_count: int = 1       # enhancement crystal sockets, tools only
