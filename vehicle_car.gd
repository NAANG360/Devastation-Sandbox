extends VehicleBody3D

@export var max_engine_force: float = 500.0
@export var max_brake_force: float = 30.0
@export var max_steering_angle: float = 0.5
@export var reverse_throttle: bool = true 
@export var reverse_steering: bool = false 

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

var in_car: bool = false
var interact_cooldown: float = 0.0
var is_third_person: bool = true
var is_active_car: bool = false 

var current_throttle: float = 0.0
var current_steer: float = 0.0

var health: float = 150.0
var is_destroyed: bool = false

func _ready():
	if car_cam: car_cam.current = false
	if interior_cam: interior_cam.current = false
	if left_light: left_light.visible = false
	if right_light: right_light.visible = false

func _physics_process(delta):
	if not is_active_car or not is_inside_tree(): return
	
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
	
	var player_close = false
	if player and player.visible and global_position.distance_to(player.global_position) < 8.0:
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
			
			engine_force = 0.0
			brake = max_brake_force
			current_throttle = 0.0
			current_steer = 0.0
			
			if player:
				player.set("current_car", null) # Tell the player they left the car
				player.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
				player.visible = true
				
				if player.has_method("set_driving_ui"):
					player.set_driving_ui(false)
					
				var eject_pos = global_position + global_transform.basis.x * 3.0
				eject_pos.y += 1.0
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
				player.set("current_car", self) # Tell the player which car they are in for the phone app!
				if player.has_method("set_driving_ui"):
					player.set_driving_ui(true)
					
				player.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
				player.visible = false
				player.global_position = Vector3(0, 5000, 0)

	var visual_speed = linear_velocity.length()
	
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

		var target_throttle = Input.get_axis("ui_down", "ui_up")
		if reverse_throttle: target_throttle = -target_throttle 
		
		var target_steering = Input.get_axis("ui_right", "ui_left")
		if reverse_steering: target_steering = -target_steering
		
		current_throttle = move_toward(current_throttle, target_throttle, 1.5 * delta)
		engine_force = current_throttle * max_engine_force
		
		current_steer = lerp(current_steer, target_steering, 3.0 * delta)
		steering = current_steer * max_steering_angle
		
		brake = 0.0
		
		if engine_sound:
			if not engine_sound.playing: engine_sound.play()
			var target_pitch = 1.0 + (visual_speed / 20.0)
			if target_throttle != 0: target_pitch += 0.5
			engine_sound.pitch_scale = clamp(lerp(engine_sound.pitch_scale, target_pitch, 5.0 * delta), 1.0, 3.0)
	else:
		if visual_speed > 0.5:
			brake = 5.0
			engine_force = 0.0
		else:
			brake = max_brake_force
			engine_force = 0.0
			
		if engine_sound and engine_sound.playing:
			engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, 1.0, 5.0 * delta)

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
		apply_central_impulse(Vector3.UP * 400.0 * mass)
		apply_torque_impulse(Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)) * mass)
		
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
		# Safety check: Only paint the body, not the tires/windows! 
		# (Make sure your main mesh has "Body" in its name, or remove this IF statement)
		if "body" in m.name.to_lower() or "mesh" in m.name.to_lower():
			var material = StandardMaterial3D.new()
			material.albedo_color = new_color
			
			# If you have multiple materials on the body, 0 is usually the main paint
			m.set_surface_override_material(0, material)
