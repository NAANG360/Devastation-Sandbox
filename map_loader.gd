extends Node

var loaded_client_map: Node3D = null

func _ready():
	# STRICT HEADLESS CHECK: Only the Linux Server loads the universe!
	if DisplayServer.get_name() == "headless":
		var maps = [
			{"path": "res://sand_village.tscn", "pos": Vector3(10000, 0, 0)},
			{"path": "res://shukakuhab.tscn", "pos": Vector3(15000, 0, 0)},
			{"path": "res://matatabihab.tscn", "pos": Vector3(20000, 0, 0)},
			{"path": "res://isobuhab.tscn", "pos": Vector3(25000, 0, 0)},
			{"path": "res://songokuhab.tscn", "pos": Vector3(30000, 0, 0)},
			{"path": "res://kokuohab.tscn", "pos": Vector3(35000, 0, 0)},
			{"path": "res://saikenhab.tscn", "pos": Vector3(40000, 0, 0)},
			{"path": "res://chomeihab.tscn", "pos": Vector3(45000, 0, 0)},
			{"path": "res://gyukihab.tscn", "pos": Vector3(50000, 0, 0)},
			{"path": "res://kuramahab.tscn", "pos": Vector3(55000, 0, 0)},
			{"path": "res://altarmap.tscn", "pos": Vector3(60000, 0, 0)},
			{"path": "res://backrooms.tscn", "pos": Vector3(0, -10000, 0)}
		]
		for m in maps:
			if ResourceLoader.exists(m["path"]):
				var scene = load(m["path"]).instantiate()
				_sanitize_map(scene)
				var wrapper = Node3D.new()
				wrapper.name = m["path"].get_file().get_basename()
				wrapper.position = m["pos"] 
				wrapper.add_child(scene)
				call_deferred("add_child", wrapper)

# CLIENT: Called by player.gd when they use the travel menu
func load_client_map(map_path: String, offset: Vector3):
	if DisplayServer.get_name() == "headless": return 
	
	if is_instance_valid(loaded_client_map):
		loaded_client_map.queue_free()
		
	if map_path != "" and ResourceLoader.exists(map_path):
		var scene = load(map_path).instantiate()
		_sanitize_map(scene)
		var wrapper = Node3D.new()
		wrapper.position = offset 
		wrapper.add_child(scene)
		add_child(wrapper)
		loaded_client_map = wrapper

# THE BOUNCER: Kills duplicate lights, cameras, and overlapping music
func _sanitize_map(node: Node):
	for child in node.get_children():
		if child is DirectionalLight3D or child is WorldEnvironment or child is Camera3D or child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.queue_free()
		elif "network" in child.name.to_lower():
			child.queue_free()
		else:
			_sanitize_map(child)
