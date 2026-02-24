## Special Light base class that contains static helper functions for LightOmni and LightSpot entities.
class_name LightBase
extends Light3D

static func _func_godot_apply_properties(node: Light3D, props: Dictionary) -> void:
	node.light_energy = props["energy"] as float
	node.light_indirect_energy = props["indirect_energy"] as float
	node.shadow_bias = props["shadow_bias"] as float
	node.shadow_enabled = props["shadows"] as bool
	node.light_color = props["color"] as Color
	var bake_mode_raw: Variant = props.get("bake_mode", "dynamic")
	var bake_mode := String(bake_mode_raw).strip_edges().to_lower()
	match bake_mode:
		"disabled", "none":
			node.light_bake_mode = Light3D.BAKE_DISABLED
		"static", "baked":
			node.light_bake_mode = Light3D.BAKE_STATIC
		_, "dynamic":
			node.light_bake_mode = Light3D.BAKE_DYNAMIC
