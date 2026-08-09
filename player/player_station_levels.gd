class_name PlayerStationLevels
extends Node

## Per-player crafting-station progression. Separate from the shared shop
## level (GameState) -- every player levels up each station's XP on their
## own, so joining a shared farm late doesn't hand you someone else's
## unlocks for free.
##
## levels[station_type] = {"xp": int, "level": int}

const XP_PER_LEVEL: int = 100

var levels: Dictionary = {}

signal xp_gained(station_type: String, amount: int, new_xp: int)
signal level_up(station_type: String, new_level: int)

func _ready() -> void:
	add_to_group("player_station_levels")

func get_level(station_type: String) -> int:
	return levels.get(station_type, {}).get("level", 1)

func get_xp(station_type: String) -> int:
	return levels.get(station_type, {}).get("xp", 0)

func xp_to_next_level(station_type: String) -> int:
	return get_level(station_type) * XP_PER_LEVEL

func meets_requirement(station_type: String, required_level: int) -> bool:
	return get_level(station_type) >= required_level

func add_xp(station_type: String, amount: int) -> void:
	if amount <= 0:
		return
	if not levels.has(station_type):
		levels[station_type] = {"xp": 0, "level": 1}
	var entry = levels[station_type]
	entry["xp"] += amount
	xp_gained.emit(station_type, amount, entry["xp"])
	while entry["xp"] >= entry["level"] * XP_PER_LEVEL:
		entry["xp"] -= entry["level"] * XP_PER_LEVEL
		entry["level"] += 1
		level_up.emit(station_type, entry["level"])
