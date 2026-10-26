extends CharacterBody3D

@export var model_faces_backwards: bool = false 

var health: float = 100.0
var walk_speed: float = 3.0 
var run_speed: float = 8.0  
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var state: String = "IDLE" 
var target_pos: Vector3
var state_timer: float = 0.0

@onready var start_pos: Vector3 = global_position
var anim: AnimationPlayer

var idle_anim_name: String = "Animation"
var walk_anim_name: String = "walk"

func _ready():
	anim = find_child("AnimationPlayer", true, false)
	pick_new_wander_target()

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if state == "DEAD":
		move_and_slide()
		return

	state_timer -= delta
	
	if state == "IDLE":
		velocity.x = move_toward(velocity.x, 0, walk_speed)
		velocity.z = move_toward(velocity.z, 0, walk_speed)
		if anim and anim.current_animation != idle_anim_name: anim.play(idle_anim_name)
		if state_timer <= 0: pick_new_wander_target()
			
	elif state == "WANDER":
		var dir = global_position.direction_to(target_pos)
		dir.y = 0
		dir = dir.normalized()
		
		if is_on_wall():
			var wall_normal = get_slide_collision(0).get_normal()
			dir = (dir + wall_normal).normalized()
			if state_timer < 6.0: pick_new_wander_target()
		
		velocity.x = dir.x * walk_speed
		velocity.z = dir.z * walk_speed
		if anim and anim.current_animation != walk_anim_name: anim.play(walk_anim_name)
		
		if velocity.length() > 0.1:
			var look_dir = -velocity if model_faces_backwards else velocity
			var look_target = global_position + look_dir
			look_target.y = global_position.y
			look_at(look_target, Vector3.UP)
			
		if global_position.distance_to(target_pos) < 1.0 or state_timer <= 0:
			state = "IDLE"
			state_timer = randf_range(2.0, 5.0) 
			
	elif state == "FLEE":
		var dir = global_position.direction_to(target_pos)
		dir.y = 0
		dir = dir.normalized()
		
		if is_on_wall():
			var wall_normal = get_slide_collision(0).get_normal()
			dir = (dir + wall_normal * 2.0).normalized()
		
		velocity.x = dir.x * run_speed
		velocity.z = dir.z * run_speed
		
		if anim:
			if anim.current_animation != walk_anim_name: anim.play(walk_anim_name)
			anim.speed_scale = 1.5 
			
		if velocity.length() > 0.1:
			var look_dir = -velocity if model_faces_backwards else velocity
			var look_target = global_position + look_dir
			look_target.y = global_position.y
			look_at(look_target, Vector3.UP)
			
		if state_timer <= 0:
			if anim: anim.speed_scale = 1.0
			state = "WANDER"
			pick_new_wander_target()

	move_and_slide()

func pick_new_wander_target():
	state = "WANDER"
	state_timer = randf_range(4.0, 8.0) 
	var rand_x = randf_range(-10.0, 10.0)
	var rand_z = randf_range(-10.0, 10.0)
	target_pos = start_pos + Vector3(rand_x, 0, rand_z)

func take_damage(amount: float):
	if state == "DEAD": return
	health -= amount
	if health <= 0:
		die()
		return
		
	state = "FLEE"
	state_timer = 4.0 
	
	var closest_player = null
	var min_dist = 999.0
	var all_nodes = get_tree().current_scene.find_children("*", "CharacterBody3D", true, false)
	for node in all_nodes:
		if node.name.is_valid_int() and node.has_method("rpc_add_star"): 
			var dist = global_position.distance_to(node.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_player = node

	if closest_player:
		var flee_dir = closest_player.global_position.direction_to(global_position)
		flee_dir.y = 0
		target_pos = global_position + (flee_dir.normalized() * 20.0)
	else:
		pick_new_wander_target()

func die():
	if state == "DEAD": return
	state = "DEAD"
	velocity = Vector3.ZERO
	if anim: anim.stop() 
	
	var col = get_node_or_null("CollisionShape3D")
	if col: col.set_deferred("disabled", true)
	
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees:x", 90.0, 0.3).set_trans(Tween.TRANS_SINE)
	
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
		
	await get_tree().create_timer(4.0).timeout
	queue_free()

# THE FIX: Allow Kamui and Domain to pull NPCs
@rpc("any_peer", "call_local")
func rpc_force_teleport(dest: Vector3):
	global_position = dest
	velocity = Vector3.ZERO
