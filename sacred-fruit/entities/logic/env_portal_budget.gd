@tool
class_name EnvPortalBudget
extends Node3D

@export var profile_mode: String = "balanced" # cinematic, balanced, stress
@export var stress_profile: bool = false
@export_range(1, 64, 1) var portal_max_active: int = 4
@export_range(0.02, 0.5, 0.01) var portal_refresh_seconds: float = 0.10
@export_range(0.25, 1.0, 0.05) var portal_max_render_scale: float = 0.60
@export_range(0.25, 1.0, 0.05) var portal_min_render_scale: float = 0.30
@export_range(0.0, 4.0, 0.01) var portal_min_priority: float = 0.0
@export_range(1, 64, 1) var mirror_max_active: int = 2
@export_range(0.02, 0.5, 0.01) var mirror_refresh_seconds: float = 0.08
@export_range(0.25, 1.0, 0.05) var mirror_render_scale: float = 0.60
@export_range(0.0, 4.0, 0.01) var mirror_min_priority: float = 0.0


static func _to_bool(value: Variant, default_value: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var s: String = String(value).strip_edges().to_lower()
			if s in ["1", "true", "yes", "on", "y"]:
				return true
			if s in ["0", "false", "no", "off", "n", ""]:
				return false
			return default_value
		_:
			return default_value


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("profile_mode"):
		profile_mode = String(props["profile_mode"]).strip_edges().to_lower()
	if props.has("stress_profile"):
		stress_profile = _to_bool(props["stress_profile"], stress_profile)
	if props.has("portal_max_active"):
		portal_max_active = maxi(1, int(props["portal_max_active"]))
	if props.has("portal_refresh_seconds"):
		portal_refresh_seconds = clampf(float(props["portal_refresh_seconds"]), 0.02, 0.5)
	if props.has("portal_max_render_scale"):
		portal_max_render_scale = clampf(float(props["portal_max_render_scale"]), 0.25, 1.0)
	if props.has("portal_min_render_scale"):
		portal_min_render_scale = clampf(float(props["portal_min_render_scale"]), 0.25, portal_max_render_scale)
	if props.has("portal_min_priority"):
		portal_min_priority = clampf(float(props["portal_min_priority"]), 0.0, 4.0)
	if props.has("mirror_max_active"):
		mirror_max_active = maxi(1, int(props["mirror_max_active"]))
	if props.has("mirror_refresh_seconds"):
		mirror_refresh_seconds = clampf(float(props["mirror_refresh_seconds"]), 0.02, 0.5)
	if props.has("mirror_render_scale"):
		mirror_render_scale = clampf(float(props["mirror_render_scale"]), 0.25, 1.0)
	if props.has("mirror_min_priority"):
		mirror_min_priority = clampf(float(props["mirror_min_priority"]), 0.0, 4.0)
