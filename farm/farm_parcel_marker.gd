extends StaticBody3D

## Placeable "purchase sign" for a locked farm parcel -- the corner piece
## of the fence kit (see farm_fence_post.gd/.tscn for the plain segments).
## Set parcel_index per-instance in the Inspector, same as the fence posts.

@export var parcel_index: int = 1
## When off, cost uses GameState's default geometric formula. Toggle on to
## hand-price this specific parcel with price_override instead.
@export var use_price_override: bool = false
@export var price_override: float = 1000.0

@onready var label: Label3D = $PriceLabel

func _ready() -> void:
	add_to_group("interactable")
	if parcel_index < GameState.farm_parcels_unlocked:
		queue_free()
		return
	label.text = _label_text()
	GameState.farm_parcel_unlocked.connect(_on_parcel_unlocked)

func _on_parcel_unlocked(new_count: int) -> void:
	if parcel_index < new_count:
		queue_free()

func _cost() -> float:
	return price_override if use_price_override else GameState.get_farm_parcel_cost(parcel_index)

func _label_text() -> String:
	return "Unlock Parcel - $%d" % int(_cost())

func get_interact_hint() -> String:
	return _label_text()

func interact() -> void:
	if GameState.unlock_farm_parcel_with_cost(_cost()):
		queue_free()
		return
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Not enough money!")
