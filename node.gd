extends Node

func _ready():
	print("Starting background bake...")
	
	# 1. Load the raw mesh data
	var mesh_data = load("res://map_collision.obj")
	
	# 2. Generate the collision shape purely in memory
	var shape = mesh_data.create_trimesh_shape()
	
	# 3. Save it permanently to your files
	ResourceSaver.save(shape, "res://baked_city_collision.tres")
	
	print("SUCCESS: Check your FileSystem for baked_city_collision.tres!")
