@tool
class_name EnvPostFX
extends Node3D

@export_range(0.0, 1.0, 0.01) var postfx_strength: float = 0.0
@export_range(0.25, 4.0, 0.01) var postfx_exposure: float = 1.0
@export_range(0.1, 4.0, 0.01) var postfx_contrast: float = 1.0
@export_range(0.0, 2.0, 0.01) var postfx_saturation: float = 1.0


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("postfx_strength"):
		postfx_strength = clampf(float(props["postfx_strength"]), 0.0, 1.0)
	if props.has("postfx_exposure"):
		postfx_exposure = clampf(float(props["postfx_exposure"]), 0.25, 4.0)
	if props.has("postfx_contrast"):
		postfx_contrast = clampf(float(props["postfx_contrast"]), 0.1, 4.0)
	if props.has("postfx_saturation"):
		postfx_saturation = clampf(float(props["postfx_saturation"]), 0.0, 2.0)
