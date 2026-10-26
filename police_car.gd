extends CharacterBody3D

const SPEED = 25.0 
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var health = 300.0
var is_destroyed = false

@onready var red_light = get_node_or_null("RedLight")
@onready var blue_light = get_node_or_null("BlueLight")
var light_timer = 0.0
var attack_timer = 0.0

# NEW: Tells the car to piss off if no one is wanted!
var despawn_timer = 15.0

func _physics_process(delta):
	if not is_destroyed:
		light_timer -= delta
		if light_timer <= 0:
			light_timer = 0.25 
			if red_light and blue_light:
				red_light.visible = !red_light.visible
				blue_light.visible = !red_light.visible

	if not is_multiplayer_authority() or is_destroyed: return
	if not is_on_floor(): velocity.y -= gravity * delta

	var target = null
	var min_dist = 300.0

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
		
		if dir.length() > 0.1: 
			dir = dir.normalized()
			
			if is_on_wall():
				var wall_normal = get_slide_collision(0).get_normal()
				dir = (dir + wall_normal * 1.5).normalized()
				
			var target_angle = atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 6.0 * delta) 
			
			var forward = global_transform.basis.z.normalized()
			velocity.x = forward.x * SPEED
			velocity.z = forward.z * SPEED
		else:
			velocity.x = 0
			velocity.z = 0
			
		if min_dist < 35.0:
			attack_timer -= delta
			if attack_timer <= 0:
				attack_timer = 0.4 
				_shoot_at(target)
	else:
		# THE FIX: If player is dead or heat drops, delete yourself!
		despawn_timer -= delta
		if despawn_timer <= 0:
			queue_free()
			
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)

	move_and_slide()

	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is CharacterBody3D and collider.name.is_valid_int():
			if collider.has_method("take_damage"):
				collider.take_damage(40.0)

func _shoot_at(target):
	var space_state = get_world_3d().direct_space_state
	var origin = global_position + Vector3(0, 1.0, 0) 
	
	var spread = Vector3(randf_range(-0.8, 0.8), randf_range(-0.5, 0.5), randf_range(-0.8, 0.8))
	var target_pos = target.global_position + Vector3(0, 1.2, 0) + spread
	
	var query = PhysicsRayQueryParameters3D.create(origin, target_pos)
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider.name.is_valid_int() or result.collider == target:
			if target.has_method("take_damage"): target.take_damage(5.0) 
		rpc("rpc_draw_tracer", origin, result.position)
	else:
		if target.has_method("take_damage"): target.take_damage(5.0) 
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

func take_damage(amount):
	rpc("rpc_police_car_damage", amount)

@rpc("any_peer", "call_local")
func rpc_police_car_damage(amount):
	if is_destroyed: return
	health -= amount
	
	if health <= 0:
		is_destroyed = true
		if red_light: red_light.queue_free()
		if blue_light: blue_light.queue_free()
		
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
		
		var pop = create_tween().set_parallel(true)
		pop.tween_property(self, "global_position:y", global_position.y + 8.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		pop.tween_property(self, "rotation_degrees:x", rotation_degrees.x + randf_range(90, 180), 0.6)
		pop.tween_property(self, "rotation_degrees:z", rotation_degrees.z + randf_range(-180, 180), 0.6)
		
		var meshes = find_children("*", "GeometryInstance3D", true, false)
		var burnt_mat = StandardMaterial3D.new()
		burnt_mat.albedo_color = Color(0.1, 0.1, 0.1)
		burnt_mat.roughness = 1.0
		for m in meshes:
			m.material_override = burnt_mat
		
		await get_tree().create_timer(10.0).timeout
		queue_free()

@rpc("any_peer", "call_local")
func rpc_force_teleport(dest: Vector3):
	global_position = dest
	velocity = Vector3.ZERO
