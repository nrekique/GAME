@tool
class_name EnvFogController
extends Node3D

# Authoring-only entity consumed by sandstorm_controller.gd map parsing.
@export var fog_enabled: bool = true
@export var volumetric_fog_enabled: bool = true
@export_range(0.0, 0.2, 0.001) var fog_density: float = 0.05
@export_range(0.0, 0.2, 0.001) var volumetric_fog_density: float = 0.04
@export var fog_color: Color = Color(0.78, 0.62, 0.36, 1.0)


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("fog_enabled"):
		fog_enabled = _to_bool(props["fog_enabled"], fog_enabled)
	elif props.has("enabled"):
		fog_enabled = _to_bool(props["enabled"], fog_enabled)
	if props.has("volumetric_fog_enabled"):
		volumetric_fog_enabled = _to_bool(props["volumetric_fog_enabled"], volumetric_fog_enabled)
	elif props.has("volumetric_enabled"):
		volumetric_fog_enabled = _to_bool(props["volumetric_enabled"], volumetric_fog_enabled)
	if props.has("fog_density"):
		fog_density = clampf(float(props["fog_density"]), 0.0, 0.2)
	if props.has("volumetric_fog_density"):
		volumetric_fog_density = clampf(float(props["volumetric_fog_density"]), 0.0, 0.2)
	if props.has("fog_color"):
		fog_color = _parse_color(props["fog_color"], fog_color)


func _to_bool(value: Variant, fallback: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var s: String = String(value).strip_edges().to_lower()
			if s in ["1", "true", "yes", "on", "y"]:
				return true
			if s in ["0", "false", "no", "off", "n", ""]:
				return false
			return fallback
		_:
			return fallback


func _parse_color(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	var parts := String(v).replace(",", " ").split_floats(" ")
	if parts.size() < 3:
		return fallback
	var r := parts[0]
	var g := parts[1]
	var b := parts[2]
	if r > 1.0 or g > 1.0 or b > 1.0:
		r /= 255.0
		g /= 255.0
		b /= 255.0
	return Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0), 1.0)
