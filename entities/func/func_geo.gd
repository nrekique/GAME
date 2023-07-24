#*******************************************************************************
# FUNC_GEO / FUNC_ILLUSIONARY
# Main map geometry class.
#*******************************************************************************
extends StaticBody
tool

#*******************************************************************************
# CLASS VARIABLES
#*******************************************************************************
export(Dictionary) var properties setget set_properties

#*******************************************************************************
# CLASS FUNCTIONS
#*******************************************************************************
func set_properties(new_properties : Dictionary) -> void:
	if(properties != new_properties):
		properties = new_properties
		update_properties()

func update_properties() -> void:
	for c in get_children():
		if c is MeshInstance:
			c.use_in_baked_light = true
			if "shadowcast" in properties:
				if properties.shadowcast == 0:
					c.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
			var m = c.get_mesh()
			if m is ArrayMesh:
				m.lightmap_unwrap(Transform.IDENTITY, 0.3125)
		if c is CollisionShape:
			c.shape.margin = 0.001
