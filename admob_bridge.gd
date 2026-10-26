extends Node

# These are the exact signals the PhoneUI is listening for!
signal rewarded_ad_loaded
signal rewarded_ad_user_earned_reward(reward_type, reward_amount)
signal rewarded_ad_closed

var is_loaded: bool = false

func initialize():
	print("[AdMob Simulator] System Online!")

func load_rewarded_ad(id: String):
	print("[AdMob Simulator] Downloading video ad from server...")
	# Simulate the 1.5 seconds it takes an Android phone to load an ad
	await get_tree().create_timer(1.5).timeout
	is_loaded = true
	rewarded_ad_loaded.emit()

func is_rewarded_ad_loaded() -> bool:
	return is_loaded

func show_rewarded_ad():
	if not is_loaded: return
	is_loaded = false
	
	# ==========================================
	# THE FIX: CanvasLayer forces it over the camera
	# ==========================================
	var ad_layer = CanvasLayer.new()
	ad_layer.layer = 128 # Maximum top layer so nothing overlaps it
	get_tree().root.add_child(ad_layer)
	
	var screen_size = get_viewport().get_visible_rect().size
	
	var fake_ad_bg = ColorRect.new()
	fake_ad_bg.color = Color(0.05, 0.05, 0.05, 0.98) 
	fake_ad_bg.size = screen_size # Forces it to cover the entire screen
	fake_ad_bg.mouse_filter = Control.MOUSE_FILTER_STOP 
	ad_layer.add_child(fake_ad_bg)
	
	var fake_video = ColorRect.new()
	fake_video.color = Color(0.1, 0.3, 0.6, 1.0) 
	
	# Responsive size: 80% of screen width, max 800px
	var vid_width = min(screen_size.x * 0.8, 800)
	var vid_height = min(screen_size.y * 0.5, 450)
	fake_video.size = Vector2(vid_width, vid_height)
	
	# Manually center the blue box
	fake_video.position = (screen_size / 2.0) - (fake_video.size / 2.0)
	fake_ad_bg.add_child(fake_video)
	
	var label = Label.new()
	label.text = "🎬 SPONSOR AD PLAYING...\n\n(Simulated AdMob Video)\n\nPlease wait 3 seconds to get your reward!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = screen_size # Stretches text box across screen for perfect centering
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color.WHITE)
	fake_ad_bg.add_child(label)
	
	# Let the "video" play for 3 seconds
	await get_tree().create_timer(3.0).timeout
	
	# Destroy the ad layer and grant the reward!
	ad_layer.queue_free()
	rewarded_ad_user_earned_reward.emit("Chakra", 1)
	rewarded_ad_closed.emit()
