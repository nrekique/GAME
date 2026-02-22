@tool
class_name CheckpointVolume
extends Volume

# Triggers a player respawn/teleport. Uses GAME.handle_player_death for now.

func _process_body(body: Node, entered: bool) -> void:
	if entered:
		# currently reuse GAME.handle_player_death for checkpoint behavior
		# (see roadmap in docs for a dedicated checkpoint system)
		if Engine.has_singleton("GAME"):
			GAME.handle_player_death(body, 0)
