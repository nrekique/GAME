@tool
class_name DamageVolume
extends Volume

# Inflicts `amount` of damage on any body with `apply_damage` method.

func _process_body(body: Node, entered: bool) -> void:
	if entered and body.has_method("apply_damage"):
		body.call("apply_damage", amount)
