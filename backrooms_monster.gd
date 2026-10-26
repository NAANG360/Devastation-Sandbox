extends CharacterBody3D

@export var speed: float = 4.5
var player_target: Node3D = null
var nav_agent: NavigationAgent3D

func _ready():
	# The scale multiplier. 7 makes this an absolute titan.
	var monster_scale: float = 7.0
	
	# 1. AUTOMATICALLY BUILD THE SHADOW DEMON
	var mesh_inst = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.4 * monster_scale
	capsule.height = 2.4 * monster_scale 
	mesh_inst.mesh = capsule
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.0, 0.0) # Faint red glow
	mesh_inst.material_override = mat
	# Lift the mesh so its feet touch the floor
	mesh_inst.position.y = 1.2 * monster_scale
	add_child(mesh_inst)
	
	# 2. AUTOMATICALLY BUILD THE FLAWLESS HITBOX
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4 * monster_scale
	shape.height = 2.4 * monster_scale
	col.shape = shape
	# Lift the hitbox exactly the same amount
	col.position.y = 1.2 * monster_scale
	add_child(col)
	
	# 3. ADD AI NAVIGATION
	nav_agent = NavigationAgent3D.new()
	add_child(nav_agent)

func _physics_process(delta):
	# Look for the player if it doesn't have them yet
	if not is_instance_valid(player_target):
		_find_player()
		return
		
	# Hunt the player
	nav_agent.target_position = player_target.global_position
	var next_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_pos)
	direction.y = 0.0 
	direction = direction.normalized()
	
	# Face the player
	var look_pos = player_target.global_position
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos, Vector3.UP)
		
	velocity = direction * speed
	move_and_slide()
	
	# Jumpscare / Kill Check
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() == player_target:
			_catch_player(player_target)

func _find_player():
	var all_bodies = get_tree().current_scene.find_children("*", "CharacterBody3D", true, false)
	for body in all_bodies:
		if body.has_method("_btn_car") and body.is_multiplayer_authority():
			player_target = body
			break

func _catch_player(target):
	# Drop sanity to zero, kicking them out of the backrooms via the player script logic
	if "sanity" in target:
		target.sanity = 0.0
	target.global_position = Vector3(0, 10, 0) 
	queue_free()
