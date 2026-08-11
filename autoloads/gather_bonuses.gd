extends Node

## Shared helper for the three gather sites (tree_node.gd, mining_node.gd,
## player_interaction.gd) so XP granting, crystal rolls, and perk/socket
## stat bonuses aren't duplicated three times over.

func _socketed_bonus(inventory: Node, equipper: Node, stat: String) -> float:
	if inventory == null or equipper == null or equipper.current_slot_index < 0:
		return 0.0
	var slot = inventory.hotbar_slots[equipper.current_slot_index]
	var bonus := 0.0
	for crystal in slot.get("sockets", []):
		if crystal.get("stat", "") == stat:
			bonus += float(crystal.get("value", 0.0))
	return bonus

func apply_yield(base_amount: int, inventory: Node, equipper: Node, perks: Node) -> int:
	var bonus := _socketed_bonus(inventory, equipper, "yield")
	if perks:
		bonus += perks.get_stat_bonus("yield")
	return max(1, int(round(base_amount * (1.0 + bonus))))

func apply_damage(base_value: int, inventory: Node, equipper: Node, perks: Node) -> int:
	var bonus := _socketed_bonus(inventory, equipper, "damage")
	if perks:
		bonus += perks.get_stat_bonus("damage")
	return max(1, int(round(base_value * (1.0 + bonus))))

## Returns true if the tool's durability should be spared this swing (rolled
## against the "durability" stat from perks + socketed crystals).
func should_spare_durability(inventory: Node, equipper: Node, perks: Node) -> bool:
	var chance := _socketed_bonus(inventory, equipper, "durability")
	if perks:
		chance += perks.get_stat_bonus("durability")
	return randf() < chance

## Shrinks a base swing/hit interval based on the "speed" stat -- used to
## speed up the held-click gather cadence in interaction_manager.gd.
func apply_speed_interval(base_interval: float, inventory: Node, equipper: Node, perks: Node) -> float:
	var bonus := _socketed_bonus(inventory, equipper, "speed")
	if perks:
		bonus += perks.get_stat_bonus("speed")
	return max(0.1, base_interval / (1.0 + bonus))

func grant_gather_xp(item_id: String, amount: int) -> void:
	var levels = get_tree().get_first_node_in_group("player_station_levels")
	if levels == null:
		return
	var def = ItemDB.get_item(item_id)
	var value = def.sell_price if def else 1
	levels.add_xp("gathering", max(1, value) * amount)

func roll_and_grant_crystal(inventory: Node, perks: Node) -> void:
	if inventory == null or perks == null:
		return
	if not perks.roll_crystal_drop():
		return
	var crystal = perks.roll_crystal()
	inventory.add_item(crystal["item_id"], crystal["amount"], {
		"crystal_tier": crystal["crystal_tier"],
		"crystal_stat": crystal["crystal_stat"],
		"crystal_value": crystal["crystal_value"],
	})
