class_name RecipeDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var icon: Texture2D
@export var description: String = ""

@export var output_item_id: String = ""
@export var output_amount: int = 1

@export var ingredients: Array[RecipeIngredient] = []

## Which station kind can craft this: "workbench", "forge", "cooking", etc.
@export var station_type: String = "workbench"
## Seconds to craft. 0 = instant.
@export var craft_time: float = 0.0
