extends Camera3D
var mouse_sensitivity = 0.005
func _input(event):
	if current and event is InputEventScreenDrag:
		var screen_width = get_viewport().get_visible_rect().size.x
		if event.position.x > (screen_width / 2):
			rotation.y -= event.relative.x * mouse_sensitivity
			rotation.x -= event.relative.y * mouse_sensitivity
			rotation.x = clamp(rotation.x, -1.2, 1.2)
			rotation.z = 0
