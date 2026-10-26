extends Node3D

func _ready():
	print("Paving the Kamui Dimension...")
	# We use call_deferred so it doesn't freeze the game right as you boot up
	call_deferred("build_collision")

func build_collision():
	# Your trick: instantly grabs every mesh inside the 1000x scale model
	var all_meshes = find_children("*", "MeshInstance3D", true, false)
	
	for mesh in all_meshes:
		# Force Godot to generate the physical floor
		mesh.create_trimesh_collision()
		
	print("Kamui floor is solid! Physics applied to ", all_meshes.size(), " meshes.")
