@tool
extends EditorPlugin

var toolbar: Control = null

func _enable_plugin() -> void:
	if toolbar != null and is_instance_valid(toolbar):
		return
	toolbar = preload("res://addons/CardGameSkeleton/CardGameSkeleton.tscn").instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, toolbar)


func _disable_plugin() -> void:
	_remove_toolbar()


func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	_remove_toolbar()


func _remove_toolbar() -> void:
	if toolbar != null and is_instance_valid(toolbar):
		remove_control_from_docks(toolbar)
		toolbar.queue_free()
	toolbar = null
