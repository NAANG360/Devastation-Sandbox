extends DirectionalLight3D

var day_speed = 0.02 
var is_night = false
var manager: Node

@onready var world_env = $"../WorldEnvironment".environment

func _ready():
	manager = get_tree().current_scene.find_child("BackroomsManager", true, false)

func _process(delta):
	rotation_degrees.x -= day_speed * delta
	
	if rotation_degrees.x <= -360.0:
		rotation_degrees.x += 360.0
		
	if rotation_degrees.x < -180.0:
		# NIGHT TIME
		light_energy = 0.2 
		world_env.ambient_light_energy = 0.8 
		world_env.background_energy_multiplier = 0.1
		
		# TRIGGER THE DOOR ONCE
		if not is_night:
			is_night = true
			if manager and manager.has_method("spawn_night_door"):
				# 1-in-3 chance the door spawns tonight. You can change this!
				if randi() % 3 == 0: 
					manager.spawn_night_door()
	else:
		# DAY TIME
		light_energy = 1.0 
		world_env.ambient_light_energy = 1.0
		world_env.background_energy_multiplier = 1.0
		
		# DELETE THE DOOR AT SUNRISE
		if is_night:
			is_night = false
			if manager and manager.has_method("remove_night_door"):
				manager.remove_night_door()
