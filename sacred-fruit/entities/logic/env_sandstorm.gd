@tool
class_name EnvSandstorm
extends Node3D

# Authoring-only entity used by TrenchBroom/FuncGodot.
# Runtime effect is applied by sandstorm_controller.gd by parsing the map keys.
@export var enabled: bool = true
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.85
@export_range(0.0, 4.0, 0.01) var wind_speed: float = 1.0
@export var wind_direction: Vector2 = Vector2(1.0, 0.25)
@export var fog_color: Color = Color(0.78, 0.62, 0.36, 1.0)


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = bool(props["enabled"])
	if props.has("intensity"):
		intensity = clampf(float(props["intensity"]), 0.0, 1.0)
	if props.has("wind_speed"):
		wind_speed = maxf(float(props["wind_speed"]), 0.0)
	if props.has("wind_direction"):
		wind_direction = _parse_vec2(props["wind_direction"], wind_direction)
	elif props.has("wind_dir"):
		wind_direction = _parse_vec2(props["wind_dir"], wind_direction)
	if props.has("fog_color"):
		fog_color = _parse_color(props["fog_color"], fog_color)


func _parse_vec2(v: Variant, fallback: Vector2) -> Vector2:
	if v is Vector2:
		return v
	var parts := String(v).replace(",", " ").split_floats(" ")
	if parts.size() >= 2:
		return Vector2(parts[0], parts[1])
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
