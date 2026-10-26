extends Control

@onready var play_btn = $PlayButton
@onready var bg_color = $ColorRect

@onready var admin_panel = $AdminPanel
@onready var name_input = $AdminPanel/VBoxContainer/NameEdit
@onready var secret_input = $AdminPanel/VBoxContainer/SecretEdit
@onready var admin_login_btn = $AdminPanel/VBoxContainer/AdminLoginButton
@onready var close_btn = $AdminPanel/VBoxContainer/CloseButton
@onready var status_label = $AdminPanel/VBoxContainer/StatusLabel
@onready var secret_trigger_btn = $SecretTriggerButton

@onready var settings_btn = $CanvasLayer/SettingsBtn
@onready var settings_panel = $CanvasLayer/SettingsPanel
@onready var steering_toggle = $CanvasLayer/SettingsPanel/SteeringToggle

var secret_click_count = 0

func _ready():
	admin_panel.hide()
	settings_panel.hide()
	
	# SAFETY CHECKS: Only connect if the Editor hasn't already done it!
	if not play_btn.pressed.is_connected(_on_play_button_pressed):
		play_btn.pressed.connect(_on_play_button_pressed)
		
	if not secret_trigger_btn.pressed.is_connected(_on_secret_trigger_button_pressed):
		secret_trigger_btn.pressed.connect(_on_secret_trigger_button_pressed)
		
	if not admin_login_btn.pressed.is_connected(_on_admin_login_button_pressed):
		admin_login_btn.pressed.connect(_on_admin_login_button_pressed)
		
	if not close_btn.pressed.is_connected(_on_close_button_pressed):
		close_btn.pressed.connect(_on_close_button_pressed)
		
	if not settings_btn.pressed.is_connected(_on_settings_button_pressed):
		settings_btn.pressed.connect(_on_settings_button_pressed)
		
	if not steering_toggle.toggled.is_connected(_on_steering_toggled):
		steering_toggle.toggled.connect(_on_steering_toggled)
	
	var use_wheel = get_tree().root.get_meta("use_steering_wheel", true)
	steering_toggle.button_pressed = use_wheel

func _on_play_button_pressed():
	print("Loading City...")
	get_tree().change_scene_to_file("res://main.tscn")

func _on_close_button_pressed():
	admin_panel.hide()

func _on_settings_button_pressed():
	settings_panel.visible = !settings_panel.visible

func _on_steering_toggled(button_pressed: bool):
	get_tree().root.set_meta("use_steering_wheel", button_pressed)

func _on_secret_trigger_button_pressed():
	secret_click_count += 1
	admin_panel.show()
	
	if secret_click_count >= 5:
		print("BIMBIMBAMBAM! Rave mode activated.")
		status_label.text = "YOU FOUND THE EASTER EGG!"
		status_label.add_theme_color_override("font_color", Color(randf(), randf(), randf()))
		bg_color.color = Color(randf(), randf(), randf())

func _on_admin_login_button_pressed():
	var user_name = name_input.text.strip_edges()
	var secret = secret_input.text.strip_edges()
	
	if user_name == "ShouryLmfao" and secret == "Lucidosiscool":
		status_label.text = "WELCOME BACK, GOD OF THIS WORLD."
		status_label.add_theme_color_override("font_color", Color.GREEN)
		get_tree().root.set_meta("is_admin", true)
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://main.tscn")
		
	elif user_name.to_lower() == "naruto" and secret.to_lower() == "dattebayo":
		status_label.text = "BELIEVE IT! (But you still aren't Admin)"
		status_label.add_theme_color_override("font_color", Color.ORANGE)
		
	elif user_name.to_lower() == "bimbimbambam":
		status_label.text = "SERVER ARCHITECTURE GO BRRRR"
		status_label.add_theme_color_override("font_color", Color.CYAN)
		
	else:
		status_label.text = "ACCESS DENIED, MORTAL."
		status_label.add_theme_color_override("font_color", Color.RED)
		bg_color.color = Color.BLACK
		secret_click_count = 0
