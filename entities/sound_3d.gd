@tool
extends AudioStreamPlayer3D
class_name Sound3D

@export var properties: Dictionary :
	set(value):
		properties = value
		if !Engine.is_editor_hint():
			return
		stream = GameManager.update_sound(properties["sound"] as String)
		volume_db = linear_to_db(properties["volume"] as float)
		autoplay = true
	get:
		return properties

func _on_finished():
	GAME.use_targets(self)

func _ready():
	if Engine.is_editor_hint():
		return
	
	if GAME.appearance_check(properties["appearance_flags"] as int):
		queue_free()
		return
	
	GAME.set_targetname(self, properties["targetname"])
	connect("finished", _on_finished)
