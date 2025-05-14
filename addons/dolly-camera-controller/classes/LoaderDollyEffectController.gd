@tool
class_name LoaderDollyEffectController
extends EditorPlugin



func _enter_tree() -> void:
	add_custom_type(
		"DollyEffectController",
		"DollyEffectController",
		preload("res://addons/dolly-camera-controller/classes/DollyEffectController.gd"),
		preload("res://addons/dolly-camera-controller/assets/icons/DollyIcon.svg"))


func _exit_tree() -> void:
	remove_custom_type("DollyEffectController")
