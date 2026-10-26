extends Area3D

var float_tween: Tween

func _ready():
	# 1. BUILD THE BOTTLE AUTOMATICALLY
	var mesh_inst = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.15
	cylinder.height = 0.4
	mesh_inst.mesh = cylinder
	
	# 2. ALMOND COLOR MATERIAL
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.7, 0.5) 
	mat.roughness = 0.2 # Makes it look like shiny glass/plastic
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	
	# 3. BUILD THE HITBOX
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 0.6
	collision.shape = shape
	add_child(collision)
	
	body_entered.connect(_on_body_entered)
	
	# 4. CLASSIC VIDEO GAME FLOATING ANIMATION
	float_tween = create_tween().set_loops()
	float_tween.tween_property(mesh_inst, "position:y", 0.2, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	float_tween.tween_property(mesh_inst, "position:y", -0.2, 1.0).as_relative().set_trans(Tween.TRANS_SINE)

func _process(delta):
	rotation_degrees.y += 45.0 * delta # Spin constantly

func _on_body_entered(body):
	# If the player touches it
	if body.name == "player" or body.has_method("_btn_car"):
		# Check if the player script has a sanity variable yet
		if "sanity" in body:
			body.sanity += 30.0
			if body.sanity > 100.0:
				body.sanity = 100.0
		
		# Delete the bottle
		queue_free()
