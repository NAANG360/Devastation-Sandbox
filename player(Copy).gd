extends CharacterBody3D

@export var model_faces_backwards: bool = false
@export var virtual_steering: CanvasItem
@export var walk_joystick: CanvasItem
@export var gas_pedal: CanvasItem
@export var brake_pedal: CanvasItem
@export var punch_button: CanvasItem     
@export var weapon_wheel_icon: CanvasItem 
@export var pistol_model: Node3D
@export var shotgun_model: Node3D
@export var rifle_model: Node3D
@export var shotgun_anim: AnimationPlayer 

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var is_admin = get_tree().root.get_meta("is_admin", false)
@onready var abilities = get_node_or_null("AbilitiesManager")

var max_health = 100.0
var current_health = 100.0
var last_y_velocity = 0.0
var is_dead = false 
@onready var health_bar = $CanvasLayer/ProgressBar 

var cam: Camera3D
var anim: AnimationPlayer
var player_model: Node3D
var in_water_zone: bool = false
var is_drowning: bool = false
var drown_tick: float = 0.0
var procedural_water: CSGBox3D = null

var record_bus_index: int
var audio_effect_capture: AudioEffectCapture
var voice_playback: AudioStreamGeneratorPlayback
@onready var voice_output = get_node_or_null("VoiceOutput") 
@onready var mic_capture = get_node_or_null("MicCapture")

@onready var minimap_viewport = find_child("MinimapViewport", true, false)
@onready var minimap_cam = find_child("MinimapCamera", true, false)
@onready var minimap_pointer = find_child("MinimapPointer", true, false)
@onready var name_tag = find_child("NameTag", true, false)

var kamui_location: Vector3 = Vector3(0, -4998, 0)
var in_kamui: bool = false
var real_world_pos: Vector3
var is_flying: bool = false
var active_chibaku_core: Node3D = null
var active_chibaku_area: Area3D = null

@export var nine_tails_scene: PackedScene 
var is_riding: bool = false
var my_beast: Node3D = null

@export var police_npc_scene: PackedScene
@export var police_car_scene: PackedScene 
var wanted_level: int = 0
var police_spawn_timer: float = 0.0
var evil_points: float = 0.0
var wanted_cooldown: float = 0.0
@onready var stars_label = find_child("StarsLabel", true, false)

@export var c4_scene: PackedScene
@export var meteor_scene: PackedScene
var active_c4s = [] 
@onready var detonate_btn = find_child("DetonateBtn", true, false)
@onready var meteor_btn = find_child("MeteorBtn", true, false)

var is_on_fire: bool = false
var fire_timer: float = 0.0
var fire_tick: float = 0.0
var fire_visual: Node3D = null

@export var car_scenes: Array[PackedScene] = [] 
@export var car_spawn_distance: float = 8.0 
@export var car_spawn_height: float = 4.0   
var current_car_index: int = -1 
var active_car_instance: Node3D = null

var is_ragdolling: bool = false
var ragdoll_velocity: Vector3 = Vector3.ZERO
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var is_awakened: bool = false
var awaken_timer: float = 0.0
var awakened_aura: Node3D = null

@onready var kamui_zone = $KamuiZone
@onready var push_zone = $PushZone 
@onready var admin_ui = $AdminUI
@onready var kamui_btn = find_child("Button", true, false)
@onready var push_btn = find_child("PushButton", true, false)
@onready var flight_btn = find_child("FlightButton", true, false) 
@onready var chibaku_btn = find_child("ChibakuButton", true, false)
@onready var summon_btn = find_child("SummonButton", true, false) 
@onready var bomb_btn = find_child("BombButton", true, false) 
@onready var genjutsu_btn = find_child("GenjutsuButton", true, false)
@onready var awaken_btn = find_child("AwakenBtn", true, false)
@onready var domain_btn = find_child("DomainBtn", true, false)
@onready var blades_btn = find_child("BladesBtn", true, false)
@onready var susanoo_btn = find_child("SusanooBtn", true, false)
@onready var amaterasu_btn = find_child("AmaterasuBtn", true, false)
@onready var beelzebuth_btn = find_child("BeelzebuthBtn", true, false)
@onready var sage_btn = find_child("SageBtn", true, false)
@onready var dragon_btn = find_child("DragonBtn", true, false)
@onready var genjutsu_ui = $GenjutsuUI
@onready var weapon_wheel = find_child("WeaponWheel", true, false)
@onready var wheel_btn = find_child("WheelButton", true, false)
@onready var attack_btn = find_child("AttackButton", true, false)
@onready var death_screen = find_child("DeathScreen", true, false)
@onready var respawn_btn = find_child("RespawnBtn", true, false)

@onready var travel_menu = find_child("TravelMenu", true, false)
var travel_menu_tween: Tween
var sage_ui_rect: TextureRect = null

var current_weapon: String = "Fists"
var can_attack: bool = true
var crosshair: ColorRect

@onready var kamui_sound = $KamuiSound
@onready var push_sound = $PushSound 
@onready var summon_sound = $SummonSound 
@onready var gun_sound = $GunSound 

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	if has_node("CanvasLayer"): $CanvasLayer.process_mode = Node.PROCESS_MODE_ALWAYS 
	scale = Vector3(1, 1, 1)
	cam = find_child("Camera3D", true, false)
	anim = find_child("AnimationPlayer", true, false)
	if anim: player_model = anim.get_parent() 
	if travel_menu: travel_menu.hide()
	
	if is_multiplayer_authority():
		var my_name = GlobalData.username
		if my_name == "": my_name = "Citizen " + str(multiplayer.get_unique_id()).left(4)
		rpc("rpc_set_username", my_name)
		if name_tag: name_tag.hide() 
	else: call_deferred("_ask_for_name")

	if not is_multiplayer_authority():
		if cam: cam.current = false
		if has_node("CanvasLayer"): $CanvasLayer.queue_free()
		if admin_ui: admin_ui.queue_free()
		if genjutsu_ui: genjutsu_ui.queue_free()
		if minimap_pointer: minimap_pointer.hide()
		if is_instance_valid(player_model):
			if is_instance_valid(pistol_model) and pistol_model.get_parent():
				pistol_model.get_parent().remove_child(pistol_model)
				player_model.add_child(pistol_model)
				pistol_model.position = Vector3(0.4, 1.0, 0.4) 
			if is_instance_valid(shotgun_model) and shotgun_model.get_parent():
				shotgun_model.get_parent().remove_child(shotgun_model)
				player_model.add_child(shotgun_model)
				shotgun_model.position = Vector3(0.4, 1.0, 0.4)
			if is_instance_valid(rifle_model) and rifle_model.get_parent():
				rifle_model.get_parent().remove_child(rifle_model)
				player_model.add_child(rifle_model)
				rifle_model.position = Vector3(0.4, 1.0, 0.4)
	else:
		if cam: cam.make_current()
		if is_instance_valid(minimap_viewport): minimap_viewport.world_3d = get_viewport().world_3d
			
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		
	if admin_ui: admin_ui.visible = is_admin or (not is_admin and GlobalData.has_beast)
	if is_admin:
		if kamui_btn: kamui_btn.pressed.connect(_btn_kamui)
		if push_btn: push_btn.pressed.connect(func(): if is_instance_valid(abilities): abilities.rpc("rpc_almighty_push"))
		if flight_btn: flight_btn.pressed.connect(toggle_flight) 
		if chibaku_btn: chibaku_btn.pressed.connect(_btn_chibaku)
		if summon_btn: summon_btn.pressed.connect(_btn_summon)
		if bomb_btn: bomb_btn.pressed.connect(func(): if is_instance_valid(abilities): abilities.rpc("rpc_beast_special", 9))
		if genjutsu_btn: genjutsu_btn.pressed.connect(_btn_genjutsu)
		if awaken_btn: awaken_btn.pressed.connect(_btn_awaken)
		if domain_btn: domain_btn.pressed.connect(_btn_domain)
		if blades_btn: blades_btn.pressed.connect(_btn_blades)
		if susanoo_btn: susanoo_btn.pressed.connect(_btn_susanoo)
		if amaterasu_btn: amaterasu_btn.pressed.connect(_btn_amaterasu)
		if meteor_btn: meteor_btn.pressed.connect(_btn_meteor)
		if beelzebuth_btn: beelzebuth_btn.pressed.connect(_btn_beelzebuth)
		if sage_btn: sage_btn.pressed.connect(_toggle_autobattle)
		if dragon_btn: dragon_btn.pressed.connect(func(): if is_instance_valid(abilities): abilities.rpc("rpc_true_dragon_liberation"))
		
		if domain_btn: domain_btn.visible = false
		if blades_btn: blades_btn.visible = false
		if susanoo_btn: susanoo_btn.visible = false
		if amaterasu_btn: amaterasu_btn.visible = false
		if meteor_btn: meteor_btn.visible = false
		if beelzebuth_btn: beelzebuth_btn.visible = false
		if sage_btn: sage_btn.visible = false
		if dragon_btn: dragon_btn.visible = false
	elif not is_admin and GlobalData.has_beast:
		if awaken_btn: 
			awaken_btn.text = "Chakra Mode"
			awaken_btn.pressed.connect(_btn_chakra_mode)
			awaken_btn.visible = true
		if bomb_btn:
			bomb_btn.text = "Beast Blast"
			bomb_btn.pressed.connect(func(): if is_instance_valid(abilities): abilities.rpc("rpc_beast_special", GlobalData.current_beast_id))
			bomb_btn.visible = false 
		if push_btn:
			push_btn.text = "Beast Special"
			push_btn.pressed.connect(func(): if is_instance_valid(abilities): abilities.rpc("rpc_beast_special", GlobalData.current_beast_id))
			push_btn.visible = false 
			
		if kamui_btn: kamui_btn.visible = false
		if flight_btn: flight_btn.visible = false
		if chibaku_btn: chibaku_btn.visible = false
		if summon_btn: summon_btn.visible = false
		if genjutsu_btn: genjutsu_btn.visible = false
		if domain_btn: domain_btn.visible = false
		if blades_btn: blades_btn.visible = false
		if susanoo_btn: susanoo_btn.visible = false
		if amaterasu_btn: amaterasu_btn.visible = false
		if meteor_btn: meteor_btn.visible = false
		if beelzebuth_btn: beelzebuth_btn.visible = false
		if sage_btn: sage_btn.visible = false
		if dragon_btn: dragon_btn.visible = false
		
	if genjutsu_ui: genjutsu_ui.visible = false
	if death_screen: death_screen.visible = false
	if respawn_btn: respawn_btn.pressed.connect(_btn_respawn)
	
	crosshair = ColorRect.new()
	crosshair.name = "DynamicCrosshair"
	crosshair.custom_minimum_size = Vector2(6, 6)
	crosshair.size = Vector2(6, 6)
	crosshair.color = Color.WHITE
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.visible = false
	if has_node("CanvasLayer"): $CanvasLayer.add_child(crosshair)
	
	if weapon_wheel: weapon_wheel.visible = false
	if wheel_btn: wheel_btn.pressed.connect(toggle_weapon_wheel)
	if attack_btn: attack_btn.pressed.connect(_btn_attack)
	if detonate_btn: 
		detonate_btn.pressed.connect(_btn_detonate)
		detonate_btn.visible = false
	
	var car_btn = find_child("CarButton", true, false)
	if car_btn: car_btn.pressed.connect(_btn_car) 
	
	var btn_fists = find_child("BtnFists", true, false)
	var btn_pistol = find_child("BtnPistol", true, false)
	var btn_shotgun = find_child("BtnShotgun", true, false)
	var btn_rifle = find_child("BtnRifle", true, false)
	var btn_c4 = find_child("BtnC4", true, false)
	if btn_fists: btn_fists.pressed.connect(func(): _equip_and_close("Fists"))
	if btn_pistol: btn_pistol.pressed.connect(func(): _equip_and_close("Pistol"))
	if btn_shotgun: btn_shotgun.pressed.connect(func(): _equip_and_close("Shotgun"))
	if btn_rifle: btn_rifle.pressed.connect(func(): _equip_and_close("Rifle"))
	if btn_c4: btn_c4.pressed.connect(func(): _equip_and_close("C4"))
	
	if attack_btn: attack_btn.text = "Attack: Fists"
	rpc_equip_weapon("Fists")
	
	if is_instance_valid(gas_pedal): gas_pedal.visible = false
	if is_instance_valid(brake_pedal): brake_pedal.visible = false
	if is_instance_valid(virtual_steering): virtual_steering.visible = false
	if has_node("CanvasLayer"):
		for btn in $CanvasLayer.find_children("*", "Button", true, false): btn.focus_mode = Control.FOCUS_NONE
	if admin_ui:
		for btn in admin_ui.find_children("*", "Button", true, false): btn.focus_mode = Control.FOCUS_NONE
			
	if is_instance_valid(player_model) and is_instance_valid(cam):
		_force_model_to_layer_two(player_model)
		cam.set_cull_mask_value(2, false) 
		
	call_deferred("_setup_chat_interceptor")
	
	if is_instance_valid(minimap_pointer) and minimap_pointer is VisualInstance3D:
		minimap_pointer.set_layer_mask_value(1, false)
		minimap_pointer.set_layer_mask_value(2, true)

func _setup_chat_interceptor():
	if not is_multiplayer_authority(): return 
	var active_scene = get_tree().current_scene
	if not active_scene: return
	
	var send_btn = active_scene.find_child("SendBtn", true, false)
	var chat_input = active_scene.find_child("ChatInput", true, false)
	
	if send_btn:
		for conn in send_btn.pressed.get_connections():
			send_btn.pressed.disconnect(conn.callable)
		send_btn.pressed.connect(_intercept_chat_message)
		
	if chat_input:
		for conn in chat_input.text_submitted.get_connections():
			chat_input.text_submitted.disconnect(conn.callable)
		chat_input.text_submitted.connect(_intercept_chat_message_submit)

func _intercept_chat_message_submit(_new_text):
	_intercept_chat_message()

func _find_node_with_method(start_node: Node, method_name: String) -> Node:
	if start_node.has_method(method_name): return start_node
	for child in start_node.get_children():
		var result = _find_node_with_method(child, method_name)
		if result: return result
	return null

func _intercept_chat_message():
	var active_scene = get_tree().current_scene
	if not active_scene: return
	
	var input_box = active_scene.find_child("ChatInput", true, false)
	if not input_box: return
	
	var msg = input_box.text.strip_edges()
	input_box.text = "" 
	
	get_viewport().gui_release_focus()
	var send_btn = active_scene.find_child("SendBtn", true, false)
	if send_btn: send_btn.release_focus()
	
	if msg == "": return
	var net_node = _find_node_with_method(active_scene, "rpc_receive_message")
	
	# ==========================================
	# DYNAMIC NETWORK MANAGER SPAWN /TP
	# ==========================================
	if msg.to_lower() == "/tp" or msg.to_lower() == "/spawn":
		var net_pos = Vector3.ZERO
		if get_parent() and "global_position" in get_parent(): net_pos = get_parent().global_position
		
		var current_dim_x = snapped(global_position.x - net_pos.x, 5000.0)
		var dest = Vector3(net_pos.x + current_dim_x, net_pos.y + 150.0, net_pos.z)
		if current_dim_x == 0.0: dest.y = net_pos.y + 10.0 # Standard City map spawn
		
		# Auto-Load the floor below you just in case
		var map_loader = active_scene.get_node_or_null("MapLoader")
		if map_loader and map_loader.has_method("load_client_map"):
			var map_path = ""
			if current_dim_x == 10000.0: map_path = "res://sand_village.tscn"
			elif current_dim_x == 15000.0: map_path = "res://shukakuhab.tscn"
			elif current_dim_x == 20000.0: map_path = "res://matatabihab.tscn"
			elif current_dim_x == 25000.0: map_path = "res://isobuhab.tscn"
			elif current_dim_x == 30000.0: map_path = "res://songokuhab.tscn"
			elif current_dim_x == 35000.0: map_path = "res://kokuohab.tscn"
			elif current_dim_x == 40000.0: map_path = "res://saikenhab.tscn"
			elif current_dim_x == 45000.0: map_path = "res://chomeihab.tscn"
			elif current_dim_x == 50000.0: map_path = "res://gyukihab.tscn"
			elif current_dim_x == 55000.0: map_path = "res://kuramahab.tscn"
			elif current_dim_x == 60000.0: map_path = "res://altarmap.tscn"
			
			if map_path != "":
				var map_pos = Vector3(dest.x, net_pos.y, dest.z)
				map_loader.load_client_map(map_path, map_pos)
			
		if is_riding and is_instance_valid(my_beast): my_beast.global_position = dest
		else: global_position = dest
		velocity = Vector3.ZERO
		if net_node: net_node.rpc_id(multiplayer.get_unique_id(), "rpc_receive_message", "SYSTEM", "Teleported to local dimension spawn.")
		return
		
	if msg.to_lower() == "/travel" or msg.to_lower() == "/map":
		show_travel_menu()
		return
		
	if msg.to_lower() == "/autobattle":
		if is_admin: _toggle_autobattle()
		return
		
	if is_admin:
		if msg.to_lower() == "/players":
			var peers = multiplayer.get_peers()
			if net_node: net_node.rpc_id(multiplayer.get_unique_id(), "rpc_receive_message", "SERVER INFO", "Connected Players: " + str(peers.size()))
			return
		elif msg.to_lower().begins_with("/announce "):
			var announcement = msg.substr(10).strip_edges()
			if net_node: net_node.rpc("rpc_receive_message", "SERVER", "« " + announcement + " »")
			return
		elif msg.to_lower() == "/quit_server":
			rpc_id(1, "rpc_shutdown_server") 
			return
			
		if msg.to_lower().begins_with("ciel") or msg.to_lower().begins_with("sage"):
			if not is_instance_valid(abilities):
				if net_node: net_node.rpc_id(multiplayer.get_unique_id(), "rpc_receive_message", "SYSTEM ERROR", "Cannot find 'AbilitiesManager' node!")
				return
	
	var handled_by_ciel = false
	if is_instance_valid(abilities) and is_admin: handled_by_ciel = abilities.parse_chat(msg)
	
	if not handled_by_ciel and net_node: 
		net_node.rpc("rpc_receive_message", GlobalData.username, msg)

func _force_model_to_layer_two(node: Node):
	if node is VisualInstance3D:
		node.set_layer_mask_value(1, false)
		node.set_layer_mask_value(2, true)
	for child in node.get_children(): _force_model_to_layer_two(child)

func _ask_for_name():
	var auth = get_multiplayer_authority()
	if auth in multiplayer.get_peers() or auth == 1:
		rpc_id(auth, "rpc_request_username", multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func rpc_set_username(new_name: String):
	if name_tag: name_tag.text = new_name

@rpc("any_peer", "call_remote", "reliable")
func rpc_request_username(requester_id: int):
	if is_multiplayer_authority():
		var my_name = GlobalData.username
		if my_name == "": my_name = "Citizen " + str(multiplayer.get_unique_id()).left(4)
		rpc_id(requester_id, "rpc_set_username", my_name)

@rpc("any_peer", "call_local")
func rpc_trigger_ragdoll(launch_force: Vector3):
	is_ragdolling = true
	ragdoll_velocity = launch_force
	if is_instance_valid(player_model):
		var tumble_tween = create_tween().set_loops(10)
		tumble_tween.tween_property(player_model, "rotation_degrees:x", 360.0, 0.5).as_relative()
		tumble_tween.parallel().tween_property(player_model, "rotation_degrees:z", 360.0, 0.7).as_relative()

func _physics_process(delta):
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED: return
	if not is_multiplayer_authority(): return
	if not is_inside_tree() or is_dead: return 
	
	if is_instance_valid(minimap_cam):
		minimap_cam.global_position = Vector3(global_position.x, 200.0, global_position.z)
		minimap_cam.global_rotation_degrees = Vector3(-90, 0, 0)
	if is_instance_valid(minimap_pointer) and is_instance_valid(cam):
		minimap_pointer.global_rotation = Vector3(deg_to_rad(-90), cam.global_rotation.y, 0)
	
	if evil_points > 0 and not is_dead:
		wanted_cooldown -= delta
		if wanted_cooldown <= 0:
			evil_points -= delta * 0.33 
			if evil_points < 0: evil_points = 0.0
			_update_wanted_ui()

	if is_on_fire:
		fire_timer -= delta
		fire_tick += delta
		if fire_tick >= 0.5: 
			fire_tick = 0.0
			take_damage(10.0)
		if fire_timer <= 0:
			is_on_fire = false
			if is_instance_valid(fire_visual): fire_visual.queue_free()
	
	if is_awakened:
		awaken_timer -= delta
		if awaken_timer <= 0: _end_awakening()
	
	if wanted_level > 0:
		police_spawn_timer -= delta
		if police_spawn_timer <= 0:
			police_spawn_timer = max(10.0 - (wanted_level * 1.5), 2.0) 
			rpc("rpc_spawn_police")

	var out_of_bounds = false
	if global_position.y < -15.0 and global_position.y > -1250.0: out_of_bounds = true
	elif abs(global_position.x) > 2000.0 or abs(global_position.z) > 2000.0: out_of_bounds = true
		
	var true_dragon_active = is_instance_valid(abilities) and abilities.is_true_dragon
	if (out_of_bounds or in_water_zone) and not is_flying and not is_dead and not true_dragon_active:
		is_drowning = true
		if out_of_bounds and not is_instance_valid(procedural_water): _spawn_procedural_water()
		velocity.y -= gravity * delta * 0.2 
		velocity.y = clamp(velocity.y, -3.0, 5.0) 
		velocity.x = move_toward(velocity.x, 0, delta * 15.0)
		velocity.z = move_toward(velocity.z, 0, delta * 15.0)
		drown_tick += delta
		if drown_tick >= 1.0:
			take_damage(25.0)
			drown_tick = 0.0
	else:
		is_drowning = false
		drown_tick = 0.0
		if is_instance_valid(procedural_water): procedural_water.queue_free()

	if is_riding and is_instance_valid(my_beast):
		var turn_input = Input.get_axis("ui_left", "ui_right") 
		var forward_input = Input.get_axis("ui_down", "ui_up") 
		var anim_beast = my_beast.get_node_or_null("AnimationPlayer")
		if anim_beast and not anim_beast.is_playing():
			for a in anim_beast.get_animation_list():
				if a != "RESET":
					var current_anim = anim_beast.get_animation(a)
					current_anim.loop_mode = Animation.LOOP_PINGPONG 
					anim_beast.play(a)
					break
		if turn_input != 0: my_beast.rotate_y(turn_input * -2.5 * delta)
		if forward_input != 0:
			var forward_dir = -my_beast.global_transform.basis.z.normalized()
			my_beast.global_position -= forward_dir * forward_input * (SPEED * 3.0) * delta
		var head = my_beast.find_child("HeadMarker", true, false)
		if head:
			global_position = head.global_position
			global_rotation = my_beast.global_rotation
			global_rotation.y += PI 
			if cam: cam.rotation = Vector3.ZERO
		return 

	if is_dashing:
		dash_timer -= delta
		velocity.x = dash_dir.x * (SPEED * 6.0)
		velocity.z = dash_dir.z * (SPEED * 6.0)
		velocity.y = 0
		if dash_timer <= 0: is_dashing = false
		move_and_slide()
		return

	if is_instance_valid(abilities) and (abilities.is_great_sage or abilities.is_ciel_unleashed):
		move_and_slide()
		return

	if not is_on_floor() and not is_flying and not is_drowning and not is_ragdolling and not true_dragon_active:
		velocity.y -= gravity * delta
		if velocity.y < -50.0: velocity.y = -50.0 
		last_y_velocity = velocity.y 
	elif is_on_floor() and not is_ragdolling:
		if not is_flying and not true_dragon_active and last_y_velocity < -25.0: 
			take_damage(abs(last_y_velocity) * 2.5)
			if is_dead: return
		last_y_velocity = 0.0 

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_drowning and not is_ragdolling:
		velocity.y = JUMP_VELOCITY

	if is_ragdolling:
		ragdoll_velocity.y -= gravity * delta
		if is_on_wall() or is_on_floor():
			ragdoll_velocity = ragdoll_velocity.bounce(get_wall_normal() if is_on_wall() else get_floor_normal()) * 0.5
			take_damage(10.0) 
			if cam and is_multiplayer_authority():
				var shake = create_tween()
				shake.tween_property(cam, "v_offset", 0.5, 0.05)
				shake.tween_property(cam, "v_offset", -0.5, 0.05)
				shake.tween_property(cam, "v_offset", 0.0, 0.05)
		velocity = ragdoll_velocity
		if is_on_floor() and ragdoll_velocity.length() < 3.0:
			is_ragdolling = false
			velocity = Vector3.ZERO
			if is_instance_valid(player_model): player_model.rotation_degrees = Vector3.ZERO
		move_and_slide()
		return 

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cam_basis = Basis()
	if cam: cam_basis = cam.global_transform.basis
	
	var current_speed = SPEED
	if is_instance_valid(abilities):
		if abilities.is_true_dragon: current_speed = SPEED * 4.0
		elif abilities.is_chakra_mode: current_speed = SPEED * 2.5
	
	if is_flying or true_dragon_active:
		var flight_dir = (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y).normalized()
		velocity = flight_dir * (current_speed * 3.0) 
	else:
		var direction = (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y)
		direction.y = 0 
		if is_instance_valid(player_model) and is_instance_valid(cam):
			var target_angle = cam.global_rotation.y
			if model_faces_backwards: target_angle += PI 
			player_model.global_rotation.y = lerp_angle(player_model.global_rotation.y, target_angle, 25.0 * delta)
		if direction.length() > 0.01:
			direction = direction.normalized()
			if is_drowning: current_speed = SPEED * 0.3
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
			if is_instance_valid(anim) and is_on_floor() and anim.current_animation != "playerwalk": anim.play("playerwalk", 0.2)
		else:
			var friction = SPEED * 2.0 if is_drowning else SPEED
			velocity.x = move_toward(velocity.x, 0, friction)
			velocity.z = move_toward(velocity.z, 0, friction)
			if is_instance_valid(anim) and is_on_floor() and anim.current_animation != "Animation": anim.play("Animation", 0.2)
	move_and_slide()

func _spawn_procedural_water():
	procedural_water = CSGBox3D.new()
	procedural_water.size = Vector3(4000.0, 50.0, 4000.0) 
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.0, 0.2, 0.6, 0.8) 
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED 
	water_mat.roughness = 0.1
	water_mat.metallic = 0.3
	procedural_water.material = water_mat
	get_tree().current_scene.add_child(procedural_water)
	procedural_water.global_position = Vector3(global_position.x, -15.0, global_position.z)

func _update_wanted_ui():
	var new_wanted = int(evil_points / 3.0) 
	if new_wanted != wanted_level:
		wanted_level = new_wanted
		if wanted_level > 0:
			var stars = ""
			for i in range(wanted_level): stars += "★"
			if stars_label:
				stars_label.text = stars
				stars_label.visible = true
		else: rpc_clear_stars() 

@rpc("any_peer", "call_local")
func rpc_add_star():
	if is_dead: return
	evil_points += 1.0 
	if evil_points > 15.0: evil_points = 15.0 
	wanted_cooldown = 15.0 
	_update_wanted_ui()

@rpc("any_peer", "call_local")
func rpc_clear_stars():
	evil_points = 0.0
	wanted_level = 0
	if stars_label: stars_label.visible = false
	if multiplayer.is_server():
		var any_wanted = false
		for p in get_parent().get_children():
			if p is CharacterBody3D and p.name.is_valid_int() and "wanted_level" in p and p.wanted_level > 0: any_wanted = true
		if not any_wanted:
			for node in get_parent().get_children():
				if "attack_timer" in node and node.has_method("_shoot_at"): node.queue_free() 

@rpc("any_peer", "call_local")
func rpc_spawn_police():
	if not multiplayer.is_server(): return 
	if global_position.y < -15 or global_position.y > 500: return
	var spawn_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var drop_pos = global_position + (spawn_dir * randf_range(25.0, 45.0)) + Vector3(0, 5, 0)
	if wanted_level >= 3 and police_car_scene:
		var cop_car = police_car_scene.instantiate()
		cop_car.name = "PoliceCar_" + str(randi() % 10000) + "_" + str(Time.get_ticks_msec())
		get_parent().add_child(cop_car, true)
		cop_car.global_position = drop_pos
	elif police_npc_scene:
		var cop = police_npc_scene.instantiate()
		cop.name = "PoliceNPC_" + str(randi() % 10000) + "_" + str(Time.get_ticks_msec())
		get_parent().add_child(cop, true)
		cop.global_position = drop_pos

func _spawn_no_effect_text(custom_text: String = "NO EFFECT", text_color: Color = Color.WHITE):
	var label = Label3D.new()
	label.text = custom_text
	var font = load("res://Noeffect.ttf")
	if font: label.font = font
	label.font_size = 120
	label.modulate = text_color
	label.outline_render_priority = 0
	label.outline_modulate = Color(0.0, 0.0, 0.0) if custom_text != "NO EFFECT" else Color(0.8, 0.0, 0.0)
	label.outline_size = 15
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true 
	get_parent().add_child(label)
	var random_offset = Vector3(randf_range(-0.8, 0.8), randf_range(2.0, 3.0), randf_range(-0.8, 0.8))
	label.global_position = global_position + random_offset
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.5, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func take_damage(amount):
	if is_dashing: return 
	rpc("rpc_take_damage", amount)

@rpc("any_peer", "call_local")
func rpc_take_damage(amount):
	if is_admin: 
		if is_instance_valid(abilities) and abilities.is_great_sage:
			_spawn_no_effect_text("« ABSOLUTE DEFENSE »", Color(0.0, 0.8, 1.0))
			if not abilities.ciel_aggro:
				abilities.trigger_counter()
				if is_multiplayer_authority():
					get_tree().current_scene.rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Hostile action intercepted. Commencing total annihilation. »")
		else: _spawn_no_effect_text()
		return 
	if is_dead: return 
	current_health -= amount
	if health_bar: health_bar.value = current_health
	if cam and is_multiplayer_authority():
		var shake = create_tween()
		shake.tween_property(cam, "v_offset", 0.3, 0.05)
		shake.tween_property(cam, "v_offset", -0.3, 0.05)
		shake.tween_property(cam, "v_offset", 0.0, 0.05)
	if current_health <= 0:
		is_dead = true
		is_on_fire = false 
		if is_instance_valid(fire_visual): fire_visual.queue_free()
		is_drowning = false
		if is_instance_valid(procedural_water): procedural_water.queue_free()
		if is_instance_valid(abilities):
			abilities.is_chakra_mode = false
			if is_instance_valid(abilities.chakra_aura): abilities.chakra_aura.queue_free()
		if is_multiplayer_authority():
			if death_screen: death_screen.visible = true
			set_combat_ui_visible(false)
			if is_instance_valid(walk_joystick): walk_joystick.visible = false

func _btn_respawn(): if is_dead: rpc("rpc_respawn")

@rpc("any_peer", "call_local")
func rpc_respawn():
	is_dead = false
	current_health = max_health
	if health_bar: health_bar.value = max_health
	is_on_fire = false
	if is_instance_valid(fire_visual): fire_visual.queue_free()
	is_drowning = false
	drown_tick = 0.0
	if is_instance_valid(procedural_water): procedural_water.queue_free()
	if is_instance_valid(player_model): player_model.rotation_degrees.x = 0.0
	rpc_equip_weapon("Fists")
	if is_multiplayer_authority():
		var net_pos = Vector3.ZERO
		if get_parent() and "global_position" in get_parent(): net_pos = get_parent().global_position
		
		var current_dim_x = snapped(global_position.x - net_pos.x, 5000.0)
		var dest = Vector3(net_pos.x + current_dim_x, net_pos.y + 150.0, net_pos.z)
		if current_dim_x == 0.0: dest.y = net_pos.y + 10.0 
		
		global_position = dest
		velocity = Vector3.ZERO
		
		if death_screen: death_screen.visible = false
		set_combat_ui_visible(true)
		if is_instance_valid(walk_joystick): walk_joystick.visible = true
		if not is_admin and GlobalData.has_beast:
			if awaken_btn: awaken_btn.text = "Chakra Mode"
			if bomb_btn: bomb_btn.visible = false
			if push_btn: push_btn.visible = false
	rpc("rpc_clear_stars")

@rpc("any_peer", "call_local")
func rpc_catch_fire():
	if is_dead or is_drowning: return 
	if is_on_fire:
		fire_timer = 5.0 
		return
	is_on_fire = true
	fire_timer = 5.0
	if not is_instance_valid(fire_visual):
		fire_visual = CSGCylinder3D.new()
		fire_visual.radius = 0.6
		fire_visual.height = 2.0
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.4, 0.0, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.2, 0.0)
		mat.emission_energy_multiplier = 4.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fire_visual.material = mat
		add_child(fire_visual)
		fire_visual.position = Vector3(0, 1.0, 0)

func toggle_weapon_wheel():
	if not weapon_wheel: return
	if weapon_wheel.visible:
		weapon_wheel.visible = false
		if current_weapon in ["Pistol", "Shotgun", "Rifle"] and crosshair: crosshair.visible = true
	else:
		weapon_wheel.visible = true
		if crosshair: crosshair.visible = false

func _equip_and_close(w_name: String):
	rpc("rpc_equip_weapon", w_name)
	if weapon_wheel and weapon_wheel.visible: toggle_weapon_wheel()

@rpc("any_peer", "call_local")
func rpc_equip_weapon(weapon_name: String):
	current_weapon = weapon_name
	if attack_btn and is_multiplayer_authority(): attack_btn.text = "Attack: " + weapon_name
	if is_instance_valid(pistol_model): pistol_model.visible = (weapon_name == "Pistol")
	if is_instance_valid(shotgun_model): shotgun_model.visible = (weapon_name == "Shotgun")
	if is_instance_valid(rifle_model): rifle_model.visible = (weapon_name == "Rifle")

func _btn_attack():
	if not can_attack or is_drowning: return 
	can_attack = false
	var origin = global_position + Vector3(0, 1.2, 0)
	var dir = -cam.global_transform.basis.z.normalized() if cam else -global_transform.basis.z.normalized()
	if cam:
		var vp_center = get_viewport().get_visible_rect().size / 2.0
		origin = cam.project_ray_origin(vp_center)
		dir = cam.project_ray_normal(vp_center)
	rpc("rpc_perform_attack", current_weapon, origin, dir)
	if current_weapon == "Fists": await get_tree().create_timer(0.3).timeout
	elif current_weapon == "Pistol": await get_tree().create_timer(0.4).timeout
	elif current_weapon == "Shotgun": await get_tree().create_timer(1.0).timeout
	elif current_weapon == "Rifle": await get_tree().create_timer(0.4).timeout
	elif current_weapon == "C4": await get_tree().create_timer(0.5).timeout
	can_attack = true

@rpc("any_peer", "call_local")
func rpc_perform_attack(w_name: String, origin: Vector3, dir: Vector3):
	if w_name == "Fists":
		var space_state = get_world_3d().direct_space_state
		var punch_start = global_position + Vector3(0, 1.0, 0)
		var query = PhysicsRayQueryParameters3D.create(punch_start, punch_start + (dir * 2.0))
		query.exclude = [self.get_rid()] 
		query.collide_with_areas = true 
		var result = space_state.intersect_ray(query)
		if result:
			var melee_dmg = 15.0
			if is_instance_valid(abilities) and abilities.is_chakra_mode: melee_dmg = 60.0
			if result.collider.has_method("take_damage"): result.collider.take_damage(melee_dmg)
			elif result.collider.has_method("TakeDamage"): result.collider.TakeDamage(melee_dmg)
			
	elif w_name == "Pistol":
		if gun_sound: gun_sound.play()
		if is_instance_valid(pistol_model):
			var orig_rot = pistol_model.rotation_degrees
			var recoil = create_tween()
			recoil.tween_property(pistol_model, "rotation_degrees:x", orig_rot.x + 15.0, 0.05)
			recoil.tween_property(pistol_model, "rotation_degrees:x", orig_rot.x, 0.15)
		_rpc_hitscan(origin, dir, 100.0, 25.0, 0.0) 
		
	elif w_name == "Shotgun":
		if gun_sound: gun_sound.play()
		if is_instance_valid(shotgun_anim):
			shotgun_anim.stop() 
			shotgun_anim.play("ShotgunAction") 
		for i in range(6): _rpc_hitscan(origin, dir, 30.0, 15.0, 0.05)
		if cam and is_multiplayer_authority():
			var shake = create_tween()
			shake.tween_property(cam, "rotation_degrees:x", cam.rotation_degrees.x + 2.0, 0.05)
			shake.tween_property(cam, "rotation_degrees:x", cam.rotation_degrees.x, 0.1)
		
	elif w_name == "Rifle":
		for i in range(3):
			if gun_sound: gun_sound.play()
			if is_instance_valid(rifle_model):
				var orig_rot = rifle_model.rotation_degrees
				var recoil = create_tween()
				recoil.tween_property(rifle_model, "rotation_degrees:x", orig_rot.x + 5.0, 0.02)
				recoil.tween_property(rifle_model, "rotation_degrees:x", orig_rot.x, 0.05)
			_rpc_hitscan(origin, dir, 150.0, 15.0, 0.01)
			if cam and is_multiplayer_authority():
				var shake = create_tween()
				shake.tween_property(cam, "rotation_degrees:x", cam.rotation_degrees.x + 0.5, 0.02)
				shake.tween_property(cam, "rotation_degrees:x", cam.rotation_degrees.x, 0.05)
			await get_tree().create_timer(0.1).timeout 
			
	elif w_name == "C4":
		if c4_scene:
			var c4 = c4_scene.instantiate()
			get_parent().add_child(c4)
			c4.global_position = origin + (dir * 1.5)
			if c4 is RigidBody3D: c4.linear_velocity = dir * 25.0 + Vector3(0, 5.0, 0) 
			if is_multiplayer_authority():
				active_c4s.append(c4)
				if detonate_btn: detonate_btn.visible = true

func _rpc_hitscan(origin: Vector3, aim_dir: Vector3, max_dist: float, damage: float, spread: float):
	var final_dir = (aim_dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))).normalized()
	var target_point = origin + (final_dir * max_dist)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, target_point)
	query.exclude = [self.get_rid()] 
	query.collide_with_areas = true
	if is_riding and is_instance_valid(my_beast): query.exclude.append(my_beast.get_rid()) 
	var result = space_state.intersect_ray(query)
	var hit_pos = target_point
	if result:
		hit_pos = result.position
		var c = result.collider
		if c.has_method("take_damage"): c.take_damage(damage)
		elif c.has_method("TakeDamage"): c.TakeDamage(damage)
	var chest_pos = global_position + Vector3(0, 1.2, 0)
	if chest_pos.distance_to(hit_pos) < 0.1: return 
	var tracer = CSGCylinder3D.new()
	tracer.radius = 0.02
	tracer.height = chest_pos.distance_to(hit_pos)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.material = mat
	get_parent().add_child(tracer)
	tracer.global_position = chest_pos.lerp(hit_pos, 0.5) 
	tracer.look_at(hit_pos, Vector3.UP)
	tracer.rotate_x(deg_to_rad(90))
	var tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tween.tween_callback(tracer.queue_free)

func _btn_detonate():
	for c4 in active_c4s:
		if is_instance_valid(c4) and c4.has_method("rpc_detonate"): c4.rpc("rpc_detonate")
	active_c4s.clear()
	if detonate_btn: detonate_btn.visible = false

func _btn_car():
	if car_scenes.is_empty(): return
	var forward_dir = -cam.global_transform.basis.z.normalized() if cam else -global_transform.basis.z.normalized()
	forward_dir.y = 0
	var drop_pos = global_position + (forward_dir * car_spawn_distance) + Vector3(0, car_spawn_height, 0)
	var drop_rot = Vector3(0, global_rotation.y, 0)
	rpc("rpc_car_cycle", drop_pos, drop_rot)

@rpc("any_peer", "call_local")
func rpc_car_cycle(drop_pos: Vector3, drop_rot: Vector3):
	if is_instance_valid(active_car_instance): active_car_instance.queue_free()
	current_car_index = (current_car_index + 1) % car_scenes.size()
	var new_car_scene = car_scenes[current_car_index]
	if not new_car_scene: return
	active_car_instance = new_car_scene.instantiate()
	get_parent().add_child(active_car_instance)
	var c_cam = active_car_instance.get_node_or_null("Camera3D")
	var i_cam = active_car_instance.get_node_or_null("InteriorCam")
	if c_cam: c_cam.current = false
	if i_cam: i_cam.current = false
	if cam and is_multiplayer_authority(): cam.make_current()
	active_car_instance.global_position = drop_pos
	active_car_instance.global_rotation = drop_rot
	
	if active_car_instance is VehicleBody3D or active_car_instance is RigidBody3D:
		active_car_instance.sleeping = false
		if active_car_instance is VehicleBody3D: 
			active_car_instance.steering = 0.0
			active_car_instance.engine_force = 0.1 
			
	if "is_active_car" in active_car_instance: active_car_instance.is_active_car = true
	if active_car_instance.get("player") != null or active_car_instance.get("Player") != null:
		active_car_instance.set("player", self)
		active_car_instance.set("Player", self)
	if is_multiplayer_authority() and weapon_wheel and weapon_wheel.visible: toggle_weapon_wheel()

@warning_ignore("shadowed_variable_base_class")
func set_combat_ui_visible(is_visible: bool):
	if is_instance_valid(punch_button): punch_button.visible = is_visible
	if is_instance_valid(weapon_wheel_icon): weapon_wheel_icon.visible = is_visible
	if attack_btn: attack_btn.visible = is_visible
	if wheel_btn: wheel_btn.visible = is_visible
	if not is_visible and weapon_wheel and weapon_wheel.visible:
		weapon_wheel.visible = false
		if crosshair: crosshair.visible = false

func set_driving_ui(is_driving: bool):
	var use_wheel = get_tree().root.get_meta("use_steering_wheel", true)
	if is_instance_valid(walk_joystick):
		if is_driving and use_wheel: 
			walk_joystick.visible = false 
			if walk_joystick.has_method("reset"): walk_joystick.reset()
			elif walk_joystick.has_method("_reset"): walk_joystick._reset()
		elif is_driving and not use_wheel: walk_joystick.visible = true  
		else: walk_joystick.visible = true  
	if is_instance_valid(virtual_steering):
		virtual_steering.visible = (is_driving and use_wheel)
		virtual_steering.process_mode = Node.PROCESS_MODE_ALWAYS 
	if is_instance_valid(gas_pedal): gas_pedal.visible = (is_driving and use_wheel)
	if is_instance_valid(brake_pedal): brake_pedal.visible = (is_driving and use_wheel)
	set_combat_ui_visible(!is_driving)

# ==========================================
# UI SCROLL FIX
# ==========================================
func _get_travel_container() -> Node:
	if not travel_menu: return null
	
	var scroll = travel_menu.find_child("ScrollContainer", true, false)
	if scroll:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		
		var hbox = scroll.find_child("HBoxContainer", true, false)
		if hbox and hbox.name == "HBoxContainer":
			hbox.name = "DEAD_HBOX" 
			hbox.hide()
			hbox.queue_free()
			
		var vbox = scroll.find_child("VBoxContainer", true, false)
		if not vbox:
			vbox = VBoxContainer.new()
			vbox.name = "VBoxContainer"
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.add_theme_constant_override("separation", 15) 
			scroll.add_child(vbox)
		return vbox
		
	var fallback_vbox = travel_menu.find_child("VBoxContainer", true, false)
	if fallback_vbox: return fallback_vbox
	return travel_menu

func clear_menu_buttons():
	var container = _get_travel_container()
	if container:
		for child in container.get_children():
			child.queue_free()

func add_menu_button(btn_text: String, action: Callable):
	var container = _get_travel_container()
	if not container: return
	var btn = Button.new()
	btn.text = btn_text
	btn.focus_mode = Control.FOCUS_NONE
	var custom_font = load("res://Undertale.ttf")
	if custom_font: btn.add_theme_font_override("font", custom_font)
	btn.add_theme_font_size_override("font_size", 42)
	btn.custom_minimum_size = Vector2(0, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(action)
	container.add_child(btn)

# ==========================================
# NETWORK MANAGER DIMENSIONAL ANCHOR
# ==========================================
func _get_dim_spawn(dim_x: float, height_offset: float) -> Vector3:
	var net_pos = Vector3.ZERO
	if get_parent() and "global_position" in get_parent():
		net_pos = get_parent().global_position
	return Vector3(net_pos.x + dim_x, net_pos.y + height_offset, net_pos.z)

func show_travel_menu():
	if not travel_menu: return
	if weapon_wheel and weapon_wheel.visible: toggle_weapon_wheel() 
	var label = travel_menu.find_child("Label", true, false)
	if label:
		label.text = "* Where would you like to travel to?"
		label.remove_theme_color_override("font_color")
	clear_menu_buttons()
	
	add_menu_button("City", func(): _teleport_travel(_get_dim_spawn(0.0, 10.0), ""))
	add_menu_button("Sand Village (Shukaku)", func(): _teleport_travel(_get_dim_spawn(10000.0, 150.0), "res://sand_village.tscn"))
	add_menu_button("Scorched Caverns", func(): _teleport_travel(_get_dim_spawn(20000.0, 50.0), "res://matatabihab.tscn"))
	add_menu_button("Misty Reef", func(): _teleport_travel(_get_dim_spawn(25000.0, 50.0), "res://isobuhab.tscn"))
	add_menu_button("Volcanic Crater", func(): _teleport_travel(_get_dim_spawn(30000.0, 50.0), "res://songokuhab.tscn"))
	add_menu_button("Boiling Forest", func(): _teleport_travel(_get_dim_spawn(35000.0, 50.0), "res://kokuohab.tscn"))
	add_menu_button("Acid Swamp", func(): _teleport_travel(_get_dim_spawn(40000.0, 50.0), "res://saikenhab.tscn"))
	add_menu_button("Deep Canyon", func(): _teleport_travel(_get_dim_spawn(45000.0, 50.0), "res://chomeihab.tscn"))
	add_menu_button("Valley of Clouds", func(): _teleport_travel(_get_dim_spawn(50000.0, 50.0), "res://gyukihab.tscn"))
	add_menu_button("Ancient Ruins", func(): _teleport_travel(_get_dim_spawn(55000.0, 50.0), "res://kuramahab.tscn"))
	if GlobalData.has_fragment and not GlobalData.has_beast:
		add_menu_button("???", func(): _teleport_travel(_get_dim_spawn(60000.0, 50.0), "res://altarmap.tscn"))
	add_menu_button("Nevermind", hide_travel_menu)
	_play_menu_animation()

func _teleport_travel(dest: Vector3, map_path: String):
	hide_travel_menu()
	var map_loader = get_tree().current_scene.get_node_or_null("MapLoader")
	if map_loader and map_loader.has_method("load_client_map"):
		var net_y = get_parent().global_position.y if get_parent() and "global_position" in get_parent() else 0.0
		var map_pos = Vector3(dest.x, net_y, dest.z)
		map_loader.load_client_map(map_path, map_pos)
		
	if is_riding and is_instance_valid(my_beast): my_beast.global_position = dest
	else: global_position = dest
	velocity = Vector3.ZERO
	if push_sound: push_sound.play()

func show_artifact_menu(artifact_text: String, artifact_color: Color):
	if not travel_menu: return
	if weapon_wheel and weapon_wheel.visible: toggle_weapon_wheel()
	var label = travel_menu.find_child("Label", true, false)
	if label:
		label.text = artifact_text
		label.add_theme_color_override("font_color", artifact_color)
	clear_menu_buttons()
	add_menu_button("...", hide_travel_menu)
	_play_menu_animation()

func show_altar_menu(item_name: String, item_color: Color, altar_node: Node3D):
	if not travel_menu: return
	if weapon_wheel and weapon_wheel.visible: toggle_weapon_wheel()
	var label = travel_menu.find_child("Label", true, false)
	if label:
		label.text = "* Your " + item_name + " seems to fit."
		label.add_theme_color_override("font_color", item_color)
	clear_menu_buttons()
	add_menu_button("Insert Fragment", func(): 
		hide_travel_menu()
		if altar_node and altar_node.has_method("start_ritual"): altar_node.start_ritual(self)
	)
	add_menu_button("Nevermind", hide_travel_menu)
	_play_menu_animation()

func hide_travel_menu():
	if not travel_menu or not travel_menu.visible: return
	if travel_menu_tween and travel_menu_tween.is_running(): travel_menu_tween.kill()
	travel_menu_tween = create_tween().set_parallel(true)
	travel_menu_tween.tween_property(travel_menu, "modulate:a", 0.0, 0.2)
	travel_menu_tween.tween_property(travel_menu, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_SINE)
	travel_menu_tween.chain().tween_callback(travel_menu.hide)

func _play_menu_animation():
	travel_menu.show()
	if travel_menu_tween and travel_menu_tween.is_running(): travel_menu_tween.kill()
	travel_menu.scale = Vector2(0.8, 0.8)
	travel_menu_tween = create_tween().set_parallel(true)
	travel_menu_tween.tween_property(travel_menu, "modulate:a", 1.0, 0.2)
	travel_menu_tween.tween_property(travel_menu, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _btn_beelzebuth(): 
	if is_instance_valid(abilities): abilities.rpc("rpc_beelzebuth")

func _toggle_autobattle():
	if not is_instance_valid(abilities): return
	abilities.is_great_sage = !abilities.is_great_sage
	if sage_btn: sage_btn.text = "Manas: Ciel [ON]" if abilities.is_great_sage else "Manas: Ciel [OFF]"
	var minimap_parent = minimap_viewport.get_parent() if minimap_viewport else null
	if abilities.is_great_sage:
		if push_sound: push_sound.play()
		if minimap_parent and minimap_parent is Control:
			minimap_parent.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			minimap_parent.position = Vector2(get_viewport().get_visible_rect().size.x - minimap_parent.size.x - 20, 20)
		if not is_instance_valid(sage_ui_rect):
			sage_ui_rect = TextureRect.new()
			sage_ui_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sage_ui_rect.custom_minimum_size = Vector2(150, 150)
			sage_ui_rect.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			sage_ui_rect.position = Vector2(get_viewport().get_visible_rect().size.x - 170, 20)
			var sage_tex = load("res://tenor_gif2955386777244579388.gif") 
			if sage_tex: sage_ui_rect.texture = sage_tex
			if has_node("CanvasLayer"): $CanvasLayer.add_child(sage_ui_rect)
		if is_multiplayer_authority():
			var label = Label3D.new()
			label.text = "« AUTO-BATTLE ENGAGED »"
			var font = load("res://Undertale.ttf")
			if font: label.font = font
			label.font_size = 80
			label.modulate = Color(0.0, 0.8, 1.0)
			label.outline_render_priority = 0
			label.outline_modulate = Color(0.0, 0.2, 0.5)
			label.outline_size = 15
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true 
			get_parent().add_child(label)
			label.global_position = global_position + Vector3(0, 2.5, 0)
			var tween = create_tween().set_parallel(true)
			tween.tween_property(label, "global_position:y", label.global_position.y + 1.0, 1.5)
			tween.tween_property(label, "modulate:a", 0.0, 1.5)
			tween.chain().tween_callback(label.queue_free)
	else:
		if is_instance_valid(sage_ui_rect): sage_ui_rect.queue_free()
		if minimap_parent and minimap_parent is Control:
			minimap_parent.set_anchors_preset(Control.PRESET_TOP_LEFT)
			minimap_parent.position = Vector2(20, 20)

func _btn_chakra_mode():
	if is_instance_valid(abilities):
		abilities.is_chakra_mode = !abilities.is_chakra_mode
		if abilities.is_chakra_mode:
			if push_sound: push_sound.play()
			if awaken_btn and is_multiplayer_authority(): awaken_btn.text = "Revert Mode"
			if bomb_btn and is_multiplayer_authority(): bomb_btn.visible = true
			if push_btn and is_multiplayer_authority(): push_btn.visible = true
			max_health = 500.0
			current_health = 500.0
			if health_bar: 
				health_bar.max_value = max_health
				health_bar.value = current_health
			if is_instance_valid(abilities.chakra_aura): abilities.chakra_aura.queue_free()
			abilities.chakra_aura = CSGCombiner3D.new()
			var b_color = abilities._get_beast_color(GlobalData.current_beast_id)
			var flame = CSGSphere3D.new()
			flame.radius = 1.2
			var mat = StandardMaterial3D.new()
			mat.albedo_color = b_color
			mat.emission_enabled = true
			mat.emission = b_color
			mat.emission_energy_multiplier = 3.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.4
			flame.material = mat
			abilities.chakra_aura.add_child(flame)
			add_child(abilities.chakra_aura)
			abilities.chakra_aura.position = Vector3(0, 1.0, 0)
		else:
			if awaken_btn and is_multiplayer_authority(): awaken_btn.text = "Chakra Mode"
			if bomb_btn and is_multiplayer_authority(): bomb_btn.visible = false
			if push_btn and is_multiplayer_authority(): push_btn.visible = false
			max_health = 100.0
			current_health = min(current_health, 100.0)
			if health_bar: 
				health_bar.max_value = max_health
				health_bar.value = current_health
			if is_instance_valid(abilities.chakra_aura): abilities.chakra_aura.queue_free()

func _btn_awaken(): 
	if is_admin: rpc("rpc_trigger_awakening")

@rpc("any_peer", "call_local")
func rpc_trigger_awakening():
	if push_sound: push_sound.play()
	if cam and is_multiplayer_authority():
		var shake = create_tween()
		shake.tween_property(cam, "v_offset", 1.0, 0.05)
		shake.tween_property(cam, "v_offset", -1.0, 0.05)
		shake.tween_property(cam, "v_offset", 0.0, 0.05)
	if push_zone:
		for victim in push_zone.get_overlapping_bodies():
			if victim != self and (victim is RigidBody3D or victim is VehicleBody3D or victim is CharacterBody3D):
				var flat_direction = (victim.global_position - global_position).normalized()
				flat_direction.y += 0.2
				if victim is CharacterBody3D: victim.global_position += (flat_direction * 60.0 * 0.016)
				elif victim is RigidBody3D or victim is VehicleBody3D: victim.apply_central_impulse(flat_direction * 40.0 * victim.mass)
	if is_instance_valid(awakened_aura): awakened_aura.queue_free()
	awakened_aura = CSGCylinder3D.new()
	awakened_aura.radius = 1.5
	awakened_aura.height = 3.5
	var aura_mat = StandardMaterial3D.new()
	aura_mat.albedo_color = Color(0, 0.4, 1.0, 0.3)
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(0, 0.6, 1.0)
	aura_mat.emission_energy_multiplier = 4.0
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	awakened_aura.material = aura_mat
	add_child(awakened_aura)
	awakened_aura.position = Vector3(0, 1.0, 0)
	if not is_multiplayer_authority(): return
	is_awakened = true
	if is_instance_valid(abilities): abilities.is_awakened = true
	awaken_timer = 30.0
	is_flying = true 
	if awaken_btn: awaken_btn.visible = false
	if flight_btn: flight_btn.visible = false
	if kamui_btn: kamui_btn.visible = false
	if push_btn: push_btn.visible = false
	if chibaku_btn: chibaku_btn.visible = false
	if summon_btn: summon_btn.visible = false
	if bomb_btn: bomb_btn.visible = false
	if genjutsu_btn: genjutsu_btn.visible = false
	if domain_btn: domain_btn.visible = true
	if blades_btn: blades_btn.visible = true
	if susanoo_btn: susanoo_btn.visible = true
	if amaterasu_btn: amaterasu_btn.visible = true
	if meteor_btn: meteor_btn.visible = true
	if beelzebuth_btn: beelzebuth_btn.visible = true
	if sage_btn: sage_btn.visible = true
	if dragon_btn: dragon_btn.visible = true

func _end_awakening():
	is_awakened = false
	if is_instance_valid(abilities): abilities.is_awakened = false
	is_flying = false
	if is_instance_valid(awakened_aura): awakened_aura.queue_free()
	if awaken_btn: awaken_btn.visible = true
	if flight_btn: flight_btn.visible = true
	if kamui_btn: kamui_btn.visible = true
	if push_btn: push_btn.visible = true
	if chibaku_btn: chibaku_btn.visible = true
	if summon_btn: summon_btn.visible = true
	if bomb_btn: bomb_btn.visible = true
	if genjutsu_btn: genjutsu_btn.visible = true
	if domain_btn: domain_btn.visible = false
	if blades_btn: blades_btn.visible = false
	if susanoo_btn: susanoo_btn.visible = false
	if amaterasu_btn: amaterasu_btn.visible = false
	if meteor_btn: meteor_btn.visible = false
	if beelzebuth_btn: beelzebuth_btn.visible = false
	if sage_btn: sage_btn.visible = false
	if dragon_btn: dragon_btn.visible = false
	if is_instance_valid(abilities):
		abilities.is_great_sage = false
		abilities.is_true_dragon = false
		if is_instance_valid(abilities.dragon_aura): abilities.dragon_aura.queue_free()
	if sage_btn: sage_btn.text = "Manas: Ciel"

func _btn_genjutsu():
	if push_zone:
		for victim in push_zone.get_overlapping_bodies():
			if victim != self and victim is CharacterBody3D and victim.has_method("rpc_receive_genjutsu"): victim.rpc("rpc_receive_genjutsu")

@rpc("any_peer", "call_local")
func rpc_receive_genjutsu():
	if not is_multiplayer_authority(): return
	if genjutsu_ui:
		genjutsu_ui.visible = true
		await get_tree().create_timer(3.0).timeout
		if genjutsu_ui: genjutsu_ui.visible = false

func toggle_flight():
	is_flying = !is_flying
	if flight_btn:
		if is_flying: flight_btn.text = "[3] Flight: ON"
		else: flight_btn.text = "[3] Kamui Flight"

func _btn_kamui(): rpc("rpc_kamui")

@rpc("any_peer", "call_local")
func rpc_kamui():
	if kamui_sound: kamui_sound.play()
	if not is_multiplayer_authority(): return 
	var victims_to_pull = []
	if kamui_zone:
		for v in kamui_zone.get_overlapping_bodies():
			if v != self and not v is StaticBody3D: victims_to_pull.append(v)
	if cam:
		var swirl = create_tween().set_parallel(true)
		swirl.tween_property(cam, "fov", 20.0, 0.4).set_trans(Tween.TRANS_EXPO)
		swirl.tween_property(cam, "rotation_degrees:z", 180.0, 0.4)
		await get_tree().create_timer(0.4).timeout
	var target_dest = Vector3.ZERO
	if not in_kamui:
		real_world_pos = global_position 
		target_dest = kamui_location
		if is_riding and is_instance_valid(my_beast): my_beast.global_position = target_dest
		else: global_position = target_dest
		in_kamui = true
	else:
		target_dest = real_world_pos
		if is_riding and is_instance_valid(my_beast): my_beast.global_position = target_dest
		else: global_position = target_dest
		in_kamui = false
	for v in victims_to_pull:
		if v.has_method("rpc_receive_genjutsu"): v.rpc("rpc_receive_genjutsu")
		var rand_offset = Vector3(randf_range(-3,3), 0, randf_range(-3,3))
		if v.has_method("rpc_force_teleport"): v.rpc("rpc_force_teleport", target_dest + rand_offset)
		else:
			v.global_position = target_dest + rand_offset
			if v is RigidBody3D: v.linear_velocity = Vector3.ZERO
	if cam:
		var unswirl = create_tween().set_parallel(true)
		unswirl.tween_property(cam, "fov", 75.0, 0.4).set_trans(Tween.TRANS_SINE)
		unswirl.tween_property(cam, "rotation_degrees:z", 0.0, 0.4)

@rpc("any_peer", "call_local")
func rpc_force_teleport(dest: Vector3):
	if not is_multiplayer_authority(): return
	global_position = dest
	if cam:
		var flash = create_tween().set_parallel(true)
		cam.fov = 20.0
		cam.rotation_degrees.z = 180.0
		flash.tween_property(cam, "fov", 75.0, 0.5)
		flash.tween_property(cam, "rotation_degrees:z", 0.0, 0.5)

func _btn_chibaku():
	if is_instance_valid(active_chibaku_core): rpc("rpc_drop_chibaku")
	else:
		var forward_dir = -cam.global_transform.basis.z.normalized() if cam else -global_transform.basis.z.normalized()
		forward_dir.y = 0 
		var drop_pos = global_position + (forward_dir * 50.0) + Vector3(0, 60.0, 0)
		rpc("rpc_spawn_chibaku", drop_pos)

@rpc("any_peer", "call_local")
func rpc_drop_chibaku():
	if chibaku_btn and is_multiplayer_authority(): chibaku_btn.text = "[4] Chibaku Tensei"
	if not is_instance_valid(active_chibaku_core): return
	var crash_tween = create_tween()
	crash_tween.tween_property(active_chibaku_core, "global_position:y", active_chibaku_core.global_position.y - 60.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await crash_tween.finished
	if push_sound: push_sound.play()
	if cam and is_multiplayer_authority():
		var shake = create_tween()
		shake.tween_property(cam, "h_offset", 1.5, 0.05)
		shake.parallel().tween_property(cam, "v_offset", 1.5, 0.05)
		shake.tween_property(cam, "h_offset", -1.5, 0.05)
		shake.parallel().tween_property(cam, "v_offset", -1.5, 0.05)
		shake.tween_property(cam, "h_offset", 0.0, 0.05)
		shake.parallel().tween_property(cam, "v_offset", 0.0, 0.05)
	if is_instance_valid(active_chibaku_area):
		var center = active_chibaku_area.global_position
		var victims = active_chibaku_area.get_overlapping_bodies()
		for victim in victims:
			if victim != self and (victim is CharacterBody3D or victim is RigidBody3D or victim is VehicleBody3D):
				var blast_dir = (victim.global_position - center).normalized()
				blast_dir.y += 0.5 
				blast_dir = blast_dir.normalized()
				if victim.has_method("take_damage"): victim.take_damage(2000.0) 
				if victim is CharacterBody3D: victim.global_position += (blast_dir * 100.0 * 0.016)
				elif victim is RigidBody3D or victim is VehicleBody3D: victim.apply_central_impulse(blast_dir * 400.0 * victim.mass)
		active_chibaku_area.queue_free()
	active_chibaku_core.queue_free()
	if is_instance_valid(abilities):
		abilities.active_chibaku_area = null
		abilities.active_chibaku_core = null

@rpc("any_peer", "call_local")
func rpc_spawn_chibaku(drop_pos: Vector3):
	if push_sound: push_sound.play()
	if chibaku_btn and is_multiplayer_authority(): chibaku_btn.text = "[4] Drop Chibaku"
	active_chibaku_area = Area3D.new()
	var coll = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 80.0 
	coll.shape = sphere
	active_chibaku_area.add_child(coll)
	get_parent().add_child(active_chibaku_area)
	active_chibaku_area.global_position = drop_pos
	active_chibaku_core = Node3D.new()
	get_parent().add_child(active_chibaku_core)
	active_chibaku_core.global_position = drop_pos
	var black_hole = CSGSphere3D.new()
	black_hole.radius = 2.0
	var bh_mat = StandardMaterial3D.new()
	bh_mat.albedo_color = Color.BLACK
	bh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	black_hole.material = bh_mat
	active_chibaku_core.add_child(black_hole)
	var rock_shell = CSGCombiner3D.new()
	rock_shell.use_collision = true
	var outer_rock = CSGSphere3D.new()
	outer_rock.radius = 0.5
	outer_rock.radial_segments = 24
	outer_rock.rings = 12
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.35, 0.3, 0.25)
	outer_rock.material = rock_mat
	rock_shell.add_child(outer_rock)
	var inner_hollow = CSGSphere3D.new()
	inner_hollow.radius = 0.4
	inner_hollow.radial_segments = 24
	inner_hollow.rings = 12
	inner_hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	rock_shell.add_child(inner_hollow)
	active_chibaku_core.add_child(rock_shell)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(outer_rock, "radius", 25.0, 4.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(inner_hollow, "radius", 23.5, 4.0).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(abilities):
		abilities.active_chibaku_area = active_chibaku_area
		abilities.active_chibaku_core = active_chibaku_core

@rpc("any_peer", "call_local")
func rpc_pull_to_chibaku(center_pos: Vector3):
	if not is_multiplayer_authority(): return
	var pull_dir = (center_pos - global_position).normalized()
	if global_position.distance_to(center_pos) > 4.0: global_position += pull_dir * 600.0 * get_physics_process_delta_time()
	else: global_position = center_pos + Vector3(randf_range(-2,2),randf_range(-2,2),randf_range(-2,2))

func _btn_summon():
	var forward_dir = -cam.global_transform.basis.z.normalized() if cam else -global_transform.basis.z.normalized()
	forward_dir.y = 0
	rpc("rpc_summon", global_position, forward_dir)

@rpc("any_peer", "call_local")
func rpc_summon(spawn_pos: Vector3, face_dir: Vector3):
	if is_riding and is_instance_valid(my_beast):
		is_riding = false
		my_beast.queue_free()
		if summon_btn and is_multiplayer_authority(): summon_btn.text = "[5] Summon Nine-Tails"
		if has_node("CollisionShape3D"): $CollisionShape3D.disabled = false 
		return
	if not nine_tails_scene: return
	if summon_sound: summon_sound.play()
	my_beast = nine_tails_scene.instantiate()
	get_parent().add_child(my_beast)
	my_beast.global_position = spawn_pos
	my_beast.look_at(spawn_pos - face_dir, Vector3.UP)
	is_riding = true
	if summon_btn and is_multiplayer_authority(): summon_btn.text = "[5] Dismiss Summon"
	if has_node("CollisionShape3D"): $CollisionShape3D.disabled = true 

func _btn_domain(): rpc("rpc_domain")

@rpc("any_peer", "call_local")
func rpc_domain():
	if push_sound: push_sound.play()
	var d_center = Vector3(0, -9000, 0)
	var domain_parent = Node3D.new()
	get_parent().add_child(domain_parent)
	domain_parent.global_position = d_center
	var sphere = CSGSphere3D.new()
	sphere.radius = 80.0
	sphere.flip_faces = true
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0, 0) 
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0, 0) 
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	domain_parent.add_child(sphere)
	var floor_mesh = CSGCylinder3D.new()
	floor_mesh.radius = 80.0
	floor_mesh.height = 1.0
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color.BLACK
	floor_mesh.material = f_mat
	domain_parent.add_child(floor_mesh)
	floor_mesh.position = Vector3(0, -1, 0)
	var trapped = []
	if push_zone:
		for v in push_zone.get_overlapping_bodies():
			if v != self and not v is StaticBody3D: trapped.append(v)
	for v in trapped: 
		var drop_pos = d_center + Vector3(randf_range(-5,5), 1, randf_range(-5,5))
		if v.has_method("rpc_force_teleport"): v.rpc("rpc_force_teleport", drop_pos)
		else: 
			v.global_position = drop_pos
			if v is RigidBody3D: v.linear_velocity = Vector3.ZERO
	rpc("rpc_force_teleport", d_center + Vector3(0, 1, 0))
	for i in range(40): 
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(domain_parent): break
		for v in trapped:
			if is_instance_valid(v) and v.has_method("take_damage") and v != self: v.take_damage(25.0) 
		for j in range(5): 
			var slash = CSGBox3D.new()
			slash.size = Vector3(randf_range(8, 20), 0.1, randf_range(0.1, 0.4))
			var s_mat = StandardMaterial3D.new()
			s_mat.albedo_color = Color.RED
			s_mat.emission_enabled = true
			s_mat.emission = Color(1.0, 0.0, 0.0)
			s_mat.emission_energy_multiplier = 6.0
			slash.material = s_mat
			domain_parent.add_child(slash)
			slash.global_position = d_center + Vector3(randf_range(-30, 30), randf_range(0, 15), randf_range(-30, 30))
			slash.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))
			var t = create_tween()
			t.tween_property(slash, "scale", Vector3(1.5, 1.5, 1.5), 0.15)
			t.tween_callback(slash.queue_free)
	if is_instance_valid(domain_parent): domain_parent.queue_free()
	for v in trapped: 
		if is_instance_valid(v): 
			if v.has_method("rpc_force_teleport"): v.rpc("rpc_force_teleport", Vector3(0, 50, 0))
			else: v.global_position = Vector3(0, 50, 0)
	rpc("rpc_force_teleport", Vector3(0, 50, 0))

func _btn_blades(): rpc("rpc_blade_rain")
@rpc("any_peer", "call_local")
func rpc_blade_rain():
	var dir = -cam.global_transform.basis.z.normalized() if cam else -global_transform.basis.z.normalized()
	var hit_pos = global_position + (dir * 150.0)
	if push_sound: push_sound.play()
	for i in range(25):
		var sword = CSGBox3D.new()
		sword.size = Vector3(0.2, 0.2, 3.0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.0)
		mat.emission_energy_multiplier = 4.0
		sword.material = mat
		get_parent().add_child(sword)
		sword.global_position = global_position + Vector3(randf_range(-10,10), randf_range(5, 12), randf_range(-10,10))
		sword.look_at(hit_pos)
		var t = create_tween()
		t.tween_interval(randf_range(0.1, 1.0))
		t.tween_property(sword, "global_position", hit_pos + Vector3(randf_range(-5,5), 0, randf_range(-5,5)), 0.2)
		t.tween_callback(sword.queue_free)
		t.tween_callback(func(): _rpc_hitscan(sword.global_position, Vector3.DOWN, 2.0, 100.0, 0.0))

func _btn_susanoo(): rpc("rpc_susanoo")
@rpc("any_peer", "call_local")
func rpc_susanoo():
	if summon_sound: summon_sound.play()
	var aura = CSGCylinder3D.new()
	aura.radius = 5.0
	aura.height = 12.0
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0.4, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0, 0.4, 1.0)
	mat.emission_energy_multiplier = 2.0
	aura.material = mat
	add_child(aura)
	aura.position = Vector3(0, 5, 0)
	max_health = 10000.0
	current_health = 10000.0
	if health_bar: health_bar.max_value = max_health
	if health_bar: health_bar.value = current_health

func _btn_amaterasu():
	var dir = -cam.global_transform.basis.z.normalized() if cam else -global_transform.basis.z.normalized()
	var space_state = get_world_3d().direct_space_state
	var origin = cam.global_position if cam else global_position
	var query = PhysicsRayQueryParameters3D.create(origin, origin + (dir * 200.0))
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	if result and result.collider is Node: rpc("rpc_amaterasu", result.collider.get_path())

@rpc("any_peer", "call_local")
func rpc_amaterasu(target_path: NodePath):
	var target = get_node_or_null(target_path)
	if target:
		if push_sound: push_sound.play()
		var fire = CSGSphere3D.new()
		fire.radius = 1.5
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.BLACK
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0, 0)
		fire.material = mat
		target.add_child(fire)
		if target.has_method("take_damage"):
			for i in range(10):
				target.take_damage(50.0)
				await get_tree().create_timer(0.5).timeout
		else: await get_tree().create_timer(5.0).timeout
		if is_instance_valid(fire): fire.queue_free()

func _btn_meteor():
	var dir = -cam.global_transform.basis.z.normalized() if cam else -global_transform.basis.z.normalized()
	var origin = cam.global_position if cam else global_position
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + (dir * 500.0))
	query.exclude = [self.get_rid()]
	var result = space_state.intersect_ray(query)
	var hit_pos = result.position if result else origin + (dir * 100.0)
	var drop_pos = hit_pos + Vector3(0, 150.0, 0) 
	rpc("rpc_spawn_meteor", drop_pos)

@rpc("any_peer", "call_local")
func rpc_spawn_meteor(drop_pos: Vector3):
	if push_sound: push_sound.play()
	if meteor_scene:
		var m = meteor_scene.instantiate()
		get_parent().add_child(m)
		m.global_position = drop_pos

func _fire_normal_beast_blast():
	if is_instance_valid(abilities):
		if abilities.beast_blast_cooldown > 0: return 
		abilities.beast_blast_cooldown = 5.0 
	var forward_dir = -cam.global_transform.basis.z.normalized() if cam else -global_transform.basis.z.normalized()
	var base_start = global_position + Vector3(0, 1.2, 0)
	var b_color = Color.RED
	if is_instance_valid(abilities): b_color = abilities._get_beast_color(GlobalData.current_beast_id)
	rpc("rpc_fire_mini_blast", base_start, forward_dir, b_color)

@rpc("any_peer", "call_local")
func rpc_fire_mini_blast(start_pos: Vector3, forward_dir: Vector3, blast_color: Color):
	if push_sound: push_sound.play()
	var hit_pos = start_pos + (forward_dir * 100.0)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_pos, hit_pos)
	query.exclude = [self.get_rid()] 
	var result = space_state.intersect_ray(query)
	if result: hit_pos = result.position
	_launch_bomb_projectile(start_pos, hit_pos, blast_color, 0.3)

func _launch_bomb_projectile(start_pos: Vector3, hit_pos: Vector3, clr: Color, scale_mult: float):
	var dist = start_pos.distance_to(hit_pos)
	var travel_time = clamp(dist / 80.0, 0.1, 1.5) 
	var projectile = Node3D.new()
	get_parent().add_child(projectile)
	projectile.global_position = start_pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = clr
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var orb = CSGSphere3D.new()
	orb.radius = 0.5 * scale_mult
	orb.material = mat
	projectile.add_child(orb)
	var blade1 = CSGBox3D.new()
	blade1.size = Vector3(4.0 * scale_mult, 0.1, 0.5 * scale_mult) 
	blade1.material = mat
	projectile.add_child(blade1)
	var blade2 = CSGBox3D.new()
	blade2.size = Vector3(0.5 * scale_mult, 0.1, 4.0 * scale_mult)
	blade2.material = mat
	projectile.add_child(blade2)
	var shoot_tween = create_tween().set_parallel(true)
	shoot_tween.tween_property(projectile, "global_position", hit_pos, travel_time).set_trans(Tween.TRANS_LINEAR)
	shoot_tween.tween_property(projectile, "rotation_degrees:y", 3600.0, travel_time).set_trans(Tween.TRANS_LINEAR)
	await shoot_tween.finished
	if push_sound: push_sound.play() 
	var final_scale = 150.0 * scale_mult
	var expand_tween = create_tween().set_parallel(true)
	expand_tween.tween_property(projectile, "scale", Vector3(final_scale, final_scale, final_scale), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	expand_tween.tween_property(projectile, "rotation_degrees:y", projectile.rotation_degrees.y + 720.0, 0.2)
	if cam and is_multiplayer_authority():
		var shake = create_tween()
		shake.tween_property(cam, "h_offset", 1.5, 0.05)
		shake.parallel().tween_property(cam, "v_offset", 1.5, 0.05)
		shake.tween_property(cam, "h_offset", -1.5, 0.05)
		shake.parallel().tween_property(cam, "v_offset", -1.5, 0.05)
		shake.tween_property(cam, "h_offset", 0.0, 0.05)
		shake.parallel().tween_property(cam, "v_offset", 0.0, 0.05)
	var blast_zone = Area3D.new()
	var blast_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = final_scale 
	blast_shape.shape = sphere_shape
	blast_zone.add_child(blast_shape)
	get_parent().add_child(blast_zone)
	blast_zone.global_position = hit_pos
	await get_tree().physics_frame
	await get_tree().physics_frame
	var victims = blast_zone.get_overlapping_bodies()
	for victim in victims:
		if victim != self:
			var blast_dir = (victim.global_position - hit_pos).normalized()
			blast_dir.y += 0.3 
			blast_dir = blast_dir.normalized()
			if victim.has_method("take_damage"): victim.take_damage(5000.0) 
			elif "health" in victim: victim.health -= 5000.0
			elif victim.has_method("TakeDamage"): victim.TakeDamage(5000.0)
			if victim is CharacterBody3D: victim.global_position += (blast_dir * 120.0 * 0.016)
			elif victim is RigidBody3D or victim is VehicleBody3D: victim.apply_central_impulse(blast_dir * 300.0 * victim.mass)
	blast_zone.queue_free()
	var fade_tween = create_tween()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade_tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	await fade_tween.finished
	projectile.queue_free()

@rpc("any_peer", "call_local")
func rpc_shutdown_server():
	if multiplayer.is_server():
		get_tree().current_scene.rpc("rpc_receive_message", "SERVER", "« FATAL EXCEPTION: SERVER REBOOTING »")
		await get_tree().create_timer(3.0).timeout
		get_tree().quit()
