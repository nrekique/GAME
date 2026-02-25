@tool
class_name EnvReflectionProbe
extends ReflectionProbe
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export var box_size: Vector3 = Vector3(8.0, 8.0, 8.0)
@export var update_mode_key: String = "once"
@export var probe_intensity: float = 1.0
@export var probe_cull_mask: int = 1048575

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("box_size"):
		box_size = _to_vec3(props["box_size"], box_size)
	if props.has("probe_intensity"):
		probe_intensity = maxf(float(props["probe_intensity"]), 0.0)
	if props.has("probe_cull_mask"):
		probe_cull_mask = int(props["probe_cull_mask"])
	if props.has("update_mode"):
		update_mode_key = String(props["update_mode"]).strip_edges().to_lower()
	_apply_settings()

func _ready() -> void:
	if Util.editor_hint():
		_apply_settings()
		return
	_apply_settings()

func _apply_settings() -> void:
	visible = enabled
	size = box_size
	intensity = probe_intensity
	cull_mask = probe_cull_mask
	match update_mode_key:
		"always", "realtime", "dynamic":
			update_mode = ReflectionProbe.UPDATE_ALWAYS
		_, "once", "baked":
			update_mode = ReflectionProbe.UPDATE_ONCE

func _to_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value as Vector3
	var parts := String(value).replace(",", " ").split_floats(" ")
	if parts.size() < 3:
		return fallback
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
