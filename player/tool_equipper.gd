extends Node3D

## Emitted the instant the swing reaches its peak (tool visually connects).
signal swing_hit

const SWING_DURATION: float = 0.18
const SWING_ROTATION := Vector3(deg_to_rad(-20), 0, deg_to_rad(70))
const WINDUP_ROTATION := Vector3(deg_to_rad(5), 0, deg_to_rad(-15))
const WINDUP_DURATION: float = 0.1
const FLIPPED_SWING_CATEGORIES := ["hammer"]
const ROTATED_SWING_CATEGORIES := ["hoe"]

## Curved (windup -> [mid ->] swing -> rest) motions, keyed by tool_category.
## "mid" is optional -- omit it for a single blended diagonal swing.
const CURVED_SWINGS := {
	"scythe": {
		"windup": Vector3(-10, -15, 5),
		"mid": Vector3(60, 10, -10),
		"swing": Vector3(50, 90, -20),
		"duration_mult": 1.6,
	},
	"axe": {
		"windup": Vector3(10, 0, 5),
		"swing": Vector3(85, 0, -95),
		"duration_mult": 1.2,
	},
	"pickaxe": {
		"windup": Vector3(5, 0, -15),
		"swing": Vector3(-15, 0, 65),
		"duration_mult": 1.15,
	},
}

var current_item_id: String = ""
var current_slot_index: int = -1
var _equipped: Node3D = null
var _hand: Node3D = null
var _rest_rotation: Vector3 = Vector3.ZERO
var _swing_tween: Tween = null
var _is_swinging: bool = false

func _ready() -> void:
	add_to_group("tool_equipper")
	_hand = Node3D.new()
	_hand.name = "Hand"
	_hand.position = Vector3(0.35, -0.3, -0.5)
	var camera = _find_camera(get_parent())
	if camera:
		camera.add_child(_hand)
	else:
		push_warning("ToolEquipper: no Camera3D found in parent.")

func equip(item_id: String) -> void:
	# hotbar.gd re-calls equip() on every inventory_changed signal (e.g. tool
	# durability ticking down on every hit), not just on an actual slot
	# switch. Re-instantiating _equipped when nothing changed was destroying
	# the tool mesh mid-swing-tween, killing the tween before its "finished"
	# signal could reset _is_swinging -- permanently blocking every swing
	# after the first.
	if item_id == current_item_id and (_equipped != null or item_id == ""):
		return
	current_item_id = item_id
	if _equipped:
		_equipped.queue_free()
		_equipped = null
	if item_id == "" or _hand == null:
		return
	var def = ItemDB.get_item(item_id)
	if def == null or def.equip_scene == null:
		return
	_equipped = def.equip_scene.instantiate()
	_hand.add_child(_equipped)
	_equipped.scale = Vector3.ONE * def.equip_scale
	_disable_collisions(_equipped)
	_rest_rotation = _equipped.rotation

func can_swing() -> bool:
	# Don't just trust _is_swinging -- if _swing_tween was ever killed
	# externally (e.g. the tool it's animating got freed out from under it,
	# as equip() used to do on every durability tick), its "finished" signal
	# never fires and the flag would otherwise stay stuck true forever.
	if _is_swinging and (_swing_tween == null or not _swing_tween.is_valid()):
		_is_swinging = false
	return not _is_swinging

func play_swing() -> void:
	if _is_swinging:
		return
	_is_swinging = true

	# Bare hands (nothing equipped) still need to swing -- there's no mesh
	# to show yet, but interact()/damage still needs the swing_hit timing
	# signal to fire. Animates the always-present _hand anchor itself
	# instead of bailing out, so this reuses the exact same tween/
	# can_swing machinery a real tool uses; once a visible hand model gets
	# added as a child of _hand, it'll just start animating along with it.
	var target_node: Node3D = _equipped if _equipped != null else _hand
	var base_rotation: Vector3 = _rest_rotation if _equipped != null else Vector3.ZERO
	target_node.rotation = base_rotation

	var windup := WINDUP_ROTATION
	var swing := SWING_ROTATION
	var mid: Variant = null
	var duration_mult: float = 1.0
	var def = ItemDB.get_item(current_item_id)
	if def:
		if def.tool_category in FLIPPED_SWING_CATEGORIES:
			windup *= -1.0
			swing *= -1.0
		elif def.tool_category in ROTATED_SWING_CATEGORIES:
			windup = Vector3(windup.z, deg_to_rad(3), 0)
			swing = Vector3(swing.z, deg_to_rad(10), 0)
		elif def.tool_category in CURVED_SWINGS:
			var data: Dictionary = CURVED_SWINGS[def.tool_category]
			windup = _deg(data["windup"])
			if data.has("mid"):
				mid = _deg(data["mid"])
			swing = _deg(data["swing"])
			duration_mult = data["duration_mult"]

	_swing_tween = create_tween()
	_swing_tween.set_trans(Tween.TRANS_CUBIC)
	_swing_tween.tween_property(target_node, "rotation", base_rotation + windup, WINDUP_DURATION * duration_mult).set_ease(Tween.EASE_OUT)
	if mid != null:
		_swing_tween.tween_property(target_node, "rotation", base_rotation + mid, SWING_DURATION * 0.25 * duration_mult).set_ease(Tween.EASE_OUT)
		_swing_tween.tween_property(target_node, "rotation", base_rotation + swing, SWING_DURATION * 0.35 * duration_mult).set_ease(Tween.EASE_IN_OUT)
	else:
		_swing_tween.tween_property(target_node, "rotation", base_rotation + swing, SWING_DURATION * 0.4 * duration_mult).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_callback(func(): swing_hit.emit())
	_swing_tween.tween_property(target_node, "rotation", base_rotation, SWING_DURATION * 0.6 * duration_mult).set_ease(Tween.EASE_IN)
	_swing_tween.finished.connect(func(): _is_swinging = false)

## Recursively disables every collision shape under a held item -- items
## like furniture reuse place_scene (which has real world colliders) as
## equip_scene, and those must not collide with anything while held.
func _disable_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_disable_collisions(child)

func _deg(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))

func _find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var result = _find_camera(child)
		if result:
			return result
	return null
