@tool
class_name EnvSkyScene
extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var targetname: String = ""
@export var enabled: bool = true
@export_file("*.tscn") var sky_scene: String = ""
@export var load_on_ready: bool = true
@export var follow_camera: bool = true
@export var position_offset: Vector3 = Vector3.ZERO
@export var copy_camera_rotation: bool = false
@export var rotation_speed_deg: Vector3 = Vector3.ZERO

const ALLOWED_SKY_SCENE_ROOTS: Array[String] = [
	"res://scenes/",
	"res://entities/",
	"res://tb/"
]

var _instance: Node3D = null
var _camera: Camera3D = null


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("sky_scene"):
		var mapped_scene := Util.sanitize_allowed_resource_path(String(props["sky_scene"]), ALLOWED_SKY_SCENE_ROOTS, ".tscn")
		if mapped_scene.is_empty():
			push_warning("env_sky_scene '%s' rejected sky_scene outside allowlist: %s" % [name, String(props["sky_scene"])])
		sky_scene = mapped_scene
	if props.has("load_on_ready"):
		load_on_ready = Util.to_bool(props["load_on_ready"], load_on_ready)
	if props.has("follow_camera"):
		follow_camera = Util.to_bool(props["follow_camera"], follow_camera)
	if props.has("position_offset"):
		var off: Variant = props["position_offset"]
		if off is Vector3:
			position_offset = off
	if props.has("copy_camera_rotation"):
		copy_camera_rotation = Util.to_bool(props["copy_camera_rotation"], copy_camera_rotation)
	if props.has("rotation_speed_deg"):
		var rot: Variant = props["rotation_speed_deg"]
		if rot is Vector3:
			rotation_speed_deg = rot


func _ready() -> void:
	if Util.editor_hint():
		return
	if not targetname.is_empty():
		GAME.set_targetname(self, targetname)
	if enabled and load_on_ready:
		load_sky_scene()
	set_process(true)


func _process(delta: float) -> void:
	if not enabled or _instance == null:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if follow_camera and _camera != null:
		_instance.global_position = _camera.global_position + position_offset
		if copy_camera_rotation:
			_instance.global_rotation = _camera.global_rotation
	if rotation_speed_deg != Vector3.ZERO:
		_instance.rotate_x(deg_to_rad(rotation_speed_deg.x * delta))
		_instance.rotate_y(deg_to_rad(rotation_speed_deg.y * delta))
		_instance.rotate_z(deg_to_rad(rotation_speed_deg.z * delta))


func use() -> void:
	load_sky_scene()


func trigger() -> void:
	load_sky_scene()


func clear_sky_scene() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null


func load_sky_scene() -> void:
	if not enabled:
		return
	if sky_scene.is_empty():
		push_warning("env_sky_scene '%s' missing sky_scene path" % name)
		return
	var safe_scene := Util.sanitize_allowed_resource_path(sky_scene, ALLOWED_SKY_SCENE_ROOTS, ".tscn")
	if safe_scene.is_empty():
		push_warning("env_sky_scene '%s' rejected sky_scene outside allowlist: %s" % [name, sky_scene])
		return
	var packed_v: Variant = load(safe_scene)
	if not (packed_v is PackedScene):
		push_warning("env_sky_scene '%s' could not load PackedScene at %s" % [name, safe_scene])
		return
	clear_sky_scene()
	var inst: Node = (packed_v as PackedScene).instantiate()
	if not (inst is Node3D):
		push_warning("env_sky_scene '%s' sky scene root must inherit Node3D" % name)
		if inst != null:
			inst.free()
		return
	_instance = inst as Node3D
	add_child(_instance)
	_instance.transform = Transform3D.IDENTITY
