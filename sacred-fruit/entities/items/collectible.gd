@tool
class_name Collectible
extends Area3D
const Util := preload("res://scripts/util.gd")

@export var value: int = 1
@export var auto_free: bool = true
@export var targetname: String = ""

const COLLECT_VFX: PackedScene = preload("res://scenes/vfx/collect_burst.tscn")

# Optional: allow func_godot to set properties from a map file
func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("value"):
		value = props["value"] as int
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
	# When spawned via FuncGodot FGD point class, this node will not have children.
	# Create a simple collision + visible mesh so it works out of the box.
	var has_shape := false
	for ch in get_children():
		if ch is CollisionShape3D:
			has_shape = true
			break
	if not has_shape:
		var shape := SphereShape3D.new()
		shape.radius = 0.35
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
		var mesh := SphereMesh.new()
		mesh.radius = 0.25
		mesh.height = 0.5
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.2, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(0.6, 0.1, 0.2)
		mi.material_override = mat
		add_child(mi)


func _on_body_entered(body: Node) -> void:
	if Util.editor_hint():
		return
	if body != null and body.is_in_group("PLAYER"):
		_spawn_collect_vfx()
		GAME.collect(value)
		if auto_free:
			queue_free()


func _spawn_collect_vfx() -> void:
	if COLLECT_VFX == null:
		return
	var vfx := COLLECT_VFX.instantiate()
	var parent := get_parent()
	if parent != null:
		parent.add_child(vfx)
	else:
		get_tree().current_scene.add_child(vfx)
	if vfx is Node3D:
		vfx.global_transform = global_transform