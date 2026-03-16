@tool
class_name LightDirectional
extends DirectionalLight3D
## Directional sun/moon light entity.
## One per level. Position is ignored — only rotation matters.
##
## mangle controls the light direction:
##   x = pitch  (negative = shining downward; -45 = sun 45° above horizon)
##   y = yaw    (compass bearing the light comes FROM; 0 = +Z, 90 = +X)
##   z = roll   (leave 0)
##
## sky_mode controls whether this light affects the sky, scene, or both:
##   "light_and_sky" (default), "light_only", "sky_only"

func _func_godot_apply_properties(props: Dictionary) -> void:
	LightBase._func_godot_apply_properties(self, props)

	if props.has("mangle"):
		var m := props["mangle"] as Vector3
		rotation_degrees = Vector3(m.x, m.y, m.z)

	if props.has("shadow_max_distance"):
		directional_shadow_max_distance = float(props["shadow_max_distance"]) / 32.0

	if props.has("angular_distance"):
		light_angular_distance = clampf(float(props["angular_distance"]), 0.0, 90.0)

	var sky_mode_raw := String(props.get("sky_mode", "light_and_sky")).strip_edges().to_lower()
	match sky_mode_raw:
		"light_only":
			sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		"sky_only":
			sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
		_:
			sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
