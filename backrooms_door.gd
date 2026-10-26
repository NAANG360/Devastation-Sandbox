extends Area3D

var manager: Node

func _ready():
	body_entered.connect(_on_body_entered)
	
	# Find the Manager in the scene tree automatically
	manager = get_tree().current_scene.find_child("BackroomsManager", true, false)
	
	# 1. BUILD THE 3D DOOR AUTOMATICALLY
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.5, 2.5, 0.4) # 1.5m wide, 2.5m tall, 0.4m thick
	mesh_instance.mesh = box_mesh
	
	# 2. MAKE IT GLOW BLINDINGLY WHITE
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 15.0 # Flashbang levels of glow
	mesh_instance.material_override = mat
	
	add_child(mesh_instance)
	
	# 3. BUILD THE INVISIBLE HITBOX AUTOMATICALLY
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = box_mesh.size
	collision.shape = box_shape
	add_child(collision)
	
	# Optional: Raise the door up slightly so it doesn't clip into the floor
	mesh_instance.position.y = box_mesh.size.y / 2.0
	collision.position.y = box_shape.size.y / 2.0

func _on_body_entered(body):
	if body is CharacterBody3D and body.is_multiplayer_authority():
		if manager and manager.has_method("trigger_backrooms"):
			manager.trigger_backrooms(body)
			
			# Destroy the door after someone uses it
			queue_free() 
