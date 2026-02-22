@tool
class_name ItemAmmo
extends Area3D
const Util := preload("res://scripts/util.gd")

@export var ammo_type: String = "bullets"
@export var amount: int = 10
@export var auto_free: bool = true
@export var targetname: String = ""

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("ammo_type"):
		ammo_type = props["ammo_type"] as String
	if props.has("amount"):
		amount = props["amount"] as int
	if props.has("targetname"):
		targetname = props["targetname"] as String

func _init() -> void:
	monitoring = true
	monitorable = false
	connect("body_entered", _on_body_entered)

func _ready() -> void:
	if Util.editor_hint():
		return
	_ensure_default_children()
	if targetname != "":
		GAME.set_targetname(self, targetname)

func _ensure_default_children() -> void:
	var has_shape := false
	for ch in get_children():
		if ch is CollisionShape3D:
			has_shape = true
			break
	if not has_shape:
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.5, 0.4, 0.3)
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
		mesh.size = Vector3(0.5, 0.4, 0.3)
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.4, 0.9, 1)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.2, 0.6, 1)
		mi.material_override = mat
		add_child(mi)

func _on_body_entered(body: Node) -> void:
	if Util.editor_hint():
		return
	if body != null and body.is_in_group("PLAYER"):
		var applied := false
		if body.has_method("add_ammo"):
			body.call("add_ammo", ammo_type, amount)
			applied = true
		elif GAME and GAME.has_method("add_ammo"):
			GAME.call("add_ammo", ammo_type, amount)
			applied = true
		if applied and auto_free:
			queue_free()