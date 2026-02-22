@tool
class_name MusicZoneVolume
extends Volume

# Switches music when player enters.

func _process_body(body: Node, entered: bool) -> void:
	if entered and Engine.has_singleton("GAME"):
		GAME.call("set_music_zone", tag)
