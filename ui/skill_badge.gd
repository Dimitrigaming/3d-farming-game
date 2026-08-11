extends Button

## A rectangular skill badge: name + level on top, a thin progress line
## underneath showing XP toward the next level. Placed directly in a scene
## (e.g. character_screen.tscn) rather than spawned from code -- set
## station_type/display_name in the Inspector per instance.

signal badge_clicked(badge: Button)

@export var station_type: String = ""
@export var display_name: String = "Skill"
@export var station_icon: Texture2D

@onready var icon_rect: TextureRect = $MarginContainer/VBox/TopRow/Icon
@onready var name_label: Label = $MarginContainer/VBox/TopRow/NameLabel
@onready var level_label: Label = $MarginContainer/VBox/TopRow/LevelLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBox/ProgressBar
@onready var xp_label: Label = $MarginContainer/VBox/XPLabel

func _ready() -> void:
	add_to_group("skill_badge")
	name_label.text = display_name
	icon_rect.texture = station_icon
	icon_rect.visible = station_icon != null
	pressed.connect(func(): badge_clicked.emit(self))

func refresh(level: int, xp: int, xp_to_next: int) -> void:
	level_label.text = "Lv %d" % level
	progress_bar.max_value = max(xp_to_next, 1)
	progress_bar.value = xp
	xp_label.text = "%d / %d XP" % [xp, xp_to_next]
