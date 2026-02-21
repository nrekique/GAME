extends SceneTree

const NPC_SCENE := "res://entities/actors/npc/npc.tscn"
const OBJ_PATH := "res://tb/models/npc.obj"
const MTL_PATH := "res://tb/models/npc.mtl"
const TEX_SRC := "res://entities/actors/marsfrog/marsfrog_alb.png"
const TEX_DST := "res://tb/models/npc_diffuse.png"
const SCALE := 128.0
const YAW_DEGREES := 180.0
const HEIGHT_OFFSET := -96.0

func _init() -> void:
	var packed: PackedScene = load(NPC_SCENE)
	if packed == null:
		push_error("Failed to load NPC scene: %s" % NPC_SCENE)
		quit(1)
		return

	var root := packed.instantiate()
	var mesh_node := root.find_child("mesh", true, false)
	if mesh_node == null or not (mesh_node is MeshInstance3D):
		push_error("Could not find MeshInstance3D named 'mesh' in NPC scene.")
		quit(1)
		return

	var mi := mesh_node as MeshInstance3D
	var mesh := mi.mesh
	if mesh == null:
		push_error("NPC mesh node has no mesh.")
		quit(1)
		return

	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if vertices.is_empty():
		push_error("NPC mesh has no vertices.")
		quit(1)
		return

	var min_y := INF
	for v in vertices:
		if v.y < min_y:
			min_y = v.y

	var obj_lines := PackedStringArray()
	obj_lines.append("mtllib npc.mtl")
	obj_lines.append("o npc_mesh")

	for v in vertices:
		var p := Vector3(v.x, v.y - min_y, v.z) * SCALE
		p = p.rotated(Vector3.UP, deg_to_rad(YAW_DEGREES))
		p.y += HEIGHT_OFFSET
		var ox := p.x
		var oy := p.y
		var oz := p.z
		obj_lines.append("v %f %f %f" % [ox, oy, oz])

	for uv in uvs:
		obj_lines.append("vt %f %f" % [uv.x, 1.0 - uv.y])

	for n in normals:
		var nn := Vector3(n.x, n.y, n.z).rotated(Vector3.UP, deg_to_rad(YAW_DEGREES))
		obj_lines.append("vn %f %f %f" % [nn.x, nn.y, nn.z])

	obj_lines.append("usemtl npc_mat")

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

	var mtl := "newmtl npc_mat\nKa 1.000 1.000 1.000\nKd 1.000 1.000 1.000\nKs 0.000 0.000 0.000\nd 1.0\nillum 1\nmap_Kd npc_diffuse.png\n"
	var mtl_file := FileAccess.open(MTL_PATH, FileAccess.WRITE)
	if mtl_file == null:
		push_error("Failed to write MTL: %s" % MTL_PATH)
		quit(1)
		return
	mtl_file.store_string(mtl)
	mtl_file.close()

	var dir := DirAccess.open("res://")
	if dir == null:
		push_error("Failed to open res:// for texture copy.")
		quit(1)
		return
	var copy_err := dir.copy(TEX_SRC, TEX_DST)
	if copy_err != OK:
		push_error("Failed copying diffuse texture to tb/models: %s" % copy_err)
		quit(1)
		return

	print("Exported real NPC OBJ to ", OBJ_PATH)
	quit(0)
