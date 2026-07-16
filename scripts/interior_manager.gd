extends Node3D

const NavLinkBlock = preload("res://models/nav_link_block.tscn")

func spawn_nav_link(world_pos: Vector3) -> void:
	var instance = NavLinkBlock.instantiate()
	add_child(instance)
	instance.global_position = world_pos
