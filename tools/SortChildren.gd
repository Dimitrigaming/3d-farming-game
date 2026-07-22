@tool
extends Node3D

@export_tool_button("Sort Children A-Z") var _btn_sort = _sort_children
@export_tool_button("Auto Distribute to Arrays") var _btn_dist = _auto_distribute

@export var character_customizer: Node

const NAME_MAP = {
	"_Apron_":      "aprons",
	"_Beard_":      "beards",
	"_Bracelet_":   "bracelets",
	"_Choker_":     "chokers",
	"_Dress_":      "dresses",
	"_Earring_":    "earrings",
	"_Fannypack_":  "fanny_packs",
	"_Glasses_":    "glasses",
	"_Sunglasses_": "glasses",
	"_Hair_":       "hairstyles",
	"_Hairstyle_":  "hairstyles",
	"_Hat_":        "hats",
	"_Head_":       "heads",
	"_Headphone_":  "headphones",
	"_Jacket_":     "jackets",
	"_Leg_":        "legs",
	"_Pant_":       "pants",
	"_Pants_":      "pants",
	"_Shirt_":      "shirts",
	"_Shoe_":       "shoes",
	"_Shoes_":      "shoes",
	"_Skin_":       "skins",
	"_Skirt_":      "skirts",
	"_Tie_":        "ties",
	"_Watch_":      "watches",
}


func _sort_children() -> void:
	var children = get_children()
	children.sort_custom(func(a, b): return str(a.name) < str(b.name))
	for i in children.size():
		move_child(children[i], i)
	print("Sorted %d children" % children.size())



func _auto_distribute() -> void:
	if character_customizer == null:
		push_error("SortChildren: character_customizer is not set")
		return

	var buckets: Dictionary = {}
	var unmatched: Array = []

	for child in get_children():
		var matched = false
		var child_name = str(child.name)
		for keyword in NAME_MAP:
			if child_name.to_lower().contains(keyword.to_lower()):
				var array_name = NAME_MAP[keyword]
				if not buckets.has(array_name):
					buckets[array_name] = []
				buckets[array_name].append(child)
				matched = true
				break
		if not matched:
			unmatched.append(child_name)

	for array_name in buckets:
		var arr: Array[Node3D] = []
		arr.assign(buckets[array_name])
		character_customizer.set(array_name, arr)
		print("  -> %s: %d items" % [array_name, arr.size()])

	if unmatched.size() > 0:
		push_warning("SortChildren: unmatched nodes: " + str(unmatched))

	print("Auto distribute complete. %d unmatched." % unmatched.size())
