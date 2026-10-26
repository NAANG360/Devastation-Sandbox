extends Node

var username: String = "Guest"
var kills: int = 0
var deaths: int = 0
var is_admin: bool = true 

# MULTIPLAYER FAST TRAVEL MEMORY
var target_scene: String = "res://main.tscn"
var auto_reconnect: bool = false
var was_host: bool = false
var last_ip: String = "127.0.0.1"

# TAILED BEAST TRACKING
var has_fragment: bool = false
var current_fragment_id: int = 0 
var has_beast: bool = false
var current_beast_id: int = 0

# ADMOB & UNLOCKS
var chakra_ads_watched: int = 0
var has_chakra_unlocked: bool = false

signal show_pickup_notification(text: String, color: Color)
signal reward_ad_completed(code: String)

const SAVE_PATH = "user://player_save.cfg"

# ==========================================
# RESTORED GLOBAL ADMOB LOGIC
# ==========================================
var rewarded_id = "ca-app-pub-3940256099942544/5224354917" 
var rewarded_ad: RewardedAd = null
var load_callback: RewardedAdLoadCallback
var content_callback: FullScreenContentCallback
var reward_listener: OnUserEarnedRewardListener

var is_admob_ready: bool = false
var is_ad_loading: bool = false
var pending_code: String = "" 
var active_reward_code: String = ""

func _ready():
	load_data()
	apply_mobile_optimizations()
	get_tree().create_timer(1.5).timeout.connect(_init_admob)

func _init_admob():
	if is_instance_valid(MobileAds):
		print("[AdMob] Initializing SDK...")
		MobileAds.initialize()
		is_admob_ready = true
		get_tree().create_timer(0.5).timeout.connect(_load_ad)
	else:
		print("[AdMob] MobileAds singleton not found (Desktop or missing plugin).")

func _load_ad():
	if is_ad_loading or not is_admob_ready: return
	is_ad_loading = true
	print("[AdMob] Requesting new Rewarded Ad...")
	
	load_callback = RewardedAdLoadCallback.new()
	load_callback.on_ad_loaded = _on_ad_loaded
	load_callback.on_ad_failed_to_load = _on_ad_failed
	RewardedAdLoader.new().load(rewarded_id, AdRequest.new(), load_callback)

func _on_ad_loaded(ad: RewardedAd):
	print("[AdMob] Rewarded Ad successfully loaded.")
	is_ad_loading = false
	rewarded_ad = ad
	
	content_callback = FullScreenContentCallback.new()
	content_callback.on_ad_dismissed_full_screen_content = _on_ad_closed
	content_callback.on_ad_failed_to_show_full_screen_content = _on_ad_show_failed
	rewarded_ad.full_screen_content_callback = content_callback
	
	# If a button was clicked while the ad was still loading, show it immediately
	if pending_code != "":
		_show_ad()

func _on_ad_failed(error):
	print("[AdMob] Ad failed to load. Code: ", error)
	is_ad_loading = false
	# Retry loading after 5 seconds
	get_tree().create_timer(5.0).timeout.connect(_load_ad)

func _on_ad_show_failed(error):
	print("[AdMob] Ad failed to show: ", error)
	active_reward_code = ""
	pending_code = ""
	rewarded_ad = null
	_load_ad()

func _on_ad_closed():
	print("[AdMob] Ad dismissed by user.")
	rewarded_ad = null
	# Do not wipe active_reward_code here to prevent race conditions with reward listeners
	get_tree().create_timer(1.0).timeout.connect(func(): active_reward_code = "")
	_load_ad()

# ANY SCRIPT (Phone or Menu) CAN CALL THIS
func play_ad_for_code(code: String):
	print("[AdMob] Requested ad playback for code: ", code)
	pending_code = code
	
	if rewarded_ad != null:
		_show_ad()
	else:
		print("[AdMob] Ad not cached yet. Fetching now...")
		if not is_ad_loading:
			if is_admob_ready:
				_load_ad()
			else:
				# Force init if user clicked early
				_init_admob()

func _show_ad():
	active_reward_code = pending_code
	pending_code = ""
	
	reward_listener = OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = _on_reward_earned
	print("[AdMob] Displaying Rewarded Ad for: ", active_reward_code)
	rewarded_ad.show(reward_listener)

func _on_reward_earned(rewarded_item):
	var code = active_reward_code
	print("[AdMob] REWARD VERIFIED! Processing code: ", code)
	
	# Broadcast to any active UI nodes (like phone.gd) listening
	reward_ad_completed.emit(code)
	
	var local_player = _get_local_player()
	
	match code:
		"9999":
			chakra_ads_watched += 1
			print("[AdMob] Chakra ad watched. Total: ", chakra_ads_watched, "/5")
			
			var net_manager = get_tree().current_scene
			if chakra_ads_watched >= 5 and not has_chakra_unlocked:
				has_chakra_unlocked = true
				print("[AdMob] CHAKRA MODE UNLOCKED PERMANENTLY!")
				if local_player and local_player.has_method("live_unlock_chakra"):
					local_player.live_unlock_chakra()
				
				# Only remove the gift button once all 5 ads are watched
				if net_manager and "gift_btn" in net_manager and is_instance_valid(net_manager.gift_btn):
					net_manager.gift_btn.queue_free()
			else:
				# Update button text on menu if still progressing
				if net_manager and "gift_btn" in net_manager and is_instance_valid(net_manager.gift_btn):
					net_manager.gift_btn.text = "🎁 Gift (" + str(chakra_ads_watched) + "/5)"
					
			save_data()
				
		"7771", "7772", "7773", "7774":
			var car_paths = {
				"7771": "res://cube_car.tscn",
				"7772": "res://Rangerover.tscn",
				"7773": "res://landrover.tscn",
				"7774": "res://defender.tscn"
			}
			var chosen_car = car_paths.get(code, "")
			
			if local_player:
				if local_player.has_method("spawn_specific_car"):
					print("[AdMob] Invoking spawn_specific_car on local player for: ", chosen_car)
					local_player.spawn_specific_car(chosen_car)
				elif local_player.has_method("rpc_spawn_vehicle"):
					print("[AdMob] Invoking rpc_spawn_vehicle on local player for: ", chosen_car)
					local_player.rpc("rpc_spawn_vehicle", chosen_car)
				else:
					print("[AdMob] ERROR: Local player found, but has no car spawn method!")
			else:
				# Fallback to scene-level spawner if player node is not instantiated directly under root
				var current_scn = get_tree().current_scene
				if current_scn and current_scn.has_method("spawn_car_for_player"):
					current_scn.spawn_car_for_player(multiplayer.get_unique_id(), chosen_car)
				else:
					print("[AdMob] ERROR: Could not locate local player or scene vehicle spawner!")

# Comprehensive search to reliably locate the local player node
func _get_local_player() -> Node:
	var uid = str(multiplayer.get_unique_id())
	
	# 1. Search root by multiplayer ID
	var p = get_tree().root.find_child(uid, true, false)
	if p: return p
	
	# 2. Search group 'player' or 'players'
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		players = get_tree().get_nodes_in_group("players")
		
	for pl in players:
		if pl.is_multiplayer_authority():
			return pl
	if not players.is_empty():
		return players[0]
		
	# 3. Direct named search
	p = get_tree().root.find_child("Player", true, false)
	if p: return p
	
	return null

# ==========================================
# EXTREME MOBILE PERFORMANCE BOOSTER
# ==========================================
func apply_mobile_optimizations():
	# Cap frames to prevent thermal throttling
	Engine.max_fps = 60
	
	# Render 3D viewport at 65% resolution
	get_viewport().scaling_3d_scale = 0.65
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	
	# Disable heavy anti-aliasing
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	get_viewport().use_taa = false
	
	# Drop physics step to 30 ticks for battery longevity
	Engine.physics_ticks_per_second = 30
	
	# Strip heavy world environment effects
	var env = get_viewport().world_3d.fallback_environment
	if env:
		env.glow_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.sdfgi_enabled = false

func save_data():
	var config = ConfigFile.new()
	config.set_value("Player", "username", username)
	config.set_value("Player", "kills", kills)
	config.set_value("Player", "deaths", deaths)
	config.set_value("Player", "has_fragment", has_fragment)
	config.set_value("Player", "current_fragment_id", current_fragment_id)
	config.set_value("Player", "has_beast", has_beast)
	config.set_value("Player", "current_beast_id", current_beast_id)
	config.set_value("Player", "chakra_ads_watched", chakra_ads_watched)
	config.set_value("Player", "has_chakra_unlocked", has_chakra_unlocked)
	config.save(SAVE_PATH)

func load_data() -> bool:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK: return false 
	username = config.get_value("Player", "username", "Guest")
	kills = config.get_value("Player", "kills", 0)
	deaths = config.get_value("Player", "deaths", 0)
	has_fragment = config.get_value("Player", "has_fragment", false)
	current_fragment_id = config.get_value("Player", "current_fragment_id", 0)
	has_beast = config.get_value("Player", "has_beast", false)
	current_beast_id = config.get_value("Player", "current_beast_id", 0)
	chakra_ads_watched = config.get_value("Player", "chakra_ads_watched", 0)
	has_chakra_unlocked = config.get_value("Player", "has_chakra_unlocked", false)
	return true
