@tool
class_name TriggerExit
extends Area3D

@export var targetname: String = ""
@export var show_volume: bool = true

const EXIT_VFX: PackedScene = preload("res://scenes/vfx/exit_burst.tscn")

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = props["targetname"] as String


func _init() -> void:
	monitoring = true
	monitorable = false
	connect("body_entered", _on_body_entered)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if show_volume:
		_ensure_debug_volume()
	if targetname != "":
		GAME.set_targetname(self, targetname)


func _on_body_entered(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if body != null and body.is_in_group("PLAYER"):
		_spawn_exit_vfx()
		GAME.try_exit()


func _spawn_exit_vfx() -> void:
	if EXIT_VFX == null:
		return
	var vfx := EXIT_VFX.instantiate()
	var parent := get_parent()
	if parent != null:
		parent.add_child(vfx)
	else:
		get_tree().current_scene.add_child(vfx)
	if vfx is Node3D:
		vfx.global_transform = global_transform


func _ensure_debug_volume() -> void:
	# If map-generated visuals exist (brush meshes), don't add another.
	for ch in get_children():
		if ch is MeshInstance3D:
			return

	var aabb := _get_collision_aabb()
	if aabb.size == Vector3.ZERO:
		return

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = aabb.size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.9, 0.35, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 0.3, 1)
	mi.material_override = mat
	add_child(mi)
	mi.position = aabb.position + aabb.size * 0.5


func _get_collision_aabb() -> AABB:
	var aabb := AABB()
	var has_any := false
	for ch in get_children():
		if ch is CollisionShape3D and ch.shape != null:
			var shape_aabb := ch.shape.get_aabb()
			shape_aabb.position += ch.position
			if not has_any:
				aabb = shape_aabb
				has_any = true
			else:
				aabb = aabb.merge(shape_aabb)
	return aabb if has_any else AABB()
