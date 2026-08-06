@tool
extends EditorScript

const RENAME_MAP = {
	"Spine_01": "Spine",
	"Spine_02": "Chest",
	"Spine_03": "UpperChest",
	"Clavicle.L": "LeftShoulder",
	"Arm.L": "LeftUpperArm",
	"Forearm.L": "LeftLowerArm",
	"Hand.L": "LeftHand",
	"Clavicle.R": "RightShoulder",
	"Arm.R": "RightUpperArm",
	"Forearm.R": "RightLowerArm",
	"Hand.R": "RightHand",
	"Quad.L": "LeftUpperLeg",
	"Shin.L": "LeftLowerLeg",
	"Foot.L": "LeftFoot",
	"Toes.L": "LeftToes",
	"Quad.R": "RightUpperLeg",
	"Shin.R": "RightLowerLeg",
	"Foot.R": "RightFoot",
	"Toes.R": "RightToes",
}

func _run():
	var path = "res://addons/Toon/Toon City People/Models/TCP_Male_Character_01.tscn"
	var scene: PackedScene = load(path)
	var inst = scene.instantiate()
	var skeleton = _find_skeleton(inst)
	if skeleton == null:
		print("No Skeleton3D found!")
		return
	for i in range(skeleton.get_bone_count()):
		var old_name = skeleton.get_bone_name(i)
		if RENAME_MAP.has(old_name):
			skeleton.set_bone_name(i, RENAME_MAP[old_name])
	var packed = PackedScene.new()
	packed.pack(inst)
	ResourceSaver.save(packed, path)
	inst.queue_free()
	print("Renamed bones and saved: ", path)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result = _find_skeleton(child)
		if result != null:
			return result
	return null
