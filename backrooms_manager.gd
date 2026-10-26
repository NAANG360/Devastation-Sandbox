extends Node

# == THESE WILL SHOW UP IN YOUR INSPECTOR NOW ==
@export var backrooms_door_scene: PackedScene 
@export var weird_sound: AudioStream
@export var void_y_level: float = -15.0 

var glitch_ui: CanvasLayer
var glitch_rect: ColorRect
var audio_player: AudioStreamPlayer
var spawned_door: Node3D = null

@onready var map_loader = $"../MapLoader" 

func _ready():
	# 1. THE INVISIBLE VOID NET
	var void_area = Area3D.new()
	void_area.name = "DynamicVoidTrigger"
	void_area.global_position = Vector3(0, void_y_level, 0)
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(20000, 10, 20000) 
	collision.shape = box
	void_area.add_child(collision)
	add_child(void_area)
	void_area.body_entered.connect(_on_void_entered)

	# 2. THE GLITCH UI
	glitch_ui = CanvasLayer.new()
	glitch_ui.layer = 100
	glitch_rect = ColorRect.new()
	glitch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_rect.color = Color(0.8, 0.8, 0.2, 0.8)
	glitch_rect.hide()
	glitch_ui.add_child(glitch_rect)
	add_child(glitch_ui)

	# 3. THE AUDIO
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = weird_sound
	add_child(audio_player)

func _on_void_entered(body):
	trigger_backrooms(body)

func trigger_backrooms(body):
	if body.name == "player" or body.has_method("_btn_car"):
		if not body.is_multiplayer_authority(): return 

		if map_loader and map_loader.has_method("load_client_map"):
			map_loader.load_client_map("res://backrooms.tscn", Vector3(0, -10000, 0))

		if body is CharacterBody3D:
			body.velocity = Vector3.ZERO
			
		body.global_position = Vector3(0, -9990, 0)

		if weird_sound: audio_player.play()
		_play_glitch_effect()

func _play_glitch_effect():
	if not is_instance_valid(glitch_rect): return
	var tween = create_tween()
	for i in range(5):
		tween.tween_callback(glitch_rect.show)
		tween.tween_interval(0.04)
		tween.tween_callback(glitch_rect.hide)
		tween.tween_interval(0.04)

# ==========================================
# THE NIGHT DOOR SPAWNER (OPTION 2)
# ==========================================
func spawn_night_door():
	if not backrooms_door_scene: return
	if is_instance_valid(spawned_door): return # Door already exists
	
	# Scan the entire city for existing doors
	var all_meshes = get_tree().current_scene.find_children("*", "MeshInstance3D", true, false)
	var possible_doors = []
	
	for mesh in all_meshes:
		if "door" in mesh.name.to_lower():
			possible_doors.append(mesh)
			
	if possible_doors.size() > 0:
		# Pick a random door in the city
		var chosen_door = possible_doors.pick_random()
		
		# Build the glowing portal exactly where that door is
		spawned_door = backrooms_door_scene.instantiate()
		get_tree().current_scene.add_child(spawned_door)
		spawned_door.global_position = chosen_door.global_position
		
		# Push it slightly outward so it doesn't clip into the wall
		spawned_door.global_position.z += 1.0 
	else:
		print("BackroomsManager: No meshes with 'door' in their name were found!")

func remove_night_door():
	if is_instance_valid(spawned_door):
		spawned_door.queue_free()
		spawned_door = null
