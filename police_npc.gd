extends CharacterBody3D

const SPEED = 6.0 
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var attack_timer = 0.0

# NEW: Tells the cop to piss off if no one is wanted!
var despawn_timer = 15.0 

func _physics_process(delta):
	if not is_multiplayer_authority(): return 

	if not is_on_floor(): velocity.y -= gravity * delta

	var target = null
	var min_dist = 200.0

	for p in get_parent().get_children():
		if p is CharacterBody3D and p.name.is_valid_int() and "wanted_level" in p:
			if p.wanted_level > 0 and not p.is_dead:
				var dist = global_position.distance_to(p.global_position)
				if dist < min_dist:
					min_dist = dist
					target = p

	if target:
		despawn_timer = 15.0 # Stay alive as long as there is a target
		var dir = (target.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()

		var target_angle = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 12.0 * delta)

		if is_on_wall():
			var wall_normal = get_slide_collision(0).get_normal()
			dir = (dir + wall_normal * 1.5).normalized()

		if min_dist > 3.0:
			velocity.x = dir.x * SPEED
			velocity.z = dir.z * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)

		if min_dist < 25.0:
			attack_timer -= delta
			if attack_timer <= 0:
				attack_timer = 0.8 
				_shoot_at(target)
	else:
		# THE FIX: If player is dead or heat drops, delete yourself!
		despawn_timer -= delta
		if despawn_timer <= 0:
			queue_free()
			
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _shoot_at(target):
	var space_state = get_world_3d().direct_space_state
	var origin = global_position + Vector3(0, 1.2, 0) 
	
	var spread = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	var target_pos = target.global_position + Vector3(0, 1.2, 0) + spread
	
	var query = PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider.name.is_valid_int() or result.collider == target:
			if target.has_method("take_damage"): target.take_damage(10.0)
		rpc("rpc_draw_tracer", origin, result.position)
	else:
		if target.has_method("take_damage"): target.take_damage(10.0)
		rpc("rpc_draw_tracer", origin, target_pos)

@rpc("any_peer", "call_local")
func rpc_draw_tracer(start_pos: Vector3, end_pos: Vector3):
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.2)
	flash.light_energy = 5.0
	get_parent().add_child(flash)
	flash.global_position = start_pos
	
	var tracer = CSGCylinder3D.new()
	tracer.radius = 0.03
	tracer.height = start_pos.distance_to(end_pos)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.material = mat
	get_parent().add_child(tracer)
	tracer.global_position = start_pos.lerp(end_pos, 0.5)
	tracer.look_at(end_pos, Vector3.UP)
	tracer.rotate_x(deg_to_rad(90))
	
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.1)
	flash_tween.tween_callback(flash.queue_free)
	
	var tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(tracer.queue_free)

func take_damage(_amount):
	if is_multiplayer_authority():
		var closest_player = null
		var min_dist = 999.0
		var all_nodes = get_tree().current_scene.find_children("*", "CharacterBody3D", true, false)
		for node in all_nodes:
			if node.name.is_valid_int() and node.has_method("rpc_add_star"): 
				var dist = global_position.distance_to(node.global_position)
				if dist < min_dist:
					min_dist = dist
					closest_player = node

		if closest_player: closest_player.rpc("rpc_add_star")
		
	queue_free() 

@rpc("any_peer", "call_local")
func rpc_force_teleport(dest: Vector3):
	global_position = dest
	velocity = Vector3.ZERO
