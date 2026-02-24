@tool
class_name AIAlertVolume
extends Volume

# Alerts AI to a location when something enters the volume.

func _process_body(body: Node, entered: bool) -> void:
	if entered and Engine.has_singleton("GAME"):
		GAME.call("alert_ai", body.global_position, body)
