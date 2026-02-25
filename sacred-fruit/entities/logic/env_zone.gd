@tool
class_name EnvZone
extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var enabled: bool = true
@export_range(0.1, 4096.0, 0.1) var radius: float = 12.0
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.85
@export_range(0.0, 0.2, 0.001) var fog_density: float = 0.05
@export_range(0.0, 8.0, 0.01) var wind_speed: float = 1.0
@export var light_cull_mask: int = -1
@export var reflection_cull_mask: int = -1
@export_range(-1.0, 8.0, 0.01) var reflection_intensity_scale: float = -1.0


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("radius"):
		radius = maxf(float(props["radius"]), 0.1)
	if props.has("intensity"):
		intensity = clampf(float(props["intensity"]), 0.0, 1.0)
	if props.has("fog_density"):
		fog_density = clampf(float(props["fog_density"]), 0.0, 0.2)
	if props.has("wind_speed"):
		wind_speed = maxf(float(props["wind_speed"]), 0.0)
	if props.has("light_cull_mask"):
		light_cull_mask = int(props["light_cull_mask"])
	if props.has("reflection_cull_mask"):
		reflection_cull_mask = int(props["reflection_cull_mask"])
	if props.has("reflection_intensity_scale"):
		reflection_intensity_scale = float(props["reflection_intensity_scale"])
