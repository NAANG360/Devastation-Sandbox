extends Node3D

@onready var p = get_parent()

var is_awakened = false
var is_true_dragon = false
var is_great_sage = false
var is_ciel_unleashed = false
var is_beelzebuth = false
var is_chakra_mode = false

var beelzebuth_timer = 0.0
var sage_attack_timer = 0.0
var sage_push_cooldown = 0.0
var sage_evade_cooldown = 0.0
var dragon_haki_timer = 0.0
var unleash_timer = 0.0
var beast_blast_cooldown = 0.0
var beast_special_cooldown = 0.0

var sage_last_target: Node3D = null
var ciel_aggro = false
var ciel_spam_timer = 0.0

var beelzebuth_aura: CSGSphere3D = null
var dragon_aura: CSGCombiner3D = null
var chakra_aura: CSGCombiner3D = null
var awakened_aura: Node3D = null

var active_chibaku_core: Node3D = null
var active_chibaku_area: Area3D = null

var sage_knowledge_base = {
	"amaterasu": {"aspect": "Black Fire", "color": Color.BLACK, "form": "Targeted Burn", "damage": 50.0, "fx": "burn"},
	"blades": {"aspect": "Holy Light", "color": Color(1.0, 0.8, 0.0), "form": "Rain", "damage": 100.0, "fx": "pierce"},
	"chibaku": {"aspect": "Gravity Core", "color": Color(0.1, 0.1, 0.1), "form": "Implosion", "damage": 2000.0, "fx": "pull"},
	"meteor": {"aspect": "Cosmic Rock", "color": Color(1.0, 0.4, 0.0), "form": "Giant Drop", "damage": 5000.0, "fx": "crush"},
	"push": {"aspect": "Repulsion", "color": Color(0.8, 0.9, 1.0, 0.2), "form": "Radial Blast", "damage": 75.0, "fx": "push"},
	"kamui": {"aspect": "Void Rift", "color": Color(0.2, 0.0, 0.5), "form": "Spatial Tear", "damage": 0.0, "fx": "banish"},
	"lightning": {"aspect": "Divine Thunder", "color": Color(0.0, 0.5, 1.0), "form": "Strike", "damage": 800.0, "fx": "stun"},
	"beam": {"aspect": "Pure Energy", "color": Color(0.0, 1.0, 0.8), "form": "Laser", "damage": 300.0, "fx": "pierce"},
	"tornado": {"aspect": "Tempest", "color": Color(0.5, 0.6, 0.6), "form": "Vortex", "damage": 150.0, "fx": "pull"},
	"beelzebuth": {"aspect": "Devouring Void", "color": Color(0.15, 0.0, 0.4), "form": "Aura", "damage": 400.0, "fx": "absorb"},
	"bomb": {"aspect": "Tailed Chakra", "color": Color(1.0, 0.2, 0.2), "form": "Nuke", "damage": 3000.0, "fx": "explode"},
	"susanoo": {"aspect": "Astral Energy", "color": Color(0.0, 0.4, 1.0), "form": "Armor", "damage": 0.0, "fx": "defend"},
	"genjutsu": {"aspect": "Illusion", "color": Color(0.8, 0.0, 0.8), "form": "Mind Break", "damage": 10.0, "fx": "stun"},
	"domain": {"aspect": "Reality Marble", "color": Color(0.3, 0.0, 0.0), "form": "Barrier", "damage": 500.0, "fx": "trap"}
}

func _enter_tree():
	set_multiplayer_authority(get_parent().name.to_int())

func trigger_counter():
	ciel_aggro = true
	ciel_spam_timer = 6.0 

func _physics_process(delta):
	if not is_multiplayer_authority() or p.is_dead: return

	beast_blast_cooldown -= delta
	beast_special_cooldown -= delta
	sage_push_cooldown -= delta
	sage_evade_cooldown -= delta

	_process_chibaku(delta)
	_process_true_dragon(delta)
	_process_beelzebuth(delta)
	_process_ciel_ai(delta)

func parse_chat(msg: String) -> bool:
	var lower_msg = msg.to_lower()
	var active_scene = get_tree().current_scene
	
	if "spatial movement" in lower_msg:
		if active_scene.has_method("rpc_receive_message"):
			active_scene.rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Executing Spatial Movement. »")
		rpc("rpc_spatial_movement")
		return true
	
	if p.is_admin and ("ciel" in lower_msg or "sage" in lower_msg):
		if not is_great_sage:
			p._toggle_autobattle()
			
		if "true dragon" in lower_msg or "liberate" in lower_msg or "liberation" in lower_msg:
			active_scene.rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Individual recognized. True Dragon Liberation authorized. »")
			rpc("rpc_true_dragon_liberation")
			return true
		if "barrier" in lower_msg or "shield" in lower_msg or "defense" in lower_msg:
			active_scene.rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Deploying Absolute Barrier. »")
			rpc("rpc_sage_barrier")
			return true
		if "report" in lower_msg or "status" in lower_msg:
			active_scene.rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Diagnostic complete. Host Vitality: " + str(p.current_health) + "%. »")
			return true
		if "purge" in lower_msg or "destroy" in lower_msg:
			active_scene.rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Executing Grand Purge. Deleting local hostiles. »")
			rpc("rpc_sage_purge")
			return true
		if "unleash" in lower_msg:
			active_scene.rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Unleashing full analytical bombardment. »")
			is_ciel_unleashed = true
			p.is_flying = true
			unleash_timer = 10.0
			p.global_position.y += 20.0
			return true
			
		var found_skills = []
		for skill in sage_knowledge_base.keys():
			if skill in lower_msg: found_skills.append(skill)
				
		if found_skills.size() >= 2:
			active_scene.rpc("rpc_receive_message", "Manas: Ciel", "« NOTICE: Synthesizing New Skill. »")
			rpc("rpc_cast_dynamic_hybrid", found_skills[0], found_skills[1])
			return true
		elif found_skills.size() == 1:
			active_scene.rpc("rpc_receive_message", "Manas: Ciel", "« ERROR: Skill synthesis requires at least 2 aspects. »")
			return true
		else:
			return true
	return false

@rpc("any_peer", "call_local")
func rpc_spatial_movement():
	if p.push_sound: p.push_sound.play()
	var active_scene = get_tree().current_scene
	if not active_scene: return
	
	var net_manager = active_scene.find_child("*Network*", true, false)
	var target_pos = Vector3.ZERO
	
	if is_instance_valid(net_manager) and "global_position" in net_manager:
		target_pos = net_manager.global_position
		
	var random_offset = Vector3(randf_range(-15.0, 15.0), 3.0, randf_range(-15.0, 15.0))
	target_pos += random_offset
	
	if p.has_method("rpc_force_teleport"):
		p.rpc("rpc_force_teleport", target_pos)
	else:
		p.global_position = target_pos

# ==========================================
# ADMIN BUTTON ABILITIES (AWAKENED ONLY)
# ==========================================

@rpc("any_peer", "call_local")
func rpc_final_jarona():
	if not is_awakened: return
	if p.push_sound: p.push_sound.play()
	
	# Phase 1: Charge Up (Flowery Gathering Power)
	var charge = CSGSphere3D.new()
	charge.radius = 4.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	charge.material = mat
	add_child(charge)
	charge.global_position = p.global_position + Vector3(0, 1, 0)
	
	var t = create_tween()
	t.tween_property(charge, "scale", Vector3(0.2, 0.2, 0.2), 0.5).set_trans(Tween.TRANS_SINE)
	await t.finished
	if is_instance_valid(charge): charge.queue_free()
	
	# Get Forward Dash Direction
	var dash_dir = -p.global_transform.basis.z.normalized()
	if p.get("cam") != null and is_instance_valid(p.cam):
		dash_dir = -p.cam.global_transform.basis.z.normalized()
		dash_dir.y = 0
		dash_dir = dash_dir.normalized()
		if dash_dir.length() < 0.1: dash_dir = -p.global_transform.basis.z.normalized()

	# Phase 2: Rapid Dash & Multi-Hit (Hits many times, 999 dmg each)
	for i in range(12): 
		if not is_instance_valid(p): break
		
		# Propel player forward
		p.global_position += dash_dir * 5.0 
		
		# Deal EXACTLY 999 damage to anything in the immediate dash path
		_apply_procedural_fx(p.global_position, 8.0, 999.0, "explode")
		
		# Visual Impact Flash along the dash
		var blast = CSGSphere3D.new()
		blast.radius = 5.0
		var b_mat = StandardMaterial3D.new()
		b_mat.albedo_color = Color(1.0, 0.0, 0.0, 0.6)
		b_mat.emission_enabled = true
		b_mat.emission = Color(1.0, 1.0, 0.0)
		b_mat.emission_energy_multiplier = 2.0
		b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		blast.material = b_mat
		get_parent().get_parent().add_child(blast)
		blast.global_position = p.global_position + Vector3(0, 1, 0)
		
		var bt = create_tween()
		bt.tween_property(b_mat, "albedo_color:a", 0.0, 0.15)
		bt.tween_callback(blast.queue_free)
		
		await get_tree().create_timer(0.05).timeout

@rpc("any_peer", "call_local")
func rpc_blingo_blizzard():
	if not is_awakened: return
	if p.push_sound: p.push_sound.play()
	var target_pos = _get_aim_target()
	
	# Friendliness Pellets + Trapping Vines Combo
	_execute_procedural_form("Rain", Color(1.0, 1.0, 0.8), "pierce", 500.0, target_pos)
	_execute_procedural_form("Vortex", Color(0.1, 0.8, 0.1), "pull", 300.0, target_pos)
	_execute_procedural_form("Trap", Color(0.0, 1.0, 0.0), "trap", 0.0, target_pos)

@rpc("any_peer", "call_local")
func rpc_true_dragon_liberation():
	is_true_dragon = true
	p.is_flying = true
	dragon_haki_timer = 0.5
	if is_instance_valid(dragon_aura): dragon_aura.queue_free()
	dragon_aura = CSGCombiner3D.new()
	var core = CSGSphere3D.new()
	core.radius = 2.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.material = mat
	dragon_aura.add_child(core)
	add_child(dragon_aura)
	dragon_aura.position = Vector3(0, 1.0, 0)
	await get_tree().create_timer(30.0).timeout
	is_true_dragon = false
	p.is_flying = false
	if is_instance_valid(dragon_aura): dragon_aura.queue_free()

@rpc("any_peer", "call_local")
func rpc_sage_barrier():
	_execute_procedural_form("Armor", Color(0.0, 0.8, 1.0), "defend", 0.0, p.global_position)

@rpc("any_peer", "call_local")
func rpc_sage_purge():
	_execute_procedural_form("Radial Blast", Color(1.0, 1.0, 1.0), "burn", 10000.0, p.global_position)

@rpc("any_peer", "call_local")
func rpc_beelzebuth():
	is_beelzebuth = true
	beelzebuth_timer = 10.0
	if is_instance_valid(beelzebuth_aura): beelzebuth_aura.queue_free()
	beelzebuth_aura = CSGSphere3D.new()
	beelzebuth_aura.radius = 15.0
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.0, 0.2, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.0, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beelzebuth_aura.material = mat
	add_child(beelzebuth_aura)

@rpc("any_peer", "call_local")
func rpc_almighty_push():
	if sage_push_cooldown > 0: return
	sage_push_cooldown = 5.0
	if p.push_sound: p.push_sound.play()
	_execute_procedural_form("Radial Blast", Color(0.8, 0.9, 1.0), "push", 75.0, p.global_position)

func _process_chibaku(delta):
	if is_instance_valid(active_chibaku_area) and is_instance_valid(active_chibaku_core):
		var center = active_chibaku_core.global_position
		for victim in active_chibaku_area.get_overlapping_bodies():
			if victim != p:
				if victim.has_method("rpc_pull_to_chibaku"): victim.rpc("rpc_pull_to_chibaku", center)
				elif victim is RigidBody3D or victim is VehicleBody3D:
					var pull_dir = (center - victim.global_position).normalized()
					if victim.global_position.distance_to(center) > 4.0: victim.linear_velocity = pull_dir * 300.0 
					else: victim.linear_velocity = Vector3.ZERO

func _process_true_dragon(delta):
	if is_true_dragon:
		dragon_haki_timer -= delta
		if dragon_haki_timer <= 0:
			dragon_haki_timer = 0.5
			_apply_procedural_fx(p.global_position, 30.0, 50.0, "burn")
			if p.push_zone:
				for v in p.push_zone.get_overlapping_bodies():
					if v != p and v is CharacterBody3D and not v.get("is_admin"):
						if v.has_method("rpc_trigger_ragdoll"):
							v.rpc("rpc_trigger_ragdoll", Vector3(0, -15.0, 0)) 
		if is_instance_valid(dragon_aura):
			dragon_aura.rotation_degrees.y += 45 * delta

func _process_beelzebuth(delta):
	if is_beelzebuth:
		beelzebuth_timer -= delta
		if is_instance_valid(beelzebuth_aura):
			beelzebuth_aura.rotation_degrees.y += 180 * delta
			var pulse = 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.1
			beelzebuth_aura.scale = Vector3(pulse, pulse, pulse)
		if p.push_zone:
			for victim in p.push_zone.get_overlapping_bodies():
				if victim != p and not victim is StaticBody3D:
					var pull_dir = (p.global_position - victim.global_position).normalized()
					var dist = p.global_position.distance_to(victim.global_position)
					if victim is CharacterBody3D: victim.global_position += pull_dir * 40.0 * delta
					elif victim is RigidBody3D or victim is VehicleBody3D: victim.apply_central_impulse(pull_dir * 250.0 * victim.mass * delta)
					if dist < 3.0:
						if victim.has_method("take_damage"): 
							victim.take_damage(9999.0)
							if p.has_method("rpc_add_crime_points"): p.rpc("rpc_add_crime_points", 1.0)
						p.current_health = min(p.current_health + 25.0, p.max_health)
						if p.health_bar: p.health_bar.value = p.current_health
		if beelzebuth_timer <= 0:
			is_beelzebuth = false
			if is_instance_valid(beelzebuth_aura): beelzebuth_aura.queue_free()

func _process_ciel_ai(delta):
	if is_ciel_unleashed:
		unleash_timer -= delta
		if is_instance_valid(p.player_model): p.player_model.rotation_degrees.y += 360 * delta
		sage_attack_timer -= delta
		if sage_attack_timer <= 0:
			sage_attack_timer = 0.2
			var aspects = sage_knowledge_base.keys()
			rpc("rpc_cast_dynamic_hybrid", aspects[randi() % aspects.size()], aspects[randi() % aspects.size()])
		if unleash_timer <= 0:
			is_ciel_unleashed = false
			p.is_flying = false

	elif is_great_sage and not is_ciel_unleashed:
		if p.current_health < p.max_health * 0.3:
			p.current_health = p.max_health
			if p.health_bar: p.health_bar.value = p.current_health
			get_tree().current_scene.rpc_id(multiplayer.get_unique_id(), "rpc_receive_message", "Manas: Ciel", "« NOTICE: Host vitality critical. Auto-Recovery executed. »")
		
		if ciel_aggro:
			ciel_spam_timer -= delta
			if ciel_spam_timer <= 0:
				ciel_aggro = false
				
		var target: Node3D = null
		var closest = 150.0
		for node in get_parent().get_parent().get_children():
			if node != p and (node is CharacterBody3D or "health" in node):
				if "is_dead" in node and node.is_dead: continue
				var d = p.global_position.distance_to(node.global_position)
				if d < closest:
					closest = d
					target = node

		if target:
			var aim_dir = (target.global_position - p.global_position)
			aim_dir.y = 0
			if aim_dir.length() > 0.1:
				var target_angle = atan2(-aim_dir.x, -aim_dir.z)
				if is_instance_valid(p.player_model):
					p.player_model.global_rotation.y = lerp_angle(p.player_model.global_rotation.y, target_angle, 25.0 * delta)
			
			if ciel_aggro:
				if closest > 15.0:
					p.velocity.x = aim_dir.normalized().x * (p.SPEED * 4.0)
					p.velocity.z = aim_dir.normalized().z * (p.SPEED * 4.0)
				else:
					p.velocity.x = move_toward(p.velocity.x, 0, p.SPEED)
					p.velocity.z = move_toward(p.velocity.z, 0, p.SPEED)
					
				sage_attack_timer -= delta
				if sage_attack_timer <= 0:
					sage_attack_timer = 0.15 
					var aspects = sage_knowledge_base.keys()
					var form = ["beam", "meteor", "blades", "tornado", "chibaku", "bomb"].pick_random() 
					rpc("rpc_cast_dynamic_hybrid", aspects[randi() % aspects.size()], form)
			else:
				if closest < 5.0 and sage_evade_cooldown <= 0:
					p.is_dashing = true
					p.dash_timer = 0.3
					p.dash_dir = -aim_dir.normalized()
					sage_evade_cooldown = 3.0
					if p.push_sound: p.push_sound.play()
				else:
					p.velocity.x = move_toward(p.velocity.x, 0, p.SPEED)
					p.velocity.z = move_toward(p.velocity.z, 0, p.SPEED)
		else:
			p.velocity.x = move_toward(p.velocity.x, 0, p.SPEED)
			p.velocity.z = move_toward(p.velocity.z, 0, p.SPEED)

func _get_beast_color(id: int) -> Color:
	var beast_colors = {
		1: Color(0.85, 0.75, 0.55), 2: Color(0.1, 0.4, 1.0), 3: Color(0.2, 0.7, 0.6),
		4: Color(0.9, 0.2, 0.1), 5: Color(0.9, 0.9, 0.9), 6: Color(0.6, 0.3, 0.8),
		7: Color(0.4, 0.9, 0.3), 8: Color(0.3, 0.1, 0.4), 9: Color(1.0, 0.3, 0.0)
	}
	return beast_colors.get(id, Color.RED)

@rpc("any_peer", "call_local")
func rpc_beast_special(beast_id: int):
	if beast_special_cooldown > 0: return
	beast_special_cooldown = 10.0
	if p.push_sound: p.push_sound.play()
	var c_color = _get_beast_color(beast_id)
	var target_pos = _get_aim_target()
	
	match beast_id:
		1: _execute_procedural_form("Trap", c_color, "trap", 50.0, target_pos) 
		2: _execute_procedural_form("Targeted Burn", c_color, "burn", 150.0, target_pos) 
		3: _execute_procedural_form("Radial Blast", c_color, "stun", 100.0, p.global_position) 
		4: _execute_procedural_form("Giant Drop", c_color, "burn", 300.0, target_pos) 
		5: _execute_procedural_form("Aura", c_color, "push", 50.0, p.global_position) 
		6: _execute_procedural_form("Rain", c_color, "burn", 200.0, target_pos) 
		7: _execute_procedural_form("Vortex", c_color, "stun", 100.0, target_pos) 
		8: _execute_procedural_form("Implosion", c_color, "pull", 150.0, target_pos) 
		9: _execute_procedural_form("Laser", c_color, "explode", 400.0, target_pos) 
		_: _execute_procedural_form("Radial Blast", c_color, "push", 100.0, p.global_position)

func _get_aim_target() -> Vector3:
	var forward_dir = -p.cam.global_transform.basis.z.normalized() if p.cam else -p.global_transform.basis.z.normalized()
	var hit_pos = p.global_position + (forward_dir * 100.0)
	if p.cam:
		var vp_center = get_viewport().get_visible_rect().size / 2.0
		var origin = p.cam.project_ray_origin(vp_center)
		var dir = p.cam.project_ray_normal(vp_center)
		var query = PhysicsRayQueryParameters3D.create(origin, origin + (dir * 200.0))
		query.exclude = [p.get_rid()] 
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		if result: hit_pos = result.position
		else: hit_pos = origin + (dir * 80.0)
	return hit_pos

@rpc("any_peer", "call_local")
func rpc_cast_dynamic_hybrid(base_id: String, form_id: String):
	if p.push_sound: p.push_sound.play()
	var aspect = sage_knowledge_base[base_id]
	var form = sage_knowledge_base[form_id]
	_execute_procedural_form(form["form"], aspect["color"], aspect["fx"], aspect["damage"], _get_aim_target())

func _execute_procedural_form(form_type: String, c_color: Color, c_fx: String, c_dmg: float, target_pos: Vector3):
	match form_type:
		"Aura":
			var aura = CSGSphere3D.new()
			aura.radius = 8.0 
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color 
			mat.emission_enabled = true
			mat.emission = c_color
			mat.emission_energy_multiplier = 2.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED 
			aura.material = mat
			add_child(aura)
			aura.global_position = p.global_position
			
			for i in range(8):
				await get_tree().create_timer(0.5).timeout
				if is_instance_valid(aura):
					aura.global_position = p.global_position
					_apply_procedural_fx(p.global_position, 8.0, c_dmg / 4.0, c_fx)
			if is_instance_valid(aura): aura.queue_free()
			
		"Nuke":
			var dist = p.global_position.distance_to(target_pos)
			var travel_time = clamp(dist / 80.0, 0.1, 1.5) 
			var proj = CSGSphere3D.new()
			proj.radius = 1.0
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color
			mat.emission_enabled = true
			mat.emission = c_color
			mat.emission_energy_multiplier = 4.0
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			proj.material = mat
			get_parent().get_parent().add_child(proj)
			proj.global_position = p.global_position + Vector3(0, 2.0, 0)
			
			var t = create_tween()
			t.tween_property(proj, "global_position", target_pos, travel_time).set_trans(Tween.TRANS_LINEAR)
			await t.finished
			
			if is_instance_valid(proj):
				var expand = create_tween().set_parallel(true)
				expand.tween_property(proj, "scale", Vector3(50.0, 50.0, 50.0), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
				_apply_procedural_fx(target_pos, 50.0, c_dmg, c_fx)
				await get_tree().create_timer(0.5).timeout
				if is_instance_valid(proj): proj.queue_free()

		"Armor":
			var armor = CSGCylinder3D.new()
			armor.radius = 4.0
			armor.height = 10.0
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color
			mat.emission_enabled = true
			mat.emission = c_color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.5
			armor.material = mat
			add_child(armor)
			armor.position = Vector3(0, 5, 0)
			p.current_health += 5000.0
			if p.health_bar: p.health_bar.value = p.current_health
			await get_tree().create_timer(10.0).timeout
			if is_instance_valid(armor): armor.queue_free()

		"Mind Break":
			_apply_procedural_fx(target_pos, 20.0, c_dmg, "stun")
			var dome = CSGSphere3D.new()
			dome.radius = 20.0
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color
			mat.emission_enabled = true
			mat.emission = c_color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.2
			dome.material = mat
			get_parent().get_parent().add_child(dome)
			dome.global_position = target_pos
			var t = create_tween()
			t.tween_property(mat, "albedo_color:a", 0.0, 3.0)
			t.tween_callback(dome.queue_free)

		"Barrier", "Trap":
			var b = CSGSphere3D.new()
			b.radius = 30.0 if form_type == "Barrier" else 15.0
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color
			mat.emission_enabled = true
			mat.emission = c_color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.3
			b.material = mat
			get_parent().get_parent().add_child(b)
			b.global_position = target_pos
			
			for i in range(10):
				await get_tree().create_timer(0.5).timeout
				if is_instance_valid(b):
					_apply_procedural_fx(target_pos, b.radius, c_dmg / 2.0, "trap")
					_apply_procedural_fx(target_pos, b.radius, c_dmg / 2.0, c_fx)
			if is_instance_valid(b): b.queue_free()

		"Strike":
			var strike = CSGCylinder3D.new()
			strike.radius = 2.0
			strike.height = 200.0
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color
			mat.emission_enabled = true
			mat.emission = c_color
			mat.emission_energy_multiplier = 6.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			strike.material = mat
			get_parent().get_parent().add_child(strike)
			strike.global_position = target_pos + Vector3(0, 100, 0)
			
			var t = create_tween()
			t.tween_property(mat, "albedo_color:a", 0.0, 0.5)
			t.tween_callback(strike.queue_free)
			_apply_procedural_fx(target_pos, 8.0, c_dmg, c_fx)
			
		"Laser":
			var beam = CSGCylinder3D.new()
			var dist = p.global_position.distance_to(target_pos)
			beam.radius = 1.0
			beam.height = dist
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color
			mat.emission_enabled = true
			mat.emission = c_color
			mat.emission_energy_multiplier = 5.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			beam.material = mat
			get_parent().get_parent().add_child(beam)
			
			var mid = p.global_position.lerp(target_pos, 0.5) + Vector3(0, 1.0, 0)
			beam.global_position = mid
			beam.look_at(target_pos)
			beam.rotate_x(deg_to_rad(90))
			
			var t = create_tween()
			t.tween_property(mat, "albedo_color:a", 0.0, 0.5)
			t.tween_callback(beam.queue_free)
			_apply_procedural_fx(target_pos, 5.0, c_dmg, c_fx)
			
		"Vortex":
			var tornado = CSGCylinder3D.new()
			tornado.radius = 10.0
			tornado.height = 30.0
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color
			mat.emission_enabled = true
			mat.emission = c_color
			mat.emission_energy_multiplier = 2.0
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.5
			tornado.material = mat
			get_parent().get_parent().add_child(tornado)
			tornado.global_position = target_pos + Vector3(0, 15.0, 0)
			
			var t = create_tween().set_parallel(true)
			t.tween_property(tornado, "rotation_degrees:y", 1800.0, 5.0)
			t.tween_property(tornado, "scale", Vector3(1.5, 1.5, 1.5), 5.0)
			t.chain().tween_property(mat, "albedo_color:a", 0.0, 1.0)
			t.chain().tween_callback(tornado.queue_free)
			
			for i in range(10):
				await get_tree().create_timer(0.5).timeout
				if is_instance_valid(tornado):
					_apply_procedural_fx(target_pos, 15.0, c_dmg / 5.0, "pull")
					_apply_procedural_fx(target_pos, 15.0, c_dmg / 5.0, c_fx)

		"Rain":
			for i in range(25):
				var proj = CSGBox3D.new()
				proj.size = Vector3(0.5, 0.5, 4.0)
				var mat = StandardMaterial3D.new()
				mat.albedo_color = c_color
				mat.emission_enabled = true
				mat.emission = c_color
				mat.emission_energy_multiplier = 4.0
				proj.material = mat
				get_parent().get_parent().add_child(proj)
				
				var spawn_point = target_pos + Vector3(randf_range(-15,15), randf_range(20, 35), randf_range(-15,15))
				proj.global_position = spawn_point
				proj.look_at(target_pos + Vector3(randf_range(-5,5), 0, randf_range(-5,5)))
				
				var t = create_tween()
				t.tween_interval(randf_range(0.1, 1.0))
				t.tween_property(proj, "global_position", target_pos + Vector3(randf_range(-8,8), 0, randf_range(-8,8)), 0.2)
				t.tween_callback(proj.queue_free)
				t.tween_callback(func(): _apply_procedural_fx(proj.global_position, 5.0, c_dmg, c_fx))

		"Radial Blast", "Targeted Burn", "Implosion", "Giant Drop":
			var blast = CSGSphere3D.new()
			blast.radius = 10.0 if form_type == "Targeted Burn" else 25.0
			var mat = StandardMaterial3D.new()
			mat.albedo_color = c_color
			mat.emission_enabled = true
			mat.emission = c_color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.5
			blast.material = mat
			get_parent().get_parent().add_child(blast)
			blast.global_position = target_pos
			
			var t = create_tween()
			t.tween_property(mat, "albedo_color:a", 0.0, 1.0)
			t.tween_callback(blast.queue_free)
			_apply_procedural_fx(target_pos, blast.radius, c_dmg, c_fx)

func _apply_procedural_fx(pos: Vector3, radius: float, damage: float, fx_type: String):
	var area = Area3D.new()
	var col = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	col.shape = sphere
	area.add_child(col)
	get_parent().get_parent().add_child(area)
	area.global_position = pos
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var victims = area.get_overlapping_bodies()
	for v in victims:
		if v != p and v is Node3D:
			var gave_points = false
			if v.has_method("take_damage"): 
				v.take_damage(damage)
				gave_points = true
			elif "health" in v: 
				v.health -= damage
				gave_points = true
			elif v.has_method("TakeDamage"): 
				v.TakeDamage(damage)
				gave_points = true
				
			if gave_points and p.has_method("rpc_add_crime_points"): 
				p.rpc("rpc_add_crime_points", 1.0)
			
			if fx_type == "push" or fx_type == "explode" or fx_type == "burn":
				var dir = (v.global_position - pos).normalized()
				dir.y += 0.5
				if v is CharacterBody3D: v.global_position += dir * 20.0 * get_physics_process_delta_time()
				elif v is RigidBody3D or v is VehicleBody3D: v.apply_central_impulse(dir * 500.0 * v.mass)
			elif fx_type == "pull":
				var dir = (pos - v.global_position).normalized()
				if v is CharacterBody3D: v.global_position += dir * 20.0 * get_physics_process_delta_time()
				elif v is RigidBody3D or v is VehicleBody3D: v.apply_central_impulse(dir * 500.0 * v.mass)
	area.queue_free()
