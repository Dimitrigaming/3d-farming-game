@tool
extends EditorScenePostImport

### Script by Cat Prisbrey, @catprisbrey / @var_cat_bones
### Custom import script for Quaternius assets. Imported mesh materials are compoared
### to stored materials in the Quaterius addons folder. Each name that matches will replace
### the model's material with the corrosponding material from the folder.
### License is CC0 but attribution to Quaternius is appreciated

# The folder path where custom materials are stored
const FOLDER = "res://addons/city_megakit/materials/"

# Called right after the scene is imported and gets the root node.
func _post_import(scene):
	# Process all nodes recursively
	iterate(scene)
	return scene # Return the modified scene (required)

# Recursive function to iterate through all nodes and assign matching materials.
func iterate(node):
	if !node:
		return
	
	if node is MeshInstance3D:
		var mesh = node.mesh
		if mesh:
			var surface_count = mesh.get_surface_count()
			# Check each surface material for a local match
			for i in range(surface_count): 
				var material = mesh.surface_get_material(i)
				if material:
					# Get the name of the material and build the path.
					var mat_name = material.resource_name
					var material_path = FOLDER + mat_name + ".tres" # Assuming material files are '.tres'.
					
					# Check if the material file exists.
					if ResourceLoader.exists(material_path):
						var new_material = load(material_path)
						mesh.surface_set_material(i, new_material) #  Finally assign the loaded material to the mesh.
	
	# Repeat recursively through children
	for child in node.get_children():
		iterate(child)
