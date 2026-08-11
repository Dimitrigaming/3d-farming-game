class_name GatherPerkDefinition
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var icon: Texture2D
@export var description: String = ""
## Which stat this perk feeds: "yield", "efficiency", or "luck"
@export var stat: String = "yield"
@export var value_per_point: float = 0.02
