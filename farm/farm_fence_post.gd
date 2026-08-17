extends StaticBody3D

## Modular locked-parcel fence piece -- place these by hand around a
## parcel's border, the same way the city sidewalk kit's straight pieces
## are placed. Set parcel_index per-instance in the Inspector to the
## parcel this piece blocks off; it removes itself automatically once
## that parcel unlocks (or immediately if already unlocked on load).

@export var parcel_index: int = 1

func _ready() -> void:
	if parcel_index < GameState.farm_parcels_unlocked:
		queue_free()
		return
	GameState.farm_parcel_unlocked.connect(_on_parcel_unlocked)

func _on_parcel_unlocked(new_count: int) -> void:
	if parcel_index < new_count:
		queue_free()
