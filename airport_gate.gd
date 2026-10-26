extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body is CharacterBody3D and body.is_multiplayer_authority():
		if body.has_method("show_travel_menu"):
			body.show_travel_menu()

func _on_body_exited(body):
	if body is CharacterBody3D and body.is_multiplayer_authority():
		if body.has_method("hide_travel_menu"):
			body.hide_travel_menu()
