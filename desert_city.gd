extends Node3D

@export var custom_water_mesh: NodePath

func _ready():
	call_deferred("_build_map_physics")

func _build_map_physics():
	var all_meshes = find_children("*", "MeshInstance3D", true, false)
	var destruction_script = GDScript.new()
	destruction_script.source_code = """
extends StaticBody3D
var max_hp = 30.0 
var hp = 30.0
var is_broken = false

func take_damage(amount):
	if is_broken: return
	hp -= amount
	if hp > 0: return 
	is_broken = true
	var og_mesh = get_parent()
	if not og_mesh is MeshInstance3D: return
	
	var col = get_node_or_null("CollisionShape3D")
	if col: col.set_deferred("disabled", true)
	og_mesh.visible = false
	
	var debris = RigidBody3D.new()
	debris.mass = 30.0
	
	# THE PHYSICS FIX: Put Debris on Layer 3 so it doesn't flip cars or players
	debris.collision_layer = 4 
	debris.collision_mask = 1  
	
	var d_mesh = og_mesh.duplicate(1)
	for c in d_mesh.get_children(): c.queue_free()
	d_mesh.visible = true
	debris.add_child(d_mesh)
	
	var d_col = CollisionShape3D.new()
	if og_mesh.mesh: 
		var box = BoxShape3D.new()
		box.size = og_mesh.mesh.get_aabb().size
		d_col.shape = box
		d_col.position = og_mesh.mesh.get_aabb().get_center()
	debris.add_child(d_col)
	
	og_mesh.get_parent().add_child(debris)
	debris.global_transform = og_mesh.global_transform
	
	var pop_dir = Vector3(randf_range(-1, 1), randf_range(0.2, 0.8), randf_range(-1, 1)).normalized()
	debris.apply_central_impulse(pop_dir * 300.0)
	debris.apply_torque_impulse(Vector3(randf_range(-20,20), randf_range(-20,20), randf_range(-20,20)))
	
	await get_tree().create_timer(8.0).timeout
	if is_instance_valid(debris): debris.queue_free()
	
	og_mesh.visible = true
	if col: col.set_deferred("disabled", false)
	hp = max_hp 
	is_broken = false
"""
	destruction_script.reload() 

	var water_script = GDScript.new()
	water_script.source_code = """
extends Area3D
func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
func _on_body_entered(body):
	if body.has_method("enter_water"): body.enter_water()
func _on_body_exited(body):
	if body.has_method("exit_water"): body.exit_water()
"""
	water_script.reload()

	var trimesh_keywords = ["ground", "floor", "terrain", "sand", "desert", "road", "path", "building", "house", "hut", "wall", "fence", "bridge", "stair", "step", "ramp", "arch", "roof", "ruin"]
	var pole_keywords = ["tree", "pole", "light", "sign", "billboard", "lamp", "post", "pillar", "trunk", "stand", "cactus"]
	var ghost_keywords = ["leaf", "leaves", "grass", "bush", "flower", "plant", "cloud", "fx", "particle"]
	var water_keywords = ["water", "lake", "ocean", "river", "sea", "pond", "pool"]
	var specific_water_node = get_node_or_null(custom_water_mesh) if not custom_water_mesh.is_empty() else null
	
	var meshes_processed = 0

	for mesh in all_meshes:
		if not is_instance_valid(mesh.mesh): continue
			
		# Skip objects that already have collision to prevent lag-stacking
		var has_collision = false
		for c in mesh.get_children():
			if c is CollisionObject3D: has_collision = true
		if has_collision or mesh.get_parent() is CollisionObject3D: continue

		var full_name = (mesh.name + mesh.get_parent().name).to_lower()
		var aabb = mesh.mesh.get_aabb()
		var is_indestructible = false
		
		for k in trimesh_keywords:
			if k in full_name:
				is_indestructible = true
				break

		# DESERT FLOOR FAILSAFE (This stops you from blowing up the entire desert ground)
		if aabb.size.y < 1.5 and aabb.size.x > 4.0 and aabb.size.z > 4.0:
			is_indestructible = true

		var is_water = false
		if specific_water_node and mesh == specific_water_node: is_water = true
		else:
			for k in water_keywords:
				if k in full_name: is_water = true; break
				
		if is_water:
			var water_area = Area3D.new()
			var shape = CollisionShape3D.new()
			water_area.name = "Area3D"
			shape.shape = mesh.mesh.create_trimesh_shape()
			if not shape.shape: continue
			water_area.add_child(shape)
			water_area.set_script(water_script)
			var water_mat = StandardMaterial3D.new()
			water_mat.albedo_color = Color(0.0, 0.4, 0.8, 0.6)
			water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.material_override = water_mat
			mesh.add_child(water_area)
			continue 

		if is_indestructible:
			mesh.create_trimesh_collision()
			meshes_processed += 1
			if meshes_processed % 15 == 0: await get_tree().process_frame
			continue
			
		var col_type = "box"
		for k in ghost_keywords:
			if k in full_name: col_type = "ghost"; break
		if col_type != "ghost":
			for k in pole_keywords:
				if k in full_name: col_type = "pole"; break

		if col_type == "ghost" or (aabb.size.x < 0.2 and aabb.size.y < 0.2 and aabb.size.z < 0.2): 
			continue

		var body = StaticBody3D.new()
		var shape = CollisionShape3D.new()
		body.name = "StaticBody3D"
		shape.name = "CollisionShape3D"
		
		if col_type == "pole":
			var cyl = CylinderShape3D.new()
			cyl.radius = min(aabb.size.x, aabb.size.z) * 0.35
			cyl.radius = clamp(cyl.radius, 0.1, 1.5)
			cyl.height = aabb.size.y
			shape.shape = cyl
			shape.position = aabb.get_center()
		else:
			var box = BoxShape3D.new()
			box.size = aabb.size
			shape.shape = box
			shape.position = aabb.get_center()
			
		if not shape.shape: continue
			
		body.add_child(shape)
		mesh.add_child(body) 
				
		body.set_script(destruction_script)
		# DECREASED TO 30 FOR CHAOTIC DESTRUCTION!
		body.set("max_hp", 1.0 if col_type == "pole" else 30.0)
		body.set("hp", body.get("max_hp"))
				
		meshes_processed += 1
		if meshes_processed % 30 == 0: await get_tree().process_frame
			
	print("Desert Physics Optimized Successfully!")
