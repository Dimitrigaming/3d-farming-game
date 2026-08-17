extends Node

signal money_changed(new_amount: float)
signal license_unlocked(license_id: String)
signal print_job_added(job: Dictionary)
signal print_job_completed(job: Dictionary)
signal shop_xp_gained(amount: int, new_xp: int)
signal shop_level_up(new_level: int)
signal farm_parcel_unlocked(new_count: int)

var money: float = 100000.0      # 500.0
var blocks_unlocked: int = 0

## Shared shop level -- every player contributes to and sees the same
## progress, earned from selling goods (register checkout, delivery orders).
const SHOP_XP_PER_LEVEL: int = 100
var shop_xp: int = 0
var shop_level: int = 1

func shop_xp_to_next_level() -> int:
	return shop_level * SHOP_XP_PER_LEVEL

func add_shop_xp(amount: int) -> void:
	if amount <= 0:
		return
	shop_xp += amount
	shop_xp_gained.emit(amount, shop_xp)
	while shop_xp >= shop_level * SHOP_XP_PER_LEVEL:
		shop_xp -= shop_level * SHOP_XP_PER_LEVEL
		shop_level += 1
		shop_level_up.emit(shop_level)

var shop_floor_tier: int = 0
var production_floor_tier: int = 0

const SHOP_FLOOR_COSTS = [300.0, 800.0, 1500.0, 2500.0, 4000.0]
const PRODUCTION_FLOOR_COSTS = [400.0, 1000.0, 1800.0, 3000.0, 5000.0]
const MAX_ROOM_TIER: int = 5

func upgrade_shop_floor() -> bool:
	if shop_floor_tier >= MAX_ROOM_TIER:
		return false
	if not spend_money(SHOP_FLOOR_COSTS[shop_floor_tier]):
		return false
	shop_floor_tier += 1
	get_node_or_null("/root/GameLogger").info("GameState", "shop floor upgraded to tier %d" % shop_floor_tier)
	return true

func upgrade_production_floor() -> bool:
	if production_floor_tier >= MAX_ROOM_TIER:
		return false
	if not spend_money(PRODUCTION_FLOOR_COSTS[production_floor_tier]):
		return false
	production_floor_tier += 1
	get_node_or_null("/root/GameLogger").info("GameState", "production floor upgraded to tier %d" % production_floor_tier)
	return true

## Shared farm land expansion -- parcel 0 (the starter plot) is unlocked by
## default; every parcel after that is purely a money sink (no level gate),
## with cost climbing geometrically so later expansions require real profit,
## not just grinding levels. Unbounded -- place as many
## farm/farm_expansion_area.tscn instances as you want, each with its own
## sequential parcel_index.
var farm_parcels_unlocked: int = 1
const FARM_PARCEL_BASE_COST: float = 1000.0
const FARM_PARCEL_COST_MULTIPLIER: float = 3.0

func get_farm_parcel_cost(parcel_index: int) -> float:
	return FARM_PARCEL_BASE_COST * pow(FARM_PARCEL_COST_MULTIPLIER, parcel_index - 1)

func can_unlock_farm_parcel() -> bool:
	return money >= get_farm_parcel_cost(farm_parcels_unlocked)

func unlock_farm_parcel() -> bool:
	return unlock_farm_parcel_with_cost(get_farm_parcel_cost(farm_parcels_unlocked))

## Same as unlock_farm_parcel(), but for a sign that overrides the default
## geometric cost with its own hand-set price (see farm_parcel_marker.gd's
## price_override).
func unlock_farm_parcel_with_cost(cost: float) -> bool:
	if not spend_money(cost):
		return false
	farm_parcels_unlocked += 1
	get_node_or_null("/root/GameLogger").info("GameState", "farm parcel unlocked -> total=%d" % farm_parcels_unlocked)
	farm_parcel_unlocked.emit(farm_parcels_unlocked)
	return true

func get_next_unlock_price() -> int:
	return 10

func unlock_block() -> bool:
	var price = get_next_unlock_price()
	if not spend_money(price):
		get_node_or_null("/root/GameLogger").warning("GameState", "unlock_block failed  not enough money (have $%.0f, need $%d)" % [money, price])
		return false
	blocks_unlocked += 1
	get_node_or_null("/root/GameLogger").info("GameState", "block unlocked  total=%d money=$%.0f" % [blocks_unlocked, money])
	return true

const ITEM_PRICES: Dictionary = {
	"Default Model": 5.0,
}

func get_price(item_name: String) -> float:
	return ITEM_PRICES.get(item_name, 0.0)
var licenses: Array[String] = []
var print_queue: Array[Dictionary] = []

func add_money(amount: float) -> void:
	money += amount
	get_node_or_null("/root/GameLogger").debug("GameState", "+$%.2f -> total $%.2f" % [amount, money])
	money_changed.emit(money)
	add_shop_xp(int(amount))

func spend_money(amount: float) -> bool:
	if money < amount:
		return false
	money -= amount
	get_node_or_null("/root/GameLogger").debug("GameState", "-$%.2f -> total $%.2f" % [amount, money])
	money_changed.emit(money)
	return true

func unlock_license(license_id: String) -> void:
	if license_id not in licenses:
		licenses.append(license_id)
		get_node_or_null("/root/GameLogger").info("GameState", "license unlocked: " + license_id)
		license_unlocked.emit(license_id)

func has_license(license_id: String) -> bool:
	return license_id in licenses

func add_print_job(job: Dictionary) -> void:
	print_queue.append(job)
	print_job_added.emit(job)

func complete_print_job(job: Dictionary) -> void:
	print_queue.erase(job)
	print_job_completed.emit(job)
