extends CharacterBody3D

@export var top_speed: float = 30.0
@export var acceleration: float = 5.0 
@export var braking: float = 15.0
@export var steering_speed: float = 1.2
@export var drift_grip: float = 2.0 
@export var model_faces_backwards: bool = false

@onready var car_cam = get_node_or_null("Camera3D")
@onready var interior_cam = get_node_or_null("InteriorCam")
@onready var horn = get_node_or_null("HornSound")
@onready var engine_sound = get_node_or_null("EngineSound")
@onready var left_light = get_node_or_null("LeftHeadlight")
@onready var right_light = get_node_or_null("RightHeadlight")

var player = null
var player_cam = null

var horn_btn = null
var light_btn = null
var speed_label = null
var camera_btn = null

var in_car = false
var interact_cooldown = 0.0
var is_third_person = true
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var current_forward_speed: float = 0.0 
var current_steering: float = 0.0

var health: float = 150.0
var is_destroyed: bool = false

func _ready():
	if car_cam: car_cam.current = false
	if interior_cam: interior_cam.current = false
	if left_light: left_light.visible = false
	if right_light: right_light.visible = false

func _physics_process(delta):
	if not is_inside_tree(): return
	
	# =========================================================
	# MULTIPLAYER FIX: ONLY LOOK FOR *YOUR* LOCAL PLAYER & UI!
	# =========================================================
	if not player:
		var local_id = multiplayer.get_unique_id()
		var current_map = get_tree().current_scene
		if current_map:
			player = current_map.find_child(str(local_id), true, false)
			if player: 
				player_cam = player.find_child("Camera3D", true, false)
				horn_btn = player.find_child("HornBtn", true, false)
				light_btn = player.find_child("LightBtn", true, false)
				speed_label = player.find_child("SpeedLabel", true, false)
				camera_btn = player.find_child("CameraBtn", true, false)
	
	if interact_cooldown > 0: interact_cooldown -= delta
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	var player_close = false
	if player and player.visible and global_position.distance_to(player.global_position) < 15.0:
		player_close = true
		
	if Input.is_action_just_pressed("ui_accept") and (in_car or player_close) and interact_cooldown <= 0:
		interact_cooldown = 0.5
		if in_car:
			in_car = false
			if car_cam: car_cam.current = false
			if interior_cam: interior_cam.current = false
			
			if horn_btn: horn_btn.visible = false
			if light_btn: light_btn.visible = false
			if speed_label: speed_label.visible = false
			if camera_btn: camera_btn.visible = false
			
			if player:
				player.set("current_car", null) # Tell player they left
				player.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
				player.visible = true
				
				if player.has_method("set_driving_ui"):
					player.set_driving_ui(false)
				
				var eject_pos = to_global(Vector3(3, 0, 0))
				eject_pos.y = global_position.y + 1.0
				player.global_position = eject_pos
				player.velocity = Vector3.ZERO
				
				if "last_y_velocity" in player:
					player.last_y_velocity = 0.0 
					
				if player_cam: player_cam.make_current()
		else:
			in_car = true
			if player_cam: player_cam.current = false
			
			if horn_btn: horn_btn.visible = true
			if light_btn: light_btn.visible = true
			if speed_label: speed_label.visible = true
			if camera_btn: camera_btn.visible = true
			
			if is_third_person and car_cam: car_cam.current = true
			elif interior_cam: interior_cam.current = true
			
			if player:
				player.set("current_car", self) # Connect the car for the phone spray app!
				if player.has_method("set_driving_ui"):
					player.set_driving_ui(true)
				
				player.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
				player.visible = false
				player.global_position = Vector3(0, 5000, 0)
				
	var visual_speed = abs(current_forward_speed)
				
	if in_car:
		if speed_label: speed_label.text = str(int(visual_speed * 3.6)) + " KM/H"
		
		if Input.is_action_just_pressed("ui_focus_next"):
			is_third_person = !is_third_person
			if car_cam: car_cam.current = is_third_person
			if interior_cam: interior_cam.current = !is_third_person
			
		if Input.is_action_just_pressed("ui_page_up") and horn: horn.play()
		if Input.is_action_just_pressed("ui_home"):
			if left_light: left_light.visible = !left_light.visible
			if right_light: right_light.visible = !right_light.visible

		var gas = Input.get_axis("ui_down", "ui_up") 
		var steer = Input.get_axis("ui_right", "ui_left") 
		
		if gas > 0: 
			if current_forward_speed < -0.1: current_forward_speed = move_toward(current_forward_speed, 0.0, braking * 2.0 * delta)
			else: current_forward_speed = move_toward(current_forward_speed, gas * top_speed, acceleration * delta)
		elif gas < 0: 
			if current_forward_speed > 0.1: current_forward_speed = move_toward(current_forward_speed, 0.0, braking * 2.0 * delta)
			else: current_forward_speed = move_toward(current_forward_speed, gas * (top_speed / 2.0), acceleration * delta)
		else: 
			current_forward_speed = move_toward(current_forward_speed, 0.0, braking * delta)

		var target_steering = steer * steering_speed
		current_steering = lerp(current_steering, target_steering, 3.0 * delta)

		if engine_sound:
			if not engine_sound.playing: engine_sound.play()
			var target_pitch = 1.0 + (visual_speed / 20.0)
			if gas != 0: target_pitch += 0.8
			engine_sound.pitch_scale = clamp(lerp(engine_sound.pitch_scale, target_pitch, 8.0 * delta), 1.0, 3.5)
		
		if visual_speed > 1.0:
			var direction_flip = 1.0 if current_forward_speed > 0 else -1.0
			rotation.y += current_steering * delta * direction_flip
			
		var forward_dir = global_transform.basis.z.normalized()
		if not model_faces_backwards: forward_dir = -forward_dir 
			
		var target_velocity = forward_dir * current_forward_speed
		velocity.x = lerp(velocity.x, target_velocity.x, drift_grip * delta)
		velocity.z = lerp(velocity.z, target_velocity.z, drift_grip * delta)
		
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var victim = collision.get_collider()
			if victim and visual_speed > 5.0 and victim.has_method("take_damage"):
				victim.take_damage(200.0)
				
	else:
		current_forward_speed = move_toward(current_forward_speed, 0.0, braking * delta)
		var forward_dir = global_transform.basis.z.normalized()
		if not model_faces_backwards: forward_dir = -forward_dir
			
		var target_velocity = forward_dir * current_forward_speed
		velocity.x = lerp(velocity.x, target_velocity.x, drift_grip * delta)
		velocity.z = lerp(velocity.z, target_velocity.z, drift_grip * delta)
		
		if engine_sound and engine_sound.playing:
			engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, 1.0, 5.0 * delta)
			
	move_and_slide()

# ==========================================
# DAMAGE LOGIC
# ==========================================
func take_damage(amount):
	rpc("rpc_take_car_damage", amount)

@rpc("any_peer", "call_local")
func rpc_take_car_damage(amount):
	if is_destroyed: return
	health -= amount
	
	if health <= 0:
		is_destroyed = true
		
		var pop = create_tween().set_parallel(true)
		pop.tween_property(self, "global_position:y", global_position.y + 8.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		pop.tween_property(self, "rotation_degrees:x", rotation_degrees.x + randf_range(90, 180), 0.6)
		pop.tween_property(self, "rotation_degrees:z", rotation_degrees.z + randf_range(-180, 180), 0.6)
		
		var meshes = find_children("*", "MeshInstance3D", true, false)
		for m in meshes:
			var burnt_mat = StandardMaterial3D.new()
			burnt_mat.albedo_color = Color(0.15, 0.15, 0.15) 
			burnt_mat.roughness = 1.0
			m.material_override = burnt_mat

# ==========================================
# PHONE APP PAINT LOGIC
# ==========================================
@rpc("any_peer", "call_local")
func set_car_color(new_color: Color):
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		if "body" in m.name.to_lower() or "mesh" in m.name.to_lower():
			var material = StandardMaterial3D.new()
			material.albedo_color = new_color
			m.set_surface_override_material(0, material)
