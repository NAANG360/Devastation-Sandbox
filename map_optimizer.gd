extends Node 

@export var city_map: Node3D 
@export var render_distance: float = 200.0 
@export var batch_size: int = 32 
@export var small_shadow_cutoff: float = 3.0 

var protected_ground: Node 

const FLOOR_KEYWORDS := ["ground", "floor", "terrain", "road", "street", "pavement", "asphalt", "base"] 

func _ready(): 
	if not city_map: 
		push_warning("Map Optimizer: assign the city_map export before running the scene.") 
		return 

	# Attempt to find the specific ground mesh so we don't accidentally hide it
	protected_ground = get_node_or_null("/root/main/maincity/Sketchfab_model/root/GLTF_SceneRootNode/City Ground_Color_0_77") 
	if not protected_ground and get_tree().current_scene: 
		protected_ground = get_tree().current_scene.find_child("City Ground_Color_0_77", true, false) 

	# Run the optimizer in the background so the game doesn't freeze
	call_deferred("_optimize_map") 

func _optimize_map() -> void: 
	var processed: int = 0 
	var stack: Array[Node] = [city_map] 

	# Iterative loop to scan every single object in the city
	while not stack.is_empty(): 
		# FIX: Explicitly typed as Node so the compiler doesn't complain about Variant
		var node: Node = stack.pop_back() 
		for child in node.get_children(): 
			stack.append(child) 
			
		if not (node is GeometryInstance3D): 
			continue 
			
		var geometry: GeometryInstance3D = node as GeometryInstance3D 
		
		# If it's the floor, NEVER hide it (prevents looking into the void)
		if _is_critical_floor(geometry): 
			geometry.visibility_range_end = 0.0 
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED 
		else: 
			# If it's a building/prop, hide it when the player is far away
			geometry.visibility_range_end = render_distance 
			geometry.visibility_range_end_margin = 20.0 
			geometry.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			
			# Disable shadows on tiny objects to save GPU performance
			_disable_tiny_mesh_shadows(geometry) 
			
		processed += 1 
		
		# Pause for a split second every 32 objects so the phone CPU doesn't choke
		if processed % batch_size == 0: 
			await get_tree().process_frame 
			
	print("Map Optimizer: applied visibility ranges to %d geometry nodes without a frame spike." % processed) 

func _is_critical_floor(geometry: GeometryInstance3D) -> bool: 
	if protected_ground != null and (geometry == protected_ground or protected_ground.is_ancestor_of(geometry)): 
		return true 
		
	var full_name: String = str(geometry.name).to_lower() 
	if geometry.get_parent(): 
		full_name += str(geometry.get_parent().name).to_lower() 
		
	# Check by name
	for keyword in FLOOR_KEYWORDS: 
		if keyword in full_name: 
			return true 
			
	# Check by size (if it's flat and massive, it's probably the ground)
	var mesh_inst: MeshInstance3D = geometry as MeshInstance3D
	if mesh_inst != null and mesh_inst.mesh != null: 
		# FIX: Explicitly typed as AABB to satisfy the compiler
		var aabb: AABB = mesh_inst.mesh.get_aabb() 
		return aabb.size.y < 2.0 and aabb.size.x > 50.0 and aabb.size.z > 50.0 
		
	return false 

func _disable_tiny_mesh_shadows(geometry: GeometryInstance3D) -> void: 
	var mesh_inst: MeshInstance3D = geometry as MeshInstance3D
	if mesh_inst == null or mesh_inst.mesh == null: 
		return 
		
	# FIX: Explicitly typed as AABB
	var aabb: AABB = mesh_inst.mesh.get_aabb() 
	
	# If the object is smaller than the cutoff, disable its shadows
	if aabb.size.x < small_shadow_cutoff and aabb.size.y < small_shadow_cutoff and aabb.size.z < small_shadow_cutoff: 
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
