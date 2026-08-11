class_name PlayerGatheringPerks
extends Node

## Per-player gathering perk tree + enhancement crystal drops. Gathering
## levels (PlayerStationLevels, station_type="gathering") grant 1 perk
## point per level, uncapped -- spend them here on stat perks defined in
## GatherPerkDB (data/perks/*.tres).

const CRYSTAL_BASE_CHANCE: float = 0.03
const CRYSTAL_STATS: Array[String] = ["yield", "damage", "durability", "speed", "luck"]
const CRYSTAL_TIER_WEIGHTS: Array[float] = [0.65, 0.27, 0.08]  # tiers 1-3

## Each stat rolls a random percent within its tier's range (index 0 = tier 1).
## "yield" = bonus resources per gather, "damage" = bonus swing damage,
## "durability" = chance to not consume tool durability on a swing,
## "speed" = faster swing cadence, "luck" = bonus chance to find another crystal.
const CRYSTAL_TIER_RANGES: Dictionary = {
	"yield": [[0.05, 0.10], [0.12, 0.20], [0.22, 0.32]],
	"damage": [[0.10, 0.25], [0.26, 0.40], [0.41, 0.60]],
	"durability": [[0.05, 0.15], [0.16, 0.25], [0.26, 0.40]],
	"speed": [[0.05, 0.10], [0.11, 0.18], [0.19, 0.28]],
	"luck": [[0.03, 0.06], [0.07, 0.12], [0.13, 0.20]],
}

var spent_points: Dictionary = {}  # perk_id -> points_spent

signal perk_changed

@onready var station_levels: Node = get_node_or_null("../PlayerStationLevels")

func _ready() -> void:
	add_to_group("player_gathering_perks")

func total_spent() -> int:
	var total := 0
	for amount in spent_points.values():
		total += amount
	return total

func available_points() -> int:
	if station_levels == null:
		return 0
	var earned = max(0, station_levels.get_level("gathering") - 1)
	return earned - total_spent()

func get_points_spent(perk_id: String) -> int:
	return spent_points.get(perk_id, 0)

func spend_point(perk_id: String) -> bool:
	if available_points() <= 0:
		return false
	if GatherPerkDB.get_perk(perk_id) == null:
		return false
	spent_points[perk_id] = get_points_spent(perk_id) + 1
	perk_changed.emit()
	return true

func get_stat_bonus(stat: String) -> float:
	var bonus := 0.0
	for perk in GatherPerkDB.perks_for_stat(stat):
		bonus += get_points_spent(perk.id) * perk.value_per_point
	return bonus

func roll_crystal_drop() -> bool:
	var chance = CRYSTAL_BASE_CHANCE + get_stat_bonus("luck")
	return randf() < chance

func roll_crystal() -> Dictionary:
	var tier = _weighted_tier()
	var stat = CRYSTAL_STATS[randi() % CRYSTAL_STATS.size()]
	var range = CRYSTAL_TIER_RANGES[stat][tier - 1]
	var value = randf_range(range[0], range[1])
	return {"item_id": "enhancement_crystal", "amount": 1, "crystal_tier": tier, "crystal_stat": stat, "crystal_value": value}

func _weighted_tier() -> int:
	var roll = randf()
	var cumulative := 0.0
	for i in CRYSTAL_TIER_WEIGHTS.size():
		cumulative += CRYSTAL_TIER_WEIGHTS[i]
		if roll <= cumulative:
			return i + 1
	return CRYSTAL_TIER_WEIGHTS.size()
