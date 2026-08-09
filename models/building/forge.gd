extends "res://models/building/crafting_workbench.gd"

## Item ids that upgrade this forge, mapped to the node they reveal when installed.
@export var upgrade_nodes: Dictionary = {
	"anvil": NodePath("SM_Metalworking_Prop_AnvilStand_01"),
	"bellows": NodePath("SM_Metalworking_Prop_Bellows_01"),
	"quenching_tub": NodePath("SM_Metalworking_Prop_QuenchingTub_01"),
}

var installed_upgrades: Array[String] = []

func _ready() -> void:
	station_type = "forge"
	super._ready()
	for item_id in upgrade_nodes:
		var node = get_node_or_null(upgrade_nodes[item_id])
		if node:
			node.visible = false

func interact() -> void:
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	var item_id = equipper.current_item_id if equipper else ""
	if item_id in upgrade_nodes and item_id not in installed_upgrades:
		_install_upgrade(item_id)
		return
	super.interact()

func get_interact_hint() -> String:
	var equipper = get_tree().get_first_node_in_group("tool_equipper")
	var item_id = equipper.current_item_id if equipper else ""
	if item_id in upgrade_nodes and item_id not in installed_upgrades:
		var def = ItemDB.get_item(item_id)
		return "Install %s" % (def.name if def else item_id.capitalize())
	return "Craft"

func _install_upgrade(item_id: String) -> void:
	var inventory = get_tree().get_first_node_in_group("player_inventory_data")
	if inventory == null or not inventory.has_item(item_id):
		return
	inventory.remove_item(item_id)
	installed_upgrades.append(item_id)
	var node = get_node_or_null(upgrade_nodes[item_id])
	if node:
		node.visible = true
