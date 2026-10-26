extends Node3D

@export var almond_water_scene: PackedScene
@export var bottles_to_spawn: int = 15
@export var map_spread: float = 40.0 # How far out (in meters) the bottles can spawn

func _ready():
	# Wait for the map to actually physically load before shooting lasers
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if not almond_water_scene:
		push_warning("Backrooms: You forgot to slot the Almond Water scene!")
		return
		
	_scatter_items()

func _scatter_items():
	var space_state = get_world_3d().direct_space_state
	var spawned_count = 0
	var attempts = 0
	
	# Keep trying until we spawn all the bottles (or hit the safety limit so it doesn't infinite loop)
	while spawned_count < bottles_to_spawn and attempts < 100:
		attempts += 1
		
		# 1. Pick a random X and Z coordinate within your map's spread radius
		var random_x = randf_range(-map_spread, map_spread)
		var random_z = randf_range(-map_spread, map_spread)
		
		# 2. Start the laser 3 meters in the air, shoot it down to the floor
		var ray_start = global_position + Vector3(random_x, 3.0, random_z)
		var ray_end = global_position + Vector3(random_x, -1.0, random_z)
		
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		var hit_result = space_state.intersect_ray(query)
		
		# 3. If the laser hit a floor (and didn't just shoot out into the void)
		if hit_result:
			var water = almond_water_scene.instantiate()
			add_child(water)
			
			# Drop the bottle exactly where the laser hit the floor
			water.global_position = hit_result.position
			
			# Bump it up slightly so the bottom of the bottle isn't stuck inside the concrete
			water.global_position.y += 0.5 
			
			spawned_count += 1
			
	print("Backrooms: Successfully spawned ", spawned_count, " Almond Water bottles!")
