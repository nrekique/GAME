@tool
extends Node3D

@export var properties: Dictionary :
	set(value):
		properties = value
		if !Engine.is_editor_hint():
			return
		rotation_degrees = GameManager.demangler(properties)
	get:
		return properties

func use(_activator: Node)->void:
	$marsfrog/AnimationPlayer.play("walk")

func _ready()->void:
	if Engine.is_editor_hint():
		return
	
	if GAME.appearance_check(properties["appearance_flags"] as int):
		queue_free()
		return
	
	GAME.set_targetname(self, properties["targetname"])
