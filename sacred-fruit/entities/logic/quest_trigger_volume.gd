@tool
class_name QuestTriggerVolume
extends Volume

# Placeholder for quest-related triggers. Mappers can subclass further.

func _process_body(body: Node, entered: bool) -> void:
	if entered:
		# emit signal or call quest system when ready
		pass
