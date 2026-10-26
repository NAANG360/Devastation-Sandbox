extends Node3D

@export var npc_scene: PackedScene
@export var max_npcs: int = 15

# THE DONUT ZONES
@export var min_spawn_dist: float = 30.0
@export var max_spawn_dist: float = 60.0
@export var despawn_dist: float = 80.0

@export var street_level_max_y: float = 2.0

var active_npcs: Array = []
var check_timer: float = 0.0

func _ready():
	if not npc_scene:
		print("ERROR: NPC scene is missing from the Spawner Inspector!")

func _process(delta):
	# Only run the heavy math once per second
	check_timer -= delta
	if check_timer <= 0:
		check_timer = 1.0 
		manage_population()

func manage_population():
	var active_cam = get_viewport().get_camera_3d()
	if not active_cam:
		return
		
	var center_pos = active_cam.global_position

	# 1. THE GRIM REAPER (Fixed!)
	for i in range(active_npcs.size() - 1, -1, -1):
		var npc = active_npcs[i]
		
		if is_instance_valid(npc) and not npc.is_queued_for_deletion():
			# Calculate 2D horizontal distance only
			var dist = Vector2(npc.global_position.x, npc.global_position.z).distance_to(Vector2(center_pos.x, center_pos.z))
			
			if dist > despawn_dist:
				npc.queue_free()
				active_npcs.remove_at(i)
		else:
			active_npcs.remove_at(i)

	# 2. THE REINFORCEMENTS
	var space_state = get_world_3d().direct_space_state
	var attempts = 0
	
	while active_npcs.size() < max_npcs and attempts < 10:
		attempts += 1
		
		var random_angle = randf_range(0, TAU)
		var random_dist = randf_range(min_spawn_dist, max_spawn_dist)
		
		var spawn_x = center_pos.x + (cos(random_angle) * random_dist)
		var spawn_z = center_pos.z + (sin(random_angle) * random_dist)
		
		var ray_origin = Vector3(spawn_x, 100.0, spawn_z)
		var ray_end = Vector3(spawn_x, -10.0, spawn_z)
		
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		
		if result and result.position.y <= street_level_max_y:
			var new_npc = npc_scene.instantiate()
			add_child(new_npc)
			
			new_npc.global_position = result.position + Vector3(0, 1.0, 0)
			active_npcs.append(new_npc)
