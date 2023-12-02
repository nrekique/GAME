@tool
extends Camera3D

@export var properties: Dictionary :
	set(value):
		properties = value
		if !Engine.is_editor_hint():
			return
		rotation = GameManager.demangler(properties, 2)
	get:
		return properties
