@tool
class_name EnvZone
extends Node3D

@export_range(0.1, 4096.0, 0.1) var radius: float = 12.0
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.85
@export_range(0.0, 0.2, 0.001) var fog_density: float = 0.05
@export_range(0.0, 8.0, 0.01) var wind_speed: float = 1.0


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("radius"):
		radius = maxf(float(props["radius"]), 0.1)
	if props.has("intensity"):
		intensity = clampf(float(props["intensity"]), 0.0, 1.0)
	if props.has("fog_density"):
		fog_density = clampf(float(props["fog_density"]), 0.0, 0.2)
	if props.has("wind_speed"):
		wind_speed = maxf(float(props["wind_speed"]), 0.0)
