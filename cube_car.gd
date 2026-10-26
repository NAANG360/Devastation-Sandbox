extends VehicleBody3D

@export var horsepower: float = 500.0
@export var max_steering: float = 0.4

@onready var car_cam = $Camera3D
@onready var interior_cam = $InteriorCam
@onready var horn = $HornSound
@onready var engine_sound = $EngineSound
@onready var left_light = $LeftHeadlight
@onready var right_light = $RightHeadlight

var player
var player_cam
var horn_btn
var light_btn
var speed_label
var camera_btn

var in_car = false
var interact_cooldown = 0.0
var is_third_person = true

func _ready():
	if left_light: left_light.visible = false
	if right_light: right_light.visible = false
	
	# Setup Hit-and-Run Damage!
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_impact)

	var root = get_tree().root
	player = root.find_child("Player", true, false)
	if not player:
		player = root.find_child("CharacterBody3D", true, false) 
		
	if player:
		player_cam = player.find_child("Camera3D", true, false)

	horn_btn = root.find_child("HornBtn", true, false)
	light_btn = root.find_child("LightBtn", true, false)
	speed_label = root.find_child("SpeedLabel", true, false)
	camera_btn = root.find_child("CameraBtn", true, false)
	
	# Force the car to sleep on boot instead of jittering
	engine_force = 0
	steering = 0

func _process(delta):
	if not is_inside_tree(): return
	
	# Fallback just in case the player was dynamically spawned
	if player and not player_cam:
		player_cam = player.find_child("Camera3D", true, false)

	if interact_cooldown > 0:
		interact_cooldown -= delta
		
	if Input.is_action_just_pressed("ui_accept") and interact_cooldown <= 0:
		interact_cooldown = 0.5
		if in_car:
			# --- GETTING OUT ---
			in_car = false
			if car_cam: car_cam.current = false
			if interior_cam: interior_cam.current = false
			
			if horn_btn: horn_btn.visible = false
			if light_btn: light_btn.visible = false
			if speed_label: speed_label.visible = false
			if camera_btn: camera_btn.visible = false
			
			if player:
				player.process_mode = Node.PROCESS_MODE_INHERIT
				player.visible = true
				
				# THE FIX: Find the right door, but force the height (Y) to stay level with the car's wheels
				var eject_pos = to_global(Vector3(3, 0, 0))
				eject_pos.y = global_position.y + 1.0
				player.global_position = eject_pos
				
				player.velocity = Vector3.ZERO
				if player_cam:
					player_cam.make_current()
		else:
			# GETTING IN
			if player and player.visible and global_position.distance_to(player.global_position) < 5.0:
				in_car = true
				if player_cam: player_cam.current = false
				if car_cam: car_cam.rotation = Vector3.ZERO
				if interior_cam: interior_cam.rotation = Vector3.ZERO
				
				if horn_btn: horn_btn.visible = true
				if light_btn: light_btn.visible = true
				if speed_label: speed_label.visible = true
				if camera_btn: camera_btn.visible = true
				
				if is_third_person and car_cam:
					car_cam.current = true
				elif interior_cam:
					interior_cam.current = true
				
				player.process_mode = Node.PROCESS_MODE_DISABLED
				player.visible = false
				player.global_position = Vector3(0, -1000, 0)
				
	if in_car and Input.is_action_just_pressed("ui_focus_next"):
		is_third_person = !is_third_person
		if car_cam: car_cam.current = is_third_person
		if interior_cam: interior_cam.current = !is_third_person
		
	if in_car and Input.is_action_just_pressed("ui_page_up"):
		if horn: horn.play()
		
	if in_car and Input.is_action_just_pressed("ui_home"):
		if left_light: left_light.visible = !left_light.visible
		if right_light: right_light.visible = !right_light.visible

func _physics_process(delta):
	if not is_inside_tree(): return

	var current_speed = linear_velocity.length()
	
	if in_car:
		if speed_label:
			speed_label.text = str(int(current_speed * 3.6)) + " KM/H"
		
		var gas_input = Input.get_axis("ui_up", "ui_down")
		var target_engine = gas_input * horsepower
		var target_steer = Input.get_axis("ui_right", "ui_left") * max_steering
		
		if engine_sound:
			var target_pitch = 1.0 + (current_speed / 15.0) + (abs(gas_input) * 0.8)
			target_pitch = clamp(target_pitch, 1.0, 3.0)
			engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, 8.0 * delta)
		
		engine_force = lerp(engine_force, target_engine, 5.0 * delta)
		steering = lerp(steering, target_steer, 5.0 * delta)
	else:
		# INSTANTLY CUT POWER. LET THE PHYSICS ENGINE SLEEP.
		engine_force = 0
		steering = 0

# ==========================================
#         HIT AND RUN SYSTEM
# ==========================================
func _on_impact(body):
	var speed = linear_velocity.length()
	
	# If moving faster than ~10mph, crush whatever we hit
	if speed > 4.0:
		var damage = speed * 15.0 # Example: 20m/s speed = 300 damage
		
		if body.has_method("take_damage"): body.take_damage(damage)
		elif body.has_method("TakeDamage"): body.TakeDamage(damage)
		elif "health" in body:
			body.health -= damage
			if body.health <= 0 and body.has_method("die"): body.die()
