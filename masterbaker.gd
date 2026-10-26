@tool
extends Node

@export var maps_to_bake: Array[PackedScene]

@export var start_mass_bake: bool = false:
	set(value):
		start_mass_bake = false 
		if value and Engine.is_editor_hint():
			if maps_to_bake.is_empty():
				OS.alert("Error: No maps added to the Array!")
				return
			_run_batch_bake()

func _run_batch_bake():
	var success_count = 0
	for map_scene in maps_to_bake:
		if not map_scene: continue
		
		var scene_path = map_scene.resource_path
		
		# OVERRIDE: Using OS.alert so you actually see the error on mobile
		if not scene_path.ends_with(".tscn"):
			OS.alert("Skipped " + scene_path.get_file() + "!\nMust be a saved .tscn file, not a raw .glb.")
			continue

		var map_name = scene_path.get_file().get_basename()
		var map_instance = map_scene.instantiate()
		var dir_path = "res://baked_collisions/" + map_name
		DirAccess.make_dir_recursive_absolute(dir_path)

		var meshes = _get_all_meshes(map_instance)
		var new_collisions_count = 0

		for mesh in meshes:
			if not mesh.mesh: continue
			
			var has_col = false
			for child in mesh.get_children():
				if child is StaticBody3D: has_col = true
			if has_col: continue

			var shape = mesh.mesh.create_trimesh_shape()
			if not shape: continue

			var safe_name = str(mesh.name).validate_node_name()
			var unique_id = str(mesh.get_instance_id())
			var file_path = dir_path + "/" + safe_name + "_" + unique_id + "_col.tres"
			ResourceSaver.save(shape, file_path)

			var static_body = StaticBody3D.new()
			static_body.name = "StaticBody3D"
			var coll = CollisionShape3D.new()
			coll.name = "CollisionShape3D"
			coll.shape = load(file_path)

			static_body.add_child(coll)
			mesh.add_child(static_body)

			static_body.owner = map_instance
			coll.owner = map_instance
			
			new_collisions_count += 1

		if new_collisions_count > 0:
			var packed = PackedScene.new()
			packed.pack(map_instance)
			ResourceSaver.save(packed, scene_path)
			success_count += 1
		
		map_instance.queue_free()
		
	if success_count > 0:
		OS.alert("SUCCESS! Baked collisions for " + str(success_count) + " maps.")
	else:
		OS.alert("Finished, but 0 new collisions were saved. Check file types.")

func _get_all_meshes(node: Node) -> Array:
	var meshes = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(_get_all_meshes(child))
	return meshes
