extends Node3D

var _shop_ui: CanvasLayer = null

func _ready() -> void:
	_setup_shop()
	var npc = get_node_or_null("TCP_Male_Character_11")
	if npc:
		var body = npc.get_node_or_null("StaticBody3D")
		if body:
			body.add_to_group("interactable")
			body.set_meta("interact_owner", self)

func _setup_shop() -> void:
	var scene = load("res://ui/shop_ui.tscn") as PackedScene
	if scene == null:
		push_error("StoreMarketStall: shop_ui.tscn not found.")
		return
	_shop_ui = scene.instantiate()
	get_tree().get_root().call_deferred("add_child", _shop_ui)

func interact() -> void:
	if _shop_ui:
		_shop_ui.open_shop()

func get_interact_hint() -> String:
	return "Open Shop"
