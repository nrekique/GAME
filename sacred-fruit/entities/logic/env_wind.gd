@tool
class_name EnvWind
extends Node3D

# Authoring-only entity consumed by sandstorm_controller.gd map parsing.
@export_range(0.0, 8.0, 0.01) var wind_speed: float = 1.0
@export var wind_direction: Vector2 = Vector2(1.0, 0.25)


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("wind_speed"):
		wind_speed = maxf(float(props["wind_speed"]), 0.0)
	if props.has("wind_direction"):
		wind_direction = _parse_vec2(props["wind_direction"], wind_direction)
	elif props.has("wind_dir"):
		wind_direction = _parse_vec2(props["wind_dir"], wind_direction)


func _parse_vec2(v: Variant, fallback: Vector2) -> Vector2:
	if v is Vector2:
		return v
	var parts := String(v).replace(",", " ").split_floats(" ")
	if parts.size() >= 2:
		return Vector2(parts[0], parts[1])
	return fallback
