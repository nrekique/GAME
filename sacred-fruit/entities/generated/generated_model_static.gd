@tool
extends StaticBody3D

@export var model_scene: PackedScene
@export var collision_from_model_aabb: bool = true
@export var collision_size: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var collision_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_rebuild_children()


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("classname"):
		add_to_group(String(props["classname"]))
	if props.has("targetname"):
		var targetname := String(props["targetname"])
		var game := get_node_or_null("/root/GAME")
		if not targetname.is_empty() and game != null and game.has_method("set_targetname"):
			game.call("set_targetname", self, targetname)
	if props.has("scale"):
		var scale_value := _parse_uniform_scale(props["scale"], 1.0)
		scale = Vector3.ONE * scale_value
	_rebuild_children()


func _rebuild_children() -> void:
	_ensure_model_child()
	_ensure_collision_shape()


func _ensure_model_child() -> void:
	var existing := get_node_or_null("ModelRoot")
	if existing != null:
		return
	if model_scene == null:
		return
	var inst := model_scene.instantiate()
	if inst == null:
		return
	if inst is Node3D:
		var node := inst as Node3D
		node.name = "ModelRoot"
		add_child(node)
	else:
		inst.free()


func _ensure_collision_shape() -> void:
	var shape_node := get_node_or_null("AutoCollision") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "AutoCollision"
		add_child(shape_node)

	var box := BoxShape3D.new()
	var center := collision_offset
	var size_vec := collision_size

	if collision_from_model_aabb:
		var aabb := _compute_local_mesh_aabb()
		if aabb != null:
			size_vec = aabb.size
			center = aabb.position + (aabb.size * 0.5) + collision_offset

	size_vec.x = maxf(size_vec.x, 0.05)
	size_vec.y = maxf(size_vec.y, 0.05)
	size_vec.z = maxf(size_vec.z, 0.05)
	box.size = size_vec
	shape_node.shape = box
	shape_node.position = center


func _compute_local_mesh_aabb() -> AABB:
	var root := get_node_or_null("ModelRoot") as Node3D
	if root == null:
		return AABB(Vector3.ZERO, collision_size)

	var mins := Vector3(1000000.0, 1000000.0, 1000000.0)
	var maxs := Vector3(-1000000.0, -1000000.0, -1000000.0)
	var found := false

	var stack: Array[Node] = []
	stack.append(root)
	while stack.size() > 0:
		var node_variant: Variant = stack.pop_back()
		if not (node_variant is Node):
			continue
		var node := node_variant as Node
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh != null:
				var mesh_aabb := mesh_node.mesh.get_aabb()
				var corners := _aabb_corners(mesh_aabb)
				for c in corners:
					var p_global := mesh_node.global_transform * c
					var p_local := to_local(p_global)
					mins.x = minf(mins.x, p_local.x)
					mins.y = minf(mins.y, p_local.y)
					mins.z = minf(mins.z, p_local.z)
					maxs.x = maxf(maxs.x, p_local.x)
					maxs.y = maxf(maxs.y, p_local.y)
					maxs.z = maxf(maxs.z, p_local.z)
				found = true
		for child in node.get_children():
			if child is Node:
				stack.append(child as Node)

	if not found:
		return AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)

	return AABB(mins, maxs - mins)


func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p := aabb.position
	var s := aabb.size
	return [
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, s.y, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, s.y, 0.0),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(0.0, s.y, s.z),
		p + Vector3(s.x, s.y, s.z),
	]


func _parse_uniform_scale(value: Variant, fallback: float) -> float:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return maxf(float(value), 0.001)
		TYPE_STRING:
			var parts := String(value).split(" ", false)
			if parts.size() > 0:
				return maxf(parts[0].to_float(), 0.001)
	return fallback
