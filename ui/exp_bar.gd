extends CanvasLayer

## Shows whichever XP track (shop, or this player's per-station levels) was
## most recently gained -- switches on the fly rather than being locked to
## one source, so it stays relevant whether you just sold something or just
## chopped/mined/crafted something.

@onready var bar: ProgressBar = $Panel/Bar
@onready var level_label: Label = $Panel/LevelLabel
@onready var station_levels: Node = get_node_or_null("../PlayerStationLevels")

## "shop" or a station_type string ("gathering", "workbench", "forge", ...)
var _current_source: String = "shop"

func _ready() -> void:
	GameState.shop_xp_gained.connect(_on_shop_xp_changed)
	GameState.shop_level_up.connect(_on_shop_level_up)
	if station_levels:
		station_levels.xp_gained.connect(_on_station_xp_changed)
		station_levels.level_up.connect(_on_station_level_up)
	_refresh()

func _on_shop_xp_changed(_amount: int, _new_xp: int) -> void:
	_current_source = "shop"
	_refresh()

func _on_shop_level_up(_new_level: int) -> void:
	_current_source = "shop"
	_refresh()

func _on_station_xp_changed(station_type: String, _amount: int, _new_xp: int) -> void:
	_current_source = station_type
	_refresh()

func _on_station_level_up(station_type: String, _new_level: int) -> void:
	_current_source = station_type
	_refresh()

func _refresh() -> void:
	if _current_source == "shop":
		bar.max_value = GameState.shop_xp_to_next_level()
		bar.value = GameState.shop_xp
		level_label.text = "Shop Lv %d" % GameState.shop_level
	elif station_levels:
		bar.max_value = station_levels.xp_to_next_level(_current_source)
		bar.value = station_levels.get_xp(_current_source)
		level_label.text = "%s Lv %d" % [_current_source.capitalize(), station_levels.get_level(_current_source)]
