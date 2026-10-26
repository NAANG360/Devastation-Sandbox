extends Node3D

@export var player_scene: PackedScene

const PORT = 7860
const BROADCAST_PORT = 7861 
const CLOUD_URL = "wss://shourylmfao-ars-city-server.hf.space"

var console_thread: Thread
var left_menu_panel: Control
var start_btn: Button
var host_btn: Button
var quit_btn: Button
var about_btn: Button
var about_screen: Control
var settings_btn: Button
var host_name_input: LineEdit
var lobby_list: OptionButton
var refresh_btn: Button
var settings_panel: Control
var steering_toggle: CheckButton
var chat_panel: Control
var chat_display: RichTextLabel
var chat_input: LineEdit
var send_btn: Button
var chat_toggle_btn: Button
var admin_panel: Control
var secret_trigger_btn: Button
var name_input: LineEdit
var secret_input: LineEdit
var admin_login_btn: Button
var close_btn: Button
var status_label: Label

var idle_npc: Node3D
var menu_camera: Camera3D

var udp_peer = PacketPeerUDP.new()
var is_broadcasting: bool = false
var is_listening: bool = false
var search_timeout: float = 0.0
var broadcast_timer: float = 0.0
var my_server_name = "Local City Server"
var discovered_ips = []
var secret_click_count = 0

# Gift Box Variables
var chakra_clicks: int = 0
var gift_btn: Button

var sun: DirectionalLight3D
var is_raining: bool = false
var weather_timer: float = 30.0 
var rain_audio: AudioStreamPlayer
var night_audio: AudioStreamPlayer

func _find_anywhere(node_name: String) -> Node:
	var local_node = find_child(node_name, true, false)
	if local_node: return local_node
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene.find_child(node_name, true, false)
	return null

func _ready():
	if OS.has_feature("android") or OS.has_feature("mobile"):
		OS.request_permission("RECORD_AUDIO")
		DisplayServer.screen_set_keep_on(true) 
	
	left_menu_panel = _find_anywhere("LeftMenuPanel")
	
	if DisplayServer.get_name() == "headless":
		_on_host() 
		console_thread = Thread.new()
		console_thread.start(_console_loop)
	
	if not left_menu_panel: left_menu_panel = _find_anywhere("ColorRect") 
	
	sun = _find_anywhere("DirectionalLight3D")
	rain_audio = _find_anywhere("RainAudio")
	night_audio = _find_anywhere("NightAudio")
	
	start_btn = _find_anywhere("StartBtn")
	host_btn = _find_anywhere("HostBtn")
	quit_btn = _find_anywhere("QuitBtn")
	about_btn = _find_anywhere("AboutBtn")
	about_screen = _find_anywhere("AboutScreen")
	settings_btn = _find_anywhere("SettingsBtn")
	host_name_input = _find_anywhere("HostNameInput")
	lobby_list = _find_anywhere("LobbyList")
	refresh_btn = _find_anywhere("RefreshBtn")
	settings_panel = _find_anywhere("SettingsPanel")
	steering_toggle = _find_anywhere("SteeringToggle")
	chat_panel = _find_anywhere("ChatPanel")
	chat_display = _find_anywhere("ChatDisplay")
	chat_input = _find_anywhere("ChatInput")
	send_btn = _find_anywhere("SendBtn")
	chat_toggle_btn = _find_anywhere("ChatToggleBtn")
	admin_panel = _find_anywhere("AdminPanel")
	secret_trigger_btn = _find_anywhere("SecretTriggerButton")
	name_input = _find_anywhere("NameEdit")
	secret_input = _find_anywhere("SecretEdit")
	admin_login_btn = _find_anywhere("AdminLoginButton")
	close_btn = _find_anywhere("CloseButton")
	status_label = _find_anywhere("StatusLabel")
	idle_npc = _find_anywhere("IdleNPC")
	menu_camera = _find_anywhere("Camera3D")
	
	if chat_panel: chat_panel.hide()
	if chat_toggle_btn: chat_toggle_btn.hide()
	if admin_panel: admin_panel.hide()
	if settings_panel: settings_panel.hide()
	if left_menu_panel: left_menu_panel.show()
	if settings_btn: settings_btn.show()
	if menu_camera: menu_camera.make_current()
	
	if start_btn and not start_btn.pressed.is_connected(_on_join): start_btn.pressed.connect(_on_join)
	if host_btn and not host_btn.pressed.is_connected(_on_host): host_btn.pressed.connect(_on_host)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit): quit_btn.pressed.connect(_on_quit)
	if about_btn and not about_btn.pressed.is_connected(_on_about): about_btn.pressed.connect(_on_about)
	if refresh_btn and not refresh_btn.pressed.is_connected(_refresh_lan): refresh_btn.pressed.connect(_refresh_lan)
	if settings_btn and not settings_btn.pressed.is_connected(_on_settings): settings_btn.pressed.connect(_on_settings)
	
	if steering_toggle:
		if not steering_toggle.toggled.is_connected(_on_steering_toggled): steering_toggle.toggled.connect(_on_steering_toggled)
		var use_wheel = get_tree().root.get_meta("use_steering_wheel", true)
		steering_toggle.button_pressed = use_wheel
	
	if secret_trigger_btn and not secret_trigger_btn.pressed.is_connected(_on_secret_triggered): secret_trigger_btn.pressed.connect(_on_secret_triggered)
	if admin_login_btn and not admin_login_btn.pressed.is_connected(_on_admin_login): admin_login_btn.pressed.connect(_on_admin_login)
	if close_btn and not close_btn.pressed.is_connected(func(): admin_panel.hide()): close_btn.pressed.connect(func(): admin_panel.hide())
	if chat_toggle_btn and not chat_toggle_btn.pressed.is_connected(_toggle_chat): chat_toggle_btn.pressed.connect(_toggle_chat)
	if send_btn and not send_btn.pressed.is_connected(_send_chat_message): send_btn.pressed.connect(_send_chat_message)
	
	var spawner = MultiplayerSpawner.new()
	spawner.name = "MultiplayerSpawner"
	add_child(spawner) 
	spawner.spawn_path = self.get_path() 
	spawner.add_spawnable_scene(player_scene.resource_path)
	spawner.add_spawnable_scene("res://police_npc.tscn")
	
	# Add the spawnable vehicles to the network manager spawner
	spawner.add_spawnable_scene("res://cube_car.tscn")
	spawner.add_spawnable_scene("res://Rangerover.tscn")
	spawner.add_spawnable_scene("res://landrover.tscn")
	spawner.add_spawnable_scene("res://defender.tscn")
	
	# Connect to the GlobalData ad signal to spawn vehicles
	if get_node_or_null("/root/GlobalData"):
		if not GlobalData.reward_ad_completed.is_connected(_on_ad_reward_received):
			GlobalData.reward_ad_completed.connect(_on_ad_reward_received)
	
	_setup_lobby_list()
	_build_gift_button()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if chat_panel and chat_panel.visible:
			var chat_rect = chat_panel.get_global_rect()
			var toggle_rect = chat_toggle_btn.get_global_rect() if chat_toggle_btn else Rect2()
			if not chat_rect.has_point(event.global_position) and not toggle_rect.has_point(event.global_position):
				chat_panel.visible = false

func _toggle_chat():
	if chat_panel: chat_panel.visible = !chat_panel.visible

func _on_quit(): get_tree().quit()

func _on_about():
	if about_screen and about_screen.has_method("open_about_screen"):
		about_screen.open_about_screen()

func _on_settings(): if settings_panel: settings_panel.visible = !settings_panel.visible
func _on_steering_toggled(button_pressed: bool): get_tree().root.set_meta("use_steering_wheel", button_pressed)

func _on_secret_triggered():
	secret_click_count += 1
	if admin_panel: admin_panel.show()
	if secret_click_count >= 5 and status_label:
		status_label.text = "YOU FOUND THE EASTER EGG!"
		status_label.add_theme_color_override("font_color", Color(randf(), randf(), randf()))

func _on_admin_login():
	if not name_input or not secret_input or not status_label: return
	var user_name = name_input.text.strip_edges()
	var secret = secret_input.text.strip_edges()
	if user_name == "ShouryLmfao" and secret == "Lucidosiscool":
		status_label.text = "WELCOME BACK."
		status_label.add_theme_color_override("font_color", Color.GREEN)
		get_tree().root.set_meta("is_admin", true)
		await get_tree().create_timer(1.0).timeout
		if admin_panel: admin_panel.hide()
	else:
		status_label.text = "ACCESS DENIED."
		status_label.add_theme_color_override("font_color", Color.RED)
		secret_click_count = 0

func _setup_lobby_list():
	if not lobby_list: return
	lobby_list.clear()
	lobby_list.add_item("☁️ Official Cloud Server")
	lobby_list.set_item_metadata(0, CLOUD_URL)
	discovered_ips.clear()

func _refresh_lan():
	_setup_lobby_list() 
	if udp_peer.bind(BROADCAST_PORT) == OK:
		is_listening = true
		search_timeout = 2.0 
		if start_btn: start_btn.text = "Searching Wi-Fi..."

func _process(delta):
	if is_broadcasting:
		broadcast_timer -= delta
		if broadcast_timer <= 0:
			broadcast_timer = 1.0 
			udp_peer.put_packet(("ARS_CITY|" + my_server_name).to_ascii_buffer())
			
	if is_listening:
		search_timeout -= delta
		while udp_peer.get_available_packet_count() > 0:
			var packet = udp_peer.get_packet()
			var msg = packet.get_string_from_ascii()
			var host_ip = udp_peer.get_packet_ip()
			if msg.begins_with("ARS_CITY|"):
				var srv_name = msg.split("|")[1]
				if not discovered_ips.has(host_ip):
					discovered_ips.append(host_ip)
					if lobby_list:
						var idx = lobby_list.get_item_count()
						lobby_list.add_item("📶 " + srv_name + " (" + host_ip + ")")
						lobby_list.set_item_metadata(idx, "ws://" + host_ip + ":" + str(PORT))
		if search_timeout <= 0:
			is_listening = false
			udp_peer.close()
			if start_btn: start_btn.text = "Start Game"

	if is_instance_valid(sun):
		sun.rotation_degrees.x -= delta * 2.0 
		if sun.rotation_degrees.x < -180 or sun.rotation_degrees.x > 0:
			if night_audio: night_audio.volume_db = lerp(night_audio.volume_db, 0.0, delta * 2.0)
		else:
			if night_audio: night_audio.volume_db = lerp(night_audio.volume_db, -80.0, delta * 2.0)

	if multiplayer.is_server():
		weather_timer -= delta
		if weather_timer <= 0:
			weather_timer = randf_range(60.0, 180.0) 
			var should_rain = (randf() > 0.5) 
			if should_rain != is_raining: rpc("rpc_set_global_weather", should_rain)
				
	if is_raining:
		if rain_audio: rain_audio.volume_db = lerp(rain_audio.volume_db, 0.0, delta * 3.0)
	else:
		if rain_audio: rain_audio.volume_db = lerp(rain_audio.volume_db, -80.0, delta * 3.0)

@rpc("any_peer", "call_local", "reliable")
func rpc_set_global_weather(rain_state: bool):
	is_raining = rain_state
	for child in get_children():
		if child is CharacterBody3D and child.has_node("RainParticles"):
			child.get_node("RainParticles").emitting = rain_state

func _on_host():
	if host_name_input and host_name_input.text.strip_edges() != "": my_server_name = host_name_input.text.strip_edges()
	var peer = WebSocketMultiplayerPeer.new()
	if peer.create_server(PORT) == OK:
		multiplayer.multiplayer_peer = peer
		if not multiplayer.peer_connected.is_connected(_add_player): multiplayer.peer_connected.connect(_add_player)
		if DisplayServer.get_name() != "headless":
			_add_player(multiplayer.get_unique_id())
			udp_peer.set_broadcast_enabled(true)
			udp_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
			is_broadcasting = true
		_transition_to_game()

func _on_join():
	var target_url = CLOUD_URL 
	if lobby_list and lobby_list.get_item_count() > 0 and lobby_list.is_visible_in_tree(): 
		target_url = lobby_list.get_item_metadata(lobby_list.selected)
		
	var peer = WebSocketMultiplayerPeer.new()
	if peer.create_client(target_url) == OK:
		multiplayer.multiplayer_peer = peer
		if not multiplayer.connected_to_server.is_connected(_on_connection_success): multiplayer.connected_to_server.connect(_on_connection_success)
		if not multiplayer.connection_failed.is_connected(_on_connection_fail): multiplayer.connection_failed.connect(_on_connection_fail)
		if not multiplayer.server_disconnected.is_connected(_on_server_disconnect): multiplayer.server_disconnected.connect(_on_server_disconnect)
		_transition_to_game() 
	else:
		_on_connection_fail()

func _on_server_disconnect(): get_tree().reload_current_scene()
func _on_connection_success(): pass

func _on_connection_fail():
	is_listening = false
	if start_btn: 
		start_btn.show()
		start_btn.text = "Connection Failed!"
	await get_tree().create_timer(2.0).timeout
	if start_btn: start_btn.text = "Start Game"

func _add_player(id: int):
	var p = player_scene.instantiate()
	p.name = str(id) 
	add_child(p) 
	p.global_position = self.global_position + Vector3(randf_range(-2.0, 2.0), 10.0, randf_range(-2.0, 2.0))

func _transition_to_game():
	if left_menu_panel: left_menu_panel.hide()
	if settings_btn: settings_btn.hide()
	if settings_panel: settings_panel.hide()
	if admin_panel: admin_panel.hide()
	if about_screen: about_screen.hide() 
	if lobby_list: lobby_list.hide()
	if refresh_btn: refresh_btn.hide()
	if start_btn: start_btn.hide()
	if host_btn: host_btn.hide()
	if host_name_input: host_name_input.hide()
	if quit_btn: quit_btn.hide()
	if about_btn: about_btn.hide()
	
	if is_instance_valid(gift_btn): gift_btn.hide()
	
	if secret_trigger_btn:
		secret_trigger_btn.hide()
		secret_trigger_btn.disabled = true 
	
	var my_id = str(multiplayer.get_unique_id())
	var my_player = null
	var timeout = 0
	
	while my_player == null and timeout < 600: 
		await get_tree().process_frame
		my_player = get_node_or_null(my_id)
		timeout += 1
		
	await get_tree().create_timer(1.0).timeout

	if my_player:
		var my_cam = my_player.find_child("Camera3D", true, false)
		if my_cam: my_cam.make_current()

	if is_instance_valid(idle_npc): idle_npc.queue_free()
	if is_instance_valid(menu_camera): menu_camera.queue_free()
	else:
		var fallback_cam = get_parent().get_node_or_null("Camera3D")
		if fallback_cam: fallback_cam.queue_free()
	
	if chat_toggle_btn: chat_toggle_btn.show()
	_add_to_chat("SYSTEM", "Connected! Type to chat.")

@rpc("any_peer", "call_local", "reliable")
func rpc_receive_message(sender_name: String, message: String):
	_add_to_chat(sender_name, message)

func _add_to_chat(sender: String, message: String):
	if not chat_display: return
	if sender == "ShouryLmfao": chat_display.text += "\n[color=red][ADMIN][/color] " + sender + ": " + message
	else: chat_display.text += "\n[" + sender + "]: " + message
	var scrollbar = chat_display.get_v_scroll_bar()
	if scrollbar: scrollbar.value = scrollbar.max_value

func _console_loop():
	print("=====================================")
	print("  SERVER CONSOLE ACTIVE")
	print("  Type to broadcast to all players.")
	print("  Commands: /players, /quit")
	print("=====================================")
	
	while true:
		var input_str = OS.read_string_from_stdin()
		if input_str and input_str.strip_edges() != "":
			call_deferred("_handle_console_command", input_str.strip_edges())
		else:
			OS.delay_msec(100) 

func _handle_console_command(cmd: String):
	var lower_cmd = cmd.to_lower()
	if lower_cmd == "/quit" or lower_cmd == "/stop":
		print("SERVER SHUTTING DOWN...")
		get_tree().quit()
		return
	if lower_cmd == "/players":
		var peers = multiplayer.get_peers()
		print("Connected Players (" + str(peers.size()) + "): ", peers)
		return
	var active_scene = get_tree().current_scene
	if active_scene and active_scene.has_method("rpc_receive_message"):
		active_scene.rpc("rpc_receive_message", "SYSTEM", "« " + cmd + " »")
		print("Broadcasted: ", cmd)

func _send_chat_message():
	if not chat_input: return
	var msg = chat_input.text.strip_edges()
	if msg == "": return
	chat_input.text = ""
	
	if "spatial movement" in msg.to_lower():
		rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Executing Spatial Movement to Network Anchor. »")
		var my_id = str(multiplayer.get_unique_id())
		var my_player = get_node_or_null(my_id)
		
		if is_instance_valid(my_player):
			var random_offset = Vector3(randf_range(-15.0, 15.0), 3.0, randf_range(-15.0, 15.0))
			var target_pos = global_position + random_offset
			if my_player.get("is_riding") and is_instance_valid(my_player.get("my_beast")):
				my_player.my_beast.global_position = target_pos
			else:
				my_player.global_position = target_pos
			if "velocity" in my_player: my_player.velocity = Vector3.ZERO
			if "last_y_velocity" in my_player: my_player.last_y_velocity = 0.0
		return
		
	rpc("rpc_receive_message", GlobalData.username, msg)

# ==========================================
# CHAKRA GIFT UNLOCKER
# ==========================================
func _build_gift_button():
	if get_node_or_null("/root/GlobalData") and GlobalData.has_chakra_unlocked: return
		
	gift_btn = Button.new()
	var current_watches = 0
	if get_node_or_null("/root/GlobalData"):
		current_watches = GlobalData.chakra_ads_watched
		
	if current_watches > 0:
		gift_btn.text = "🎁 Gift (" + str(current_watches) + "/5)" 
	else:
		gift_btn.text = "🎁 Claim Gift"
		
	gift_btn.focus_mode = Control.FOCUS_NONE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.1, 0.2, 1.0) 
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_bottom = 4
	style.border_color = Color(0.5, 0.0, 0.1, 1.0)
	gift_btn.add_theme_stylebox_override("normal", style)
	gift_btn.add_theme_stylebox_override("hover", style)
	gift_btn.add_theme_stylebox_override("pressed", style)
	gift_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gift_btn.custom_minimum_size = Vector2(160, 60)
	gift_btn.position = Vector2(-180, 20) 
	gift_btn.pressed.connect(_on_gift_clicked)
	add_child(gift_btn)

func _on_gift_clicked():
	chakra_clicks += 1
	if chakra_clicks < 5:
		gift_btn.text = "🎁 Opening... (" + str(5 - chakra_clicks) + ")"
		var pop = create_tween()
		gift_btn.scale = Vector2(0.9, 0.9)
		gift_btn.pivot_offset = gift_btn.size / 2.0
		pop.tween_property(gift_btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_BOUNCE)
	else:
		gift_btn.text = "Loading Ad..."
		if get_node_or_null("/root/GlobalData"):
			GlobalData.play_ad_for_code("9999")

# ==========================================
# NETWORK VEHICLE SPAWNER
# ==========================================
func _on_ad_reward_received(code: String):
	# If the code isn't for a car, ignore it. GlobalData handles Chakra internally.
	if code not in ["7771", "7772", "7773", "7774"]: return
	
	var car_paths = {
		"7771": "res://cube_car.tscn",
		"7772": "res://Rangerover.tscn",
		"7773": "res://landrover.tscn",
		"7774": "res://defender.tscn"
	}
	
	var chosen_car = car_paths[code]
	var my_id = multiplayer.get_unique_id()
	
	if multiplayer.is_server():
		_execute_car_spawn(my_id, chosen_car)
	else:
		rpc_id(1, "_request_car_spawn", my_id, chosen_car)

@rpc("any_peer", "call_local", "reliable")
func _request_car_spawn(player_id: int, car_path: String):
	if not multiplayer.is_server(): return
	_execute_car_spawn(player_id, car_path)

func _execute_car_spawn(player_id: int, car_path: String):
	var player_node = get_node_or_null(str(player_id))
	var spawn_pos = Vector3.ZERO
	var forward_dir = Vector3(0, 0, 1)
	
	if is_instance_valid(player_node):
		spawn_pos = player_node.global_position
		forward_dir = -player_node.global_transform.basis.z.normalized()
		spawn_pos += forward_dir * 5.0
		spawn_pos.y += 2.0 
		
	var car_scene = load(car_path)
	if car_scene:
		var car = car_scene.instantiate()
		# Networked nodes must have unique names to sync properly
		car.name = "Vehicle_" + str(player_id) + "_" + str(Time.get_ticks_msec())
		add_child(car, true)
		car.global_position = spawn_pos
		
		# Turn the vehicle towards the player slightly
		car.look_at(spawn_pos + forward_dir, Vector3.UP)
