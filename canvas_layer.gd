extends CanvasLayer

@onready var settings_btn = $SettingsBtn
@onready var settings_panel = $SettingsPanel
@onready var steering_toggle = $SettingsPanel/SteeringToggle

func _ready():
	# Load the global preference (Defaults to True)
	var use_wheel = get_tree().root.get_meta("use_steering_wheel", true)
	steering_toggle.button_pressed = use_wheel
	
	settings_btn.pressed.connect(_on_settings_pressed)
	steering_toggle.toggled.connect(_on_steering_toggled)

func _on_settings_pressed():
	settings_panel.visible = !settings_panel.visible

func _on_steering_toggled(toggled_on: bool):
	# Saves your choice globally so the Player script can read it instantly!
	get_tree().root.set_meta("use_steering_wheel", toggled_on)
