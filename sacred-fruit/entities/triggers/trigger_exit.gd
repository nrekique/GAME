@tool
class_name TriggerExit
extends Area3D
const Util := preload("res://scripts/core/util.gd")

@export var targetname: String = ""
@export var map_path: String = ""
@export var delay: float = 0.0
@export var show_volume: bool = true
@export var one_shot: bool = true

const ALLOWED_SCENE_ROOTS: Array[String] = [
	"res://scenes/",
	"res://tb/",
	"res://entities/"
]

var _fired: bool = false

const EXIT_VFX: PackedScene = preload("res://scenes/vfx/exit_burst.tscn")


static func _parse_bool(value: Variant, default_value: bool = false) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var s := (value as String).strip_edges().to_lower()
			if s in ["1", "true", "yes", "y", "on"]:
				return true
			if s in ["0", "false", "no", "n", "off", ""]:
				return false
			return default_value
		_:
			return default_value

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = props["targetname"] as String
	if props.has("map"):
		map_path = Util.sanitize_allowed_resource_path(String(props["map"]), ALLOWED_SCENE_ROOTS, ".tscn")
	elif props.has("map_path"):
		map_path = Util.sanitize_allowed_resource_path(String(props["map_path"]), ALLOWED_SCENE_ROOTS, ".tscn")
	elif props.has("scene"):
		map_path = Util.sanitize_allowed_resource_path(String(props["scene"]), ALLOWED_SCENE_ROOTS, ".tscn")
	elif props.has("next_scene"):
		map_path = Util.sanitize_allowed_resource_path(String(props["next_scene"]), ALLOWED_SCENE_ROOTS, ".tscn")
	if props.has("delay"):
		# TrenchBroom values often arrive as strings.
		delay = float(props["delay"])
	if props.has("show_volume"):
		show_volume = _parse_bool(props["show_volume"], show_volume)
	if props.has("one_shot"):
		one_shot = _parse_bool(props["one_shot"], one_shot)
	if (props.has("map") or props.has("map_path") or props.has("scene") or props.has("next_scene")) and map_path.is_empty():
		push_warning("trigger_exit '%s' rejected map_path outside allowlist" % name)


func _init() -> void:
	monitoring = true
	monitorable = false
	connect("body_entered", _on_body_entered)


func _ready() -> void:
	if Util.editor_hint():
		return
	if show_volume:
		_ensure_debug_volume()
	if targetname != "":
		GAME.set_targetname(self, targetname)


func _on_body_entered(body: Node) -> void:
	if Util.editor_hint():
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
		var safe_scene := Util.sanitize_allowed_resource_path(map_path, ALLOWED_SCENE_ROOTS, ".tscn")
		if ok and safe_scene != "":
			if delay > 0.0:
				await get_tree().create_timer(delay).timeout
			get_tree().change_scene_to_file(safe_scene)


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
