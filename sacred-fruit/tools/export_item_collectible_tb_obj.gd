extends SceneTree

const SCENE_PATH := "res://entities/items/collectible/collectible.tscn"
const OBJ_PATH := "res://tb/models/item_collectible.obj"
const MTL_PATH := "res://tb/models/item_collectible.mtl"
const TEX_PATH := "res://tb/models/item_collectible_diffuse.png"
const SCALE := 128.0

func _init() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("Failed to load collectible scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := packed.instantiate()
	var mesh_node := root.find_child("MeshInstance3D", true, false)
	if mesh_node == null or not (mesh_node is MeshInstance3D):
		push_error("Could not find MeshInstance3D in collectible scene.")
		quit(1)
		return

	var mi := mesh_node as MeshInstance3D
	var mesh := mi.mesh
	if mesh == null:
		push_error("Collectible mesh node has no mesh.")
		quit(1)
		return

	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		push_error("Collectible mesh has no vertices.")
		quit(1)
		return

	var obj_lines := PackedStringArray()
	obj_lines.append("mtllib item_collectible.mtl")
	obj_lines.append("o item_collectible_mesh")

	for v in vertices:
		var p := v * SCALE
		obj_lines.append("v %f %f %f" % [p.x, p.y, p.z])

	for uv in uvs:
		obj_lines.append("vt %f %f" % [uv.x, 1.0 - uv.y])

	for n in normals:
		obj_lines.append("vn %f %f %f" % [n.x, n.y, n.z])

	obj_lines.append("usemtl item_collectible_mat")
	if not indices.is_empty():
		for i in range(0, indices.size(), 3):
			var a := indices[i] + 1
			var b := indices[i + 1] + 1
			var c := indices[i + 2] + 1
			obj_lines.append("f %d/%d/%d %d/%d/%d %d/%d/%d" % [a, a, a, b, b, b, c, c, c])
	else:
		for i in range(0, vertices.size(), 3):
			var a := i + 1
			var b := i + 2
			var c := i + 3
			obj_lines.append("f %d/%d/%d %d/%d/%d %d/%d/%d" % [a, a, a, b, b, b, c, c, c])

	var obj_file := FileAccess.open(OBJ_PATH, FileAccess.WRITE)
	if obj_file == null:
		push_error("Failed to write OBJ: %s" % OBJ_PATH)
		quit(1)
		return
	obj_file.store_string("\n".join(obj_lines) + "\n")
	obj_file.close()

	var mtl := "newmtl item_collectible_mat\nKa 1.000 1.000 1.000\nKd 1.000 1.000 1.000\nKs 0.000 0.000 0.000\nd 1.0\nillum 1\nmap_Kd item_collectible_diffuse.png\n"
	var mtl_file := FileAccess.open(MTL_PATH, FileAccess.WRITE)
	if mtl_file == null:
		push_error("Failed to write MTL: %s" % MTL_PATH)
		quit(1)
		return
	mtl_file.store_string(mtl)
	mtl_file.close()

	var albedo := Color(0.95, 0.2, 0.35, 1.0)
	if mi.material_override is StandardMaterial3D:
		albedo = (mi.material_override as StandardMaterial3D).albedo_color

	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(albedo)
	var err := img.save_png(TEX_PATH)
	if err != OK:
		push_error("Failed to write diffuse texture PNG: %s" % err)
		quit(1)
		return

	print("Exported item collectible OBJ to ", OBJ_PATH)
	quit(0)
