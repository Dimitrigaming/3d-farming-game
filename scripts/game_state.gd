extends Node

signal money_changed(new_amount: float)
signal license_unlocked(license_id: String)
signal print_job_added(job: Dictionary)
signal print_job_completed(job: Dictionary)

var money: float = 10000.0      # 500.0
var blocks_unlocked: int = 0

var shop_floor_tier: int = 0
var production_floor_tier: int = 0

const SHOP_FLOOR_COSTS = [300.0, 800.0]
const PRODUCTION_FLOOR_COSTS = [400.0, 1000.0]
const MAX_ROOM_TIER: int = 2

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
