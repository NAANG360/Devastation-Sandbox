extends Area3D

var beast_data = {
	1: {"name": "Shukaku", "item": "Sandy Artifact", "color": Color(0.85, 0.75, 0.55)},
	2: {"name": "Matatabi", "item": "Ghostly Ember", "color": Color(0.1, 0.4, 1.0)},
	3: {"name": "Isobu", "item": "Coral Fragment", "color": Color(0.2, 0.7, 0.6)},
	4: {"name": "Son Goku", "item": "Volcanic Stone", "color": Color(0.9, 0.2, 0.1)},
	5: {"name": "Kokuo", "item": "White Horn", "color": Color(0.9, 0.9, 0.9)},
	6: {"name": "Saiken", "item": "Bubble Shard", "color": Color(0.6, 0.3, 0.8)},
	7: {"name": "Chomei", "item": "Beetle Wing", "color": Color(0.4, 0.9, 0.3)},
	8: {"name": "Gyuki", "item": "Ink-Stained Barb", "color": Color(0.3, 0.1, 0.4)},
	9: {"name": "Kurama", "item": "Fiery Tuft", "color": Color(1.0, 0.3, 0.0)}
}

@onready var chakra_orb = $ChakraOrb
@onready var flame_particles = $ChakraOrb/FlameParticles
@onready var orb_light = $ChakraOrb/OmniLight3D

var is_ritual_active = false
var flame_material: StandardMaterial3D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	flame_material = StandardMaterial3D.new()
	flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	if flame_particles: 
		flame_particles.material_override = flame_material
		flame_particles.emitting = false 

func _on_body_entered(body):
	if is_ritual_active: return
	if body is CharacterBody3D and body.is_multiplayer_authority():
		if GlobalData.has_fragment and not GlobalData.has_beast:
			var data = beast_data.get(GlobalData.current_fragment_id, beast_data[1])
			if body.has_method("show_altar_menu"):
				body.show_altar_menu(data["item"], data["color"], self)
		elif GlobalData.has_beast:
			if body.has_method("show_artifact_menu"):
				body.show_artifact_menu("* Your body cannot handle another Tailed Beast.", Color.RED)

func _on_body_exited(body):
	if is_ritual_active: return 
	if body is CharacterBody3D and body.is_multiplayer_authority():
		if body.has_method("hide_travel_menu"):
			body.hide_travel_menu()

func start_ritual(player):
	is_ritual_active = true
	var b_id = GlobalData.current_fragment_id
	var data = beast_data.get(b_id, beast_data[1])
	var b_color = data["color"]
	var b_name = data["name"]
	
	flame_material.albedo_color = b_color
	if orb_light: orb_light.light_color = b_color
		
	chakra_orb.show()
	chakra_orb.scale = Vector3.ZERO
	chakra_orb.position.y = 1.0 
	if flame_particles: flame_particles.emitting = true
	
	var tween = create_tween()
	tween.tween_property(chakra_orb, "scale", Vector3(2.5, 2.5, 2.5), 2.0).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(chakra_orb, "position:y", 3.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(1.0)
	
	tween.tween_property(chakra_orb, "global_position", player.global_position + Vector3(0, 1.2, 0), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(chakra_orb, "scale", Vector3(0.1, 0.1, 0.1), 0.2)
	
	tween.tween_callback(func():
		chakra_orb.hide()
		if flame_particles: flame_particles.emitting = false
		
		GlobalData.has_fragment = false
		GlobalData.current_fragment_id = 0
		GlobalData.has_beast = true
		GlobalData.current_beast_id = b_id
		GlobalData.save_data() 
		
		if player.has_method("show_artifact_menu"):
			player.show_artifact_menu("* You have successfully bonded with " + b_name + "!", b_color)
			
		if player.cam:
			var shake = create_tween()
			shake.tween_property(player.cam, "v_offset", 0.5, 0.05)
			shake.tween_property(player.cam, "v_offset", -0.5, 0.05)
			shake.tween_property(player.cam, "v_offset", 0.0, 0.05)
			
		await get_tree().create_timer(5.0).timeout
		is_ritual_active = false
		chakra_orb.position = Vector3.ZERO
	)
