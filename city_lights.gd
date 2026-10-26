extends Node

# Drag your city map node into this slot in the Inspector
@export var city_map: Node3D 

# Updated to match your screenshot
@export var mesh_keyword: String = "Road Light" 

# How high up the pole the bulb is (adjust this if the light is on the ground!)
@export var bulb_height: float = 6.0 

@export var light_color: Color = Color("ffddaa")
@export var light_energy: float = 3.0
@export var light_range: float = 20.0

func _ready():
	if not city_map:
		print("ERROR: You forgot to drag the City Map into the CityLights script!")
		return
		
	print("Scanning city for lights...")
	scan_for_lights(city_map)

func scan_for_lights(node: Node):
	for child in node.get_children():
		# Did we find ANY node that has "road light" in the name?
		if mesh_keyword.to_lower() in child.name.to_lower():
			spawn_spotlight(child)
			# Stop digging into this specific folder so we don't accidentally spawn 2 lights on 1 pole
			continue 
			
		# Keep digging deeper into the map's folders
		if child.get_child_count() > 0:
			scan_for_lights(child)

func spawn_spotlight(pole: Node):
	var spot = SpotLight3D.new()
	
	spot.light_color = light_color
	spot.light_energy = light_energy
	spot.spot_range = light_range
	spot.spot_angle = 45.0 
	
	spot.rotation_degrees = Vector3(-90, 0, 0)
	
	# Try turning this to false if your phone starts lagging!
	spot.shadow_enabled = true 
	
	pole.add_child(spot)
	spot.position = Vector3(0, bulb_height, 0) 
