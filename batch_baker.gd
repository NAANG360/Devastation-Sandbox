extends Node

@export var map_scenes: Array[String] = [
	"res://maincity.tscn",
	"res://sand_village.tscn"
]

func _ready():
	print("=======================================")
	print(" STARTING AGGRESSIVE CLEAN & BAKE...")
	print("=======================================")
	
	for path in map_scenes:
		if not path.ends_with(".tscn"): continue
		print("-> Processing Map: ", path)
		
		var packed = load(path)
		if not packed: continue
		var map = packed.instantiate()
		
		var meshes = _get_all_meshes(map)
		var added_cols = 0
		var deleted_ghosts = 0
		
		DirAccess.make_dir_recursive_absolute("res://baked_collisions/")
		
		for mesh in meshes:
			if not mesh.mesh: continue
			
			# AGGRESSIVE MODE: Find any existing StaticBody3D and NUKE it.
			# This clears out the broken ghost nodes that made you fall through the map.
			for c in mesh.get_children():
				if c is StaticBody3D:
					mesh.remove_child(c)
					c.free() # Instantly delete from memory
					deleted_ghosts += 1
			
			var shape = mesh.mesh.create_trimesh_shape()
			if not shape: continue
			
			var safe_name = str(mesh.name).validate_node_name() + "_" + str(mesh.get_instance_id())
			var res_path = "res://baked_collisions/" + safe_name + "_col.res"
			ResourceSaver.save(shape, res_path)
			
			var sb = StaticBody3D.new()
			sb.name = "StaticBody3D" 
			
			var cs = CollisionShape3D.new()
			cs.name = "CollisionShape3D"
			cs.shape = shape 
			
			sb.add_child(cs)
			mesh.add_child(sb)
			
			sb.owner = map
			cs.owner = map
			added_cols += 1
			
		if added_cols > 0:
			var new_packed = PackedScene.new()
			new_packed.pack(map)
			ResourceSaver.save(new_packed, path)
			print("   [SUCCESS] Deleted ", deleted_ghosts, " broken ghosts.")
			print("   [SUCCESS] Added ", added_cols, " permanent collisions!")
		else:
			print("   [SKIP] No meshes found to bake.")
			
		map.queue_free()
		
	print("=======================================")
	print(" ALL DONE! YOU CAN CLOSE THIS WINDOW NOW.")
	print("=======================================")
	get_tree().quit()

func _get_all_meshes(node: Node) -> Array:
	var arr = []
	if node is MeshInstance3D: arr.append(node)
	for c in node.get_children():
		arr.append_array(_get_all_meshes(c))
	return arr
