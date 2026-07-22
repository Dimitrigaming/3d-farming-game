@tool
extends Node3D


# ── Core (always present) ─────────────────────────────────────────────────────

@export_group("Fatness")
@export_range(0, 100) var master_fat_slider: int = 0:
	set(v): master_fat_slider = v; _apply_fatness()

@export_group("Head")
@export_range(0, 34) var head: int = 0:
	set(v): head = v; _apply_selection(heads, v)
@export var heads: Array[Node3D] = []

@export_group("Skin")
@export_range(0, 4) var skin: int = 0:
	set(v): skin = v; _apply_selection(skins, v)
@export var skins: Array[Node3D] = []

@export_group("Hair")
@export_range(0, 50) var hairstyle: int = 0:
	set(v): hairstyle = v; _apply_selection(hairstyles, v)
@export var hairstyles: Array[Node3D] = []

# ── Optional ──────────────────────────────────────────────────────────────────

@export_group("Beard")
@export_range(0, 45) var beard: int = 0:
	set(v): beard = v; _apply_selection(beards, v)
@export var beards: Array[Node3D] = []

@export_group("Glasses")
@export_range(0, 20) var glass: int = 0:
	set(v): glass = v; _apply_selection(glasses, v)
@export var glasses: Array[Node3D] = []

@export_group("Earrings")
@export_range(0, 18) var earring: int = 0:
	set(v): earring = v; _apply_selection(earrings, v)
@export var earrings: Array[Node3D] = []

@export_group("Watch")
@export_range(0, 15) var watch: int = 0:
	set(v): watch = v; _apply_selection(watches, v)
@export var watches: Array[Node3D] = []

@export_group("Bracelet")
@export_range(0, 12) var bracelet: int = 0:
	set(v): bracelet = v; _apply_selection(bracelets, v)
@export var bracelets: Array[Node3D] = []

@export_group("Headphones")
@export_range(0, 5) var headphone: int = 0:
	set(v): headphone = v; _apply_selection(headphones, v)
@export var headphones: Array[Node3D] = []

@export_group("Hat")
@export_range(0, 25) var hat: int = 0:
	set(v): hat = v; _apply_selection(hats, v)
@export var hats: Array[Node3D] = []

@export_group("Choker")
@export_range(0, 3) var choker: int = 0:
	set(v): choker = v; _apply_selection(chokers, v)
@export var chokers: Array[Node3D] = []

@export_group("Fanny Pack")
@export_range(0, 5) var fanny_pack: int = 0:
	set(v): fanny_pack = v; _apply_selection(fanny_packs, v)
@export var fanny_packs: Array[Node3D] = []

@export_group("Tie")
@export_range(0, 4) var tie: int = 0:
	set(v): tie = v; _apply_selection(ties, v)
@export var ties: Array[Node3D] = []

@export_group("Shirt")
@export_range(0, 4) var shirt: int = 0:
	set(v): shirt = v; _apply_selection(shirts, v)
@export var shirts: Array[Node3D] = []

@export_group("Jacket")
@export_range(0, 4) var jacket: int = 0:
	set(v): jacket = v; _apply_selection(jackets, v)
@export var jackets: Array[Node3D] = []

@export_group("Dress")
@export_range(0, 4) var dress: int = 0:
	set(v): dress = v; _apply_selection(dresses, v)
@export var dresses: Array[Node3D] = []

@export_group("Apron")
@export_range(0, 4) var apron: int = 0:
	set(v): apron = v; _apply_selection(aprons, v)
@export var aprons: Array[Node3D] = []

@export_group("Skirt")
@export_range(0, 4) var skirt: int = 0:
	set(v): skirt = v; _apply_selection(skirts, v)
@export var skirts: Array[Node3D] = []

@export_group("Pants")
@export_range(0, 4) var pant: int = 0:
	set(v): pant = v; _apply_selection(pants, v)
@export var pants: Array[Node3D] = []

@export_group("Legs")
@export_range(0, 4) var leg: int = 0:
	set(v): leg = v; _apply_selection(legs, v)
@export var legs: Array[Node3D] = []

@export_group("Shoes")
@export_range(0, 4) var shoe: int = 0:
	set(v): shoe = v; _apply_selection(shoes, v)
@export var shoes: Array[Node3D] = []


# ── Helpers ───────────────────────────────────────────────────────────────────


func _apply_selection(items: Array[Node3D], selected: int) -> void:
	for i in items.size():
		if items[i] != null:
			items[i].visible = (i == selected)


func _apply_fatness() -> void:
	for node in skins:
		if not node is MeshInstance3D:
			continue
		var mi = node as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_blend_shape_count():
			if mi.mesh.get_blend_shape_name(i) == "Fat":
				mi.set_blend_shape_value(i, master_fat_slider / 100.0)
