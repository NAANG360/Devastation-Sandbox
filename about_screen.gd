extends Control

@onready var panel = $Panel
@onready var close_btn = $Panel/CloseBtn

func _ready():
	# Hide it instantly when the game starts
	visible = false
	modulate.a = 0.0
	
	# Connect the close button
	close_btn.pressed.connect(close_about_screen)

func open_about_screen():
	visible = true
	panel.scale = Vector2(0.8, 0.8) 
	
	# Smooth fade and scale in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close_about_screen():
	# Smooth fade and scale out
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(self.hide)
