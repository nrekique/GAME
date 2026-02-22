@tool
class_name EnvMessage
extends Node3D
const Util := preload("res://scripts/util.gd")

@export var target: String = ""
@export var targetfunc: String = ""
@export var targetname: String = ""
@export var enabled: bool = true
@export var message: String = ""
@export var hold_time: float = 2.0
@export var restore_default_text: bool = true


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("target"):
		target = String(props["target"])
	if props.has("targetfunc"):
		targetfunc = String(props["targetfunc"])
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("message"):
		message = String(props["message"])
	if props.has("hold_time"):
		hold_time = maxf(float(props["hold_time"]), 0.0)
	if props.has("restore_default_text"):
		restore_default_text = Util.to_bool(props["restore_default_text"], restore_default_text)


func _ready() -> void:
	if Util.editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)


func use() -> void:
	if not enabled:
		return

	var msg := message.strip_edges()
	if not msg.is_empty():
		Util.debug_print("[env_message] %s" % msg)
		GAME.emit_signal("objective_text_changed", msg)
		if restore_default_text and hold_time > 0.0:
			call_deferred("_restore_default_after_delay", hold_time)

	_fire_targets()


func _restore_default_after_delay(seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0)).timeout
	if GAME != null and GAME.has_method("_default_objective_text"):
		var fallback := String(GAME.call("_default_objective_text"))
		if not fallback.is_empty():
			GAME.emit_signal("objective_text_changed", fallback)


func _fire_targets() -> void:
	var target_group := target.strip_edges()
	if target_group.is_empty():
		return
	GAME.use_targets(self, target_group)