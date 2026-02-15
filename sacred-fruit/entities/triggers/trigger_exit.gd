@tool
class_name TriggerExit
extends Area3D

@export var targetname: String = ""
@export var map_path: String = ""
@export var delay: float = 0.0
@export var show_volume: bool = true
@export var one_shot: bool = true

var _fired: bool = false

const EXIT_VFX: PackedScene = preload("res://scenes/vfx/exit_burst.tscn")

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = props["targetname"] as String
	if props.has("map"):
		map_path = props["map"] as String
	elif props.has("map_path"):
		map_path = props["map_path"] as String
	elif props.has("scene"):
		map_path = props["scene"] as String
	elif props.has("next_scene"):
		map_path = props["next_scene"] as String
	if props.has("delay"):
		# TrenchBroom values often arrive as strings.
		delay = float(props["delay"])
	if props.has("show_volume"):
		show_volume = bool(props["show_volume"])
	if props.has("one_shot"):
		one_shot = bool(props["one_shot"])


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
	if one_shot and _fired:
		return
	if body != null and body.is_in_group("PLAYER"):
		_fired = true
		if one_shot:
			# Prevent re-triggering on subsequent overlap events.
			set_deferred("monitoring", false)
		_spawn_exit_vfx()
		var ok := GAME.try_exit()
		if ok and map_path != "":
			if delay > 0.0:
				await get_tree().create_timer(delay).timeout
			get_tree().change_scene_to_file(map_path)


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
			var shape_aabb: AABB = ch.shape.get_aabb()
			shape_aabb.position += ch.position
			if not has_any:
				aabb = shape_aabb
				has_any = true
			else:
				aabb = aabb.merge(shape_aabb)
	return aabb if has_any else AABB()
