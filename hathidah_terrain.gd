extends MeshInstance3D

# Changed from 60.0 to 12.0 for realistic, gentle slopes!
var height_multiplier = 12.0 

func _ready():
	var img_tex = load("res://height.png") # Make sure the name matches!
	if not img_tex:
		print("ERROR: Heightmap missing!")
		return
		
	var img = img_tex.get_image()
	var plane = mesh as PlaneMesh
	
	var st = SurfaceTool.new()
	st.create_from(plane, 0)
	var array_mesh = st.commit()
	
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)
	
	for i in range(mdt.get_vertex_count()):
		var v = mdt.get_vertex(i)
		var u = (v.x / plane.size.x) + 0.5
		var v_uv = (v.z / plane.size.y) + 0.5
		
		var img_x = clamp(int(u * img.get_width()), 0, img.get_width() - 1)
		var img_y = clamp(int(v_uv * img.get_height()), 0, img.get_height() - 1)
		
		# Read the black and white pixel to set the height
		var color = img.get_pixel(img_x, img_y)
		v.y = color.r * height_multiplier
		
		mdt.set_vertex(i, v)
		
	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)
	
	st.clear()
	st.create_from(array_mesh, 0)
	st.generate_normals()
	self.mesh = st.commit()
	
	# Generate solid collision so the Fortuner can drive on it
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	collision.shape = self.mesh.create_trimesh_shape()
	static_body.add_child(collision)
	add_child(static_body)
