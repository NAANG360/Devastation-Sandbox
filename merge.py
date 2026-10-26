import trimesh

# 1. Load the GLB scene (make sure your map file is in the same folder)
print("Loading Sketchfab map...")
scene = trimesh.load('low_poly_city.glb', force='scene')

# 2. Dump the scene and apply all transforms, concatenating it into one mesh
print("Crushing 1000s of objects into one giant mesh...")
merged = scene.dump(concatenate=True)

# Note: Sometimes dump() returns a list if there are weird non-mesh objects
if isinstance(merged, list):
    merged = merged[0]

# 3. Export as a lightweight OBJ file
print("Exporting as map_collision.obj...")
merged.export('map_collision.obj')
print("Done! You now have a single collision map.")
