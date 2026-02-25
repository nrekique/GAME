@tool
class_name FuncPrefabInstance
extends Node3D
const Util := preload("res://scripts/core/util.gd")

@export var targetname: String = ""
@export var enabled: bool = true
@export_file("*.tscn") var prefab_scene: String = ""
@export var spawn_on_ready: bool = true
@export var one_shot: bool = true
@export var clear_children_before_spawn: bool = true
@export_multiline var override_json: String = ""

var _spawned: bool = false
var _instance: Node = null


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("prefab_scene"):
		prefab_scene = String(props["prefab_scene"]).strip_edges()
	if props.has("spawn_on_ready"):
		spawn_on_ready = Util.to_bool(props["spawn_on_ready"], spawn_on_ready)
	if props.has("one_shot"):
		one_shot = Util.to_bool(props["one_shot"], one_shot)
	if props.has("clear_children_before_spawn"):
		clear_children_before_spawn = Util.to_bool(props["clear_children_before_spawn"], clear_children_before_spawn)
	if props.has("override_json"):
		override_json = String(props["override_json"])


func _ready() -> void:
	if Util.editor_hint():
		return
	if not targetname.is_empty():
		GAME.set_targetname(self, targetname)
	if enabled and spawn_on_ready:
		spawn_prefab()


func use() -> void:
	spawn_prefab()


func trigger() -> void:
	spawn_prefab()


func clear_instance() -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	_spawned = false


func spawn_prefab() -> void:
	if not enabled:
		return
	if one_shot and _spawned:
		return
	if prefab_scene.is_empty():
		push_warning("func_prefab_instance '%s' missing prefab_scene" % name)
		return
	var packed_v: Variant = load(prefab_scene)
	if not (packed_v is PackedScene):
		push_warning("func_prefab_instance '%s' could not load PackedScene at %s" % [name, prefab_scene])
		return
	if clear_children_before_spawn:
		clear_instance()
	var inst: Node = (packed_v as PackedScene).instantiate()
	if inst == null:
		return
	add_child(inst)
	if inst is Node3D:
		(inst as Node3D).transform = Transform3D.IDENTITY
	_apply_overrides(inst)
	_instance = inst
	_spawned = true


func _apply_overrides(root: Node) -> void:
	var text: String = override_json.strip_edges()
	if text.is_empty() or root == null:
		return
	var parser := JSON.new()
	var err: Error = parser.parse(text)
	if err != OK:
		push_warning("func_prefab_instance '%s' override_json parse error: %s" % [name, parser.get_error_message()])
		return
	var data: Variant = parser.data
	if not (data is Dictionary):
		push_warning("func_prefab_instance '%s' override_json must be a Dictionary" % name)
		return
	var dict_data: Dictionary = data
	for key_v in dict_data.keys():
		var key: String = String(key_v)
		var value: Variant = dict_data[key_v]
		var sep_idx: int = key.rfind(":")
		if sep_idx <= 0 or sep_idx >= key.length() - 1:
			continue
		var node_path_str: String = key.substr(0, sep_idx).strip_edges()
		var prop_name: String = key.substr(sep_idx + 1).strip_edges()
		if node_path_str.is_empty() or prop_name.is_empty():
			continue
		var target_node: Node = root.get_node_or_null(NodePath(node_path_str))
		if target_node == null:
			continue
		target_node.set(prop_name, value)