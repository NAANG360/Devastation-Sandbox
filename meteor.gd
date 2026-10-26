extends RigidBody3D

@onready var impact_zone = $ImpactZone
var has_impacted = false

func _ready():
	body_entered.connect(_on_impact)

func _on_impact(body):
	if has_impacted: return
	has_impacted = true
	
	# The moment it touches the ground, tell everyone to explode!
	rpc("rpc_meteor_explosion")

@rpc("any_peer", "call_local")
func rpc_meteor_explosion():
	# 1. Screen Shake for everyone!
	var cam = get_viewport().get_camera_3d()
	if cam:
		var shake = create_tween()
		shake.tween_property(cam, "v_offset", 2.0, 0.05)
		shake.tween_property(cam, "v_offset", -2.0, 0.05)
		shake.tween_property(cam, "v_offset", 0.0, 0.05)

	# 2. Obliterate everything in the 150m radius
	var victims = impact_zone.get_overlapping_bodies()
	for victim in victims:
		if victim == self: continue
		
		var blast_dir = (victim.global_position - global_position).normalized()
		blast_dir.y += 0.8 # Launch things straight up
		
		if victim.has_method("take_damage"): victim.take_damage(5000.0)
		
		if victim is CharacterBody3D: 
			victim.global_position += (blast_dir * 150.0 * 0.016)
		elif victim is RigidBody3D or victim is VehicleBody3D: 
			victim.apply_central_impulse(blast_dir * 500.0 * victim.mass)
			
	# Fade out the giant rock
	await get_tree().create_timer(3.0).timeout
	queue_free()
