@tool
extends Area3D

@export_range(1, 9) var beast_id: int = 1:
	set(value):
		beast_id = value
		update_fragment_appearance()

var beast_data = {
	1: {"name": "Shukaku", "item": "Sandy Artifact", "color": Color(0.85, 0.75, 0.55), "text": "* You picked up a strange, sandy artifact pulsating with desert energy."},
	2: {"name": "Matatabi", "item": "Ghostly Ember", "color": Color(0.1, 0.4, 1.0), "text": "* You picked up a ghostly blue ember that burns cold to the touch."},
	3: {"name": "Isobu", "item": "Coral Fragment", "color": Color(0.2, 0.7, 0.6), "text": "* You picked up a rough coral fragment dripping with dense, misty moisture."},
	4: {"name": "Son Goku", "item": "Volcanic Stone", "color": Color(0.9, 0.2, 0.1), "text": "* You picked up a scorched volcanic stone radiating intense heat."},
	5: {"name": "Kokuo", "item": "White Horn", "color": Color(0.9, 0.9, 0.9), "text": "* You picked up a pure white horn fragment that smells of boiling steam."},
	6: {"name": "Saiken", "item": "Bubble Shard", "color": Color(0.6, 0.3, 0.8), "text": "* You picked up a sticky bubble shard humming with chemical energy."},
	7: {"name": "Chomei", "item": "Beetle Wing", "color": Color(0.4, 0.9, 0.3), "text": "* You picked up an armored beetle wing that vibrates violently."},
	8: {"name": "Gyuki", "item": "Ink-Stained Barb", "color": Color(0.3, 0.1, 0.4), "text": "* You picked up a dark ink-stained barb crackling with raw power."},
	9: {"name": "Kurama", "item": "Fiery Tuft", "color": Color(1.0, 0.3, 0.0), "text": "* You picked up a burning tuft overflowing with malice."}
}

func _ready():
	update_fragment_appearance()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func update_fragment_appearance():
	if not is_inside_tree(): return
	if not has_node("CSGPolygon3D") or not has_node("OmniLight3D"): return
	
	var data = beast_data.get(beast_id, beast_data[1])
	var target_color = data["color"]
	var mat = $CSGPolygon3D.material
	if mat is StandardMaterial3D:
		mat.albedo_color = target_color
		mat.albedo_color.a = 0.6 
		mat.emission = target_color
	$OmniLight3D.light_color = target_color

func _on_body_entered(body):
	if Engine.is_editor_hint(): return
	
	if body is CharacterBody3D and body.is_multiplayer_authority():
		if not GlobalData.is_admin:
			if GlobalData.has_fragment or GlobalData.has_beast:
				return 
				
		var data = beast_data.get(beast_id, beast_data[1])
		GlobalData.has_fragment = true
		GlobalData.current_fragment_id = beast_id
		GlobalData.save_data() 
		
		if body.has_method("show_artifact_menu"):
			body.show_artifact_menu(data["text"], data["color"])
		queue_free()

func _process(delta):
	if not Engine.is_editor_hint() and has_node("CSGPolygon3D"):
		$CSGPolygon3D.rotate_y(delta * 1.5)
		$CSGPolygon3D.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.15
