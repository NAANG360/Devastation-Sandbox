extends StaticBody3D

var health: float = 3000.0 # Takes a few C4s or a massive attack
var is_broken: bool = false
@onready var my_mesh: MeshInstance3D = get_parent()

func take_damage(amount: float):
	if is_broken: return
	health -= amount
	if health <= 0:
		is_broken = true
		_shatter()

func TakeDamage(amount: float):
	take_damage(amount)

func _shatter():
	if not is_instance_valid(my_mesh): return

	# 1. Steal the texture/color from the building
	var mat = null
	if my_mesh.mesh and my_mesh.mesh.get_surface_count() > 0:
		mat = my_mesh.mesh.surface_get_material(0)
	if not mat and my_mesh.get_active_material(0):
		mat = my_mesh.get_active_material(0)

	var aabb = my_mesh.mesh.get_aabb()
	var global_center = my_mesh.to_global(aabb.get_center())

	# 2. Spawn 4 chunks of debris
	for i in range(4):
		var chunk = RigidBody3D.new()
		chunk.mass = 20.0
		
		var chunk_mesh = CSGBox3D.new()
		chunk_mesh.size = aabb.size / 2.0 # Make chunks 1/4th the size of the building
		if mat: chunk_mesh.material = mat
		
		var coll = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = chunk_mesh.size
		coll.shape = shape
		
		chunk.add_child(chunk_mesh)
		chunk.add_child(coll)
		
		get_tree().current_scene.add_child(chunk)
		
		# Explode them outward
		chunk.global_position = global_center + Vector3(randf_range(-1,1), randf_range(0, 2), randf_range(-1,1))
		chunk.apply_central_impulse(Vector3(randf_range(-10, 10), randf_range(10, 25), randf_range(-10, 10)) * chunk.mass)
		
		# Auto-delete debris after 5 seconds so the phone doesn't lag
		get_tree().create_timer(5.0).timeout.connect(chunk.queue_free)

	# 3. Delete the original building
	my_mesh.queue_free()
