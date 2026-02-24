@tool
class_name CheckpointVolume
extends Volume

# Registers a respawn checkpoint when the player enters.
@export var checkpoint_id: String = ""

func _process_body(body: Node, entered: bool) -> void:
	if not entered:
		return
	if not Engine.has_singleton("GAME"):
		return
	var resolved_id := checkpoint_id.strip_edges()
	if resolved_id.is_empty():
		resolved_id = save_id.strip_edges()
	if resolved_id.is_empty():
		resolved_id = "checkpoint_%d" % get_instance_id()
	if GAME.has_method("register_checkpoint"):
		GAME.call("register_checkpoint", resolved_id, global_position, global_rotation_degrees)
		if GAME.has_method("set_active_checkpoint"):
			GAME.call("set_active_checkpoint", resolved_id)
		return
	# compatibility path for older GAME scripts
	if GAME.has_method("handle_player_death"):
		GAME.call("handle_player_death", body, 0.0)
