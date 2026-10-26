extends Node3D 

var render_distance = 150.0 
var city_parts = [] 
var tick = 0.0 

@export var collision_batch_size: int = 12 
@export var minimum_collision_size: float = 0.2 
@export var ground_mesh: Node3D # <-- ASSIGN YOUR GROUND IN THE INSPECTOR HERE!

var physics_built: bool = false

const TRIMESH_KEYWORDS := ["ground", "floor", "terrain", "road", "street", "pavement", "asphalt", "base", "path", "building", "house", "wall", "fence", "bridge", "stair", "step", "ramp", "arch", "roof", "intersection", "crosswalk", "sidewalk", "curb", "plaza", "concrete", "lot"] 

const POLE_KEYWORDS := ["tree", "pole", "light", "sign", "billboard", "lamp", "post", "pillar", "trunk", "stand"] 

const GHOST_KEYWORDS := ["leaf", "leaves", "grass", "bush", "flower", "plant", "cloud", "fx", "particle", "water"] 

func _ready(): 
	var all_meshes = find_children("*", "MeshInstance3D", true, false) 
	
	for mesh_node in all_meshes: 
		city_parts.append(mesh_node) 
	
	# Fallback just in case you forget to assign the export
	if not ground_mesh and get_tree().current_scene: 
		var found = get_tree().current_scene.find_child("City Ground_Color_0_77", true, false)
		if found is Node3D:
			ground_mesh = found
	
	call_deferred("_build_world_physics")

func _process(delta): 
	tick += delta 
	if tick > 0.5: 
		tick = 0.0 
		 
		var active_camera = get_viewport().get_camera_3d() 
		if not active_camera: 
			return 
		 
		var target_pos = active_camera.global_position 
		 
		for part in city_parts: 
			if is_instance_valid(part):
				# THE FIX: Never hide the ground/roads so you don't fall into the void!
				if ground_mesh != null and (part == ground_mesh or ground_mesh.is_ancestor_of(part)):
					part.show()
					continue
					
				if part.global_position.distance_to(target_pos) > render_distance: 
					part.hide() 
				else: 
					part.show() 

func _build_world_physics() -> void: 
	if physics_built: return
	physics_built = true
	
	var meshes := find_children("*", "MeshInstance3D", true, false) 
	var processed := 0 
	
	for mesh_node in meshes: 
		var mesh := mesh_node as MeshInstance3D 
		if mesh == null or not mesh.mesh or _already_has_collision(mesh): 
			continue 
			
		var full_name := _node_and_parent_name(mesh) 
		var aabb := mesh.mesh.get_aabb() 
		
		if _should_skip_collision(full_name, aabb): 
			continue 
			
		if _needs_trimesh_collision(mesh, full_name, aabb): 
			mesh.create_trimesh_collision() 
		else: 
			_add_simple_collision(mesh, full_name, aabb) 
			
		processed += 1 
		
		if processed % collision_batch_size == 0: 
			await get_tree().process_frame 
			
	print("Low Poly City: generated %d collision bodies in batches." % processed) 

func _already_has_collision(mesh: MeshInstance3D) -> bool: 
	if mesh.get_meta("city_collision_generated", false): 
		return true 
	if mesh.get_parent() is CollisionObject3D: 
		return true 
	for child in mesh.get_children(): 
		if child is CollisionObject3D: 
			return true 
	return false 

func _node_and_parent_name(node: Node) -> String: 
	var full_name := str(node.name).to_lower() 
	if node.get_parent(): 
		full_name += str(node.get_parent().name).to_lower() 
	return full_name 

func _should_skip_collision(full_name: String, aabb: AABB) -> bool: 
	if aabb.size.x < minimum_collision_size and aabb.size.y < minimum_collision_size and aabb.size.z < minimum_collision_size: 
		return true 
	for keyword in GHOST_KEYWORDS: 
		if keyword in full_name: 
			return true 
	return false 

func _needs_trimesh_collision(mesh: MeshInstance3D, full_name: String, aabb: AABB) -> bool: 
	# THE SELECTOR FIX: If this is the ground_mesh you selected, force Trimesh!
	if ground_mesh != null and (mesh == ground_mesh or ground_mesh.is_ancestor_of(mesh)): 
		return true 
		
	# THE SHAPE FIX: Even if a sidewalk has a weird name, if it is flat and wide, force Trimesh!
	if aabb.size.y < 1.5 and (aabb.size.x > 3.0 or aabb.size.z > 3.0): 
		return true 
		
	# THE NAME FIX: Check standard keywords
	for keyword in TRIMESH_KEYWORDS: 
		if keyword in full_name: 
			return true 
			
	return false 

func _add_simple_collision(mesh: MeshInstance3D, full_name: String, aabb: AABB) -> void: 
	var body := StaticBody3D.new() 
	var shape := CollisionShape3D.new() 
	body.name = "GeneratedCityCollision" 
	shape.name = "CollisionShape3D" 
	shape.position = aabb.get_center() 
	
	if _is_pole(full_name): 
		var cylinder := CylinderShape3D.new() 
		cylinder.radius = clamp(min(aabb.size.x, aabb.size.z) * 0.35, 0.1, 1.5) 
		cylinder.height = max(aabb.size.y, 0.1) 
		shape.shape = cylinder 
	else: 
		var box := BoxShape3D.new() 
		var safe_size = aabb.size
		if safe_size.x < 0.2: safe_size.x = 0.2
		if safe_size.y < 0.2: safe_size.y = 0.2
		if safe_size.z < 0.2: safe_size.z = 0.2
		box.size = safe_size 
		shape.shape = box 
		
	body.add_child(shape) 
	mesh.add_child(body) 
	mesh.set_meta("city_collision_generated", true) 

func _is_pole(full_name: String) -> bool: 
	for keyword in POLE_KEYWORDS: 
		if keyword in full_name: 
			return true 
	return false
