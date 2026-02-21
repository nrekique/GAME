@tool
class_name EnvWeather
extends Node3D

@export_enum("none", "rain", "snow") var weather_mode: String = "none"
@export_range(0.0, 1.0, 0.01) var weather_intensity: float = 0.0


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("weather_mode"):
		weather_mode = String(props["weather_mode"]).strip_edges().to_lower()
	if props.has("weather_intensity"):
		weather_intensity = clampf(float(props["weather_intensity"]), 0.0, 1.0)
