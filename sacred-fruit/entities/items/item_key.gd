@tool
class_name ItemKey
extends Area3D
const Util := preload("res://scripts/core/util.gd")

@export var key_id: String = "blue"
@export var auto_free: bool = true
@export var targetname: String = ""


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("key_id"):
		key_id = String(props["key_id"])
	if props.has("auto_free"):
		auto_free = Util.to_bool(props["auto_free"], auto_free)
	if props.has("targetname"):
		targetname = String(props["targetname"])


func _init() -> void:
	monitoring = true
	monitorable = false
	connect("body_entered", _on_body_entered)


func _ready() -> void:
	if Util.editor_hint():
		return
	_ensure_default_children()
	if targetname != "":
		var game := get_node_or_null("/root/GAME")
		if game != null and game.has_method("set_targetname"):
			game.call("set_targetname", self, targetname)


func _ensure_default_children() -> void:
	var has_shape := false
	for ch in get_children():
		if ch is CollisionShape3D:
			has_shape = true
			break
	if not has_shape:
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.35, 0.35, 0.12)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		add_child(cs)

	var has_mesh := false
	for ch in get_children():
		if ch is MeshInstance3D:
			has_mesh = true
			break
	if not has_mesh:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.35, 0.35, 0.12)
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.82, 0.22, 1.0)
		mat.metallic = 0.8
		mat.roughness = 0.2
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.24, 0.04, 1.0)
		mi.material_override = mat
		add_child(mi)


func _on_body_entered(body: Node) -> void:
	if Util.editor_hint():
		return
	if body == null or not body.is_in_group("PLAYER"):
		return
	var game := get_node_or_null("/root/GAME")
	if game != null and game.has_method("give_key"):
		game.call("give_key", key_id)
	if auto_free:
		queue_free()
