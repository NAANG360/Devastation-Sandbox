extends RigidBody3D

@onready var blast_zone = find_child("BlastZone", true, false)
var is_stuck = false
var is_detonated = false # New flag to track if it's currently on fire

func _ready():
	contact_monitor = true
	max_contacts_reported = 3
	continuous_cd = true 
	body_entered.connect(_on_body_entered)

# THE MISSING FUNCTION IS BACK!
func _on_body_entered(body):
	if is_stuck or is_detonated: return
	if body is CharacterBody3D: return 
	
	is_stuck = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	set_deferred("freeze", true) 

func _physics_process(delta):
	# FIRE HAZARD: Burn any players standing in the blast zone!
	if is_detonated and is_instance_valid(blast_zone):
		for body in blast_zone.get_overlapping_bodies():
			if body is CharacterBody3D and body.has_method("rpc_catch_fire"):
				body.rpc("rpc_catch_fire")
	
	if is_stuck or is_detonated: return
	
	var space_state = get_world_3d().direct_space_state
	var look_ahead = global_position + (linear_velocity * delta * 1.5)
	var query = PhysicsRayQueryParameters3D.create(global_position, look_ahead)
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	if result and not result.collider is CharacterBody3D:
		global_position = result.position
		is_stuck = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		set_deferred("freeze", true)

@rpc("any_peer", "call_local")
func rpc_detonate():
	if is_detonated: return
	is_detonated = true
	
	# 1. Hide the physical C4 block so it looks like it was destroyed
	visible = false
	
	# 2. INSTANT VISUAL EXPLOSION
	var flash = OmniLight3D.new()
	flash.light_color = Color(1.0, 0.4, 0.0)
	flash.light_energy = 15.0
	flash.omni_range = 40.0
	get_parent().add_child(flash)
	flash.global_position = global_position
	
	var boom = CSGSphere3D.new()
	boom.radius = 0.5
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(1.0, 0.3, 0.0)
	b_mat.emission_enabled = true
	b_mat.emission = Color(1.0, 0.2, 0.0)
	b_mat.emission_energy_multiplier = 8.0
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	boom.material = b_mat
	get_parent().add_child(boom)
	boom.global_position = global_position

	var t = create_tween().set_parallel(true)
	t.tween_property(boom, "radius", 15.0, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(b_mat, "albedo_color:a", 0.0, 0.3)
	t.tween_property(flash, "light_energy", 0.0, 0.3)
	t.chain().tween_callback(boom.queue_free)
	t.parallel().tween_callback(flash.queue_free)

	# 3. INITIAL BLAST DAMAGE
	if blast_zone:
		var victims = blast_zone.get_overlapping_bodies()
		for victim in victims:
			if victim == self: continue
			
			var blast_dir = (victim.global_position - global_position).normalized()
			blast_dir.y += 0.5 
			
			if victim.has_method("take_damage"): victim.take_damage(200.0)
			
			if victim is CharacterBody3D: 
				victim.global_position += (blast_dir * 30.0 * 0.016)
			elif victim is RigidBody3D or victim is VehicleBody3D: 
				victim.apply_central_impulse(blast_dir * 250.0 * victim.mass)
			
	# 4. CREATE THE LINGERING FIRE EFFECT
	if blast_zone:
		blast_zone.scale = Vector3(6, 6, 6) # Expand the Area3D to catch players
		
	var fire_mesh = CSGSphere3D.new()
	fire_mesh.radius = 6.0
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(1.0, 0.4, 0.0, 0.3)
	f_mat.emission_enabled = true
	f_mat.emission = Color(1.0, 0.2, 0.0)
	f_mat.emission_energy_multiplier = 3.0
	f_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mesh.material = f_mat
	add_child(fire_mesh) # Attach fire to the C4 body
	
	var fade_fire = create_tween()
	fade_fire.tween_interval(5.0) # Stay burning for 5 seconds
	fade_fire.tween_property(f_mat, "albedo_color:a", 0.0, 1.0) # Fade out smoothly
	
	await get_tree().create_timer(6.0).timeout
	queue_free() # Finally delete the C4 entirely
