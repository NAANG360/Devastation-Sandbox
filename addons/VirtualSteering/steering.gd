@tool @icon("res://addons/VirtualSteering/icon.png")
extends TextureRect

@export var max_angle: float = 120.0
var is_dragging: bool = false

func _ready():
	pivot_offset = size / 2.0

func _process(delta):
	if not is_dragging:
		rotation_degrees = lerp(rotation_degrees, 0.0, 15.0 * delta)
		_send_input(rotation_degrees / max_angle)

func _gui_input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			is_dragging = true
		else:
			is_dragging = false
			
	if is_dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		var center_point = size / 2.0
		var direction = (event.position - center_point).normalized()
		var angle = atan2(direction.y, direction.x) + (PI / 2.0)
		
		rotation_degrees = clamp(rad_to_deg(angle), -max_angle, max_angle)
		_send_input(rotation_degrees / max_angle)

func _send_input(strength: float):
	if strength < -0.05:
		Input.action_press("ui_left", abs(strength))
		Input.action_release("ui_right")
	elif strength > 0.05:
		Input.action_press("ui_right", strength)
		Input.action_release("ui_left")
	else:
		Input.action_release("ui_left")
		Input.action_release("ui_right")
