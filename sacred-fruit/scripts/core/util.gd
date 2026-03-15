class_name Util
extends Node

# global debug switch; can be toggled at runtime
static var debug_enabled: bool = false

static func to_bool(value: Variant, default_value: bool = false) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var s := String(value).strip_edges().to_lower()
			if s in ["1", "true", "yes", "on", "y"]:
				return true
			if s in ["0", "false", "no", "off", "n", ""]:
				return false
			return default_value
		_:
			return default_value

static func get_node_prop(node: Node, key: String, default_value: Variant = null) -> Variant:
	if node == null or key.is_empty():
		return default_value
	if key in node:
		return node.get(key)
	if "func_godot_properties" in node:
		var props_var: Variant = node.func_godot_properties
		if props_var is Dictionary:
			var props := props_var as Dictionary
			if props.has(key):
				return props[key]
	if node.has_meta("func_godot_properties"):
		var meta_props_var: Variant = node.get_meta("func_godot_properties")
		if meta_props_var is Dictionary:
			var meta_props := meta_props_var as Dictionary
			if meta_props.has(key):
				return meta_props[key]
	return default_value

static func _is_master_unlocked(master_node: Node) -> bool:
	if master_node == null:
		return false
	if master_node.has_method("is_unlocked"):
		return to_bool(master_node.call("is_unlocked"), false)
	for method_name in ["is_active", "is_enabled", "is_open", "is_on"]:
		if master_node.has_method(method_name):
			return to_bool(master_node.call(method_name), false)
	for property_name in ["unlocked", "active", "enabled", "open", "on", "button_pressed"]:
		var value: Variant = get_node_prop(master_node, property_name, null)
		if value != null:
			return to_bool(value, false)
	return true

static func master_allows(activator: Node) -> bool:
	var master_name := String(get_node_prop(activator, "master", "")).strip_edges()
	if master_name.is_empty():
		return true
	# use activator's tree since static functions cannot call get_tree()
	var tree: SceneTree = null
	if activator != null:
		tree = activator.get_tree() as SceneTree
	if tree == null:
		return true  # cannot evaluate, assume unlocked
	var masters: Array = tree.get_nodes_in_group(master_name)
	if masters.is_empty():
		return false
	for m in masters:
		if m is Node and _is_master_unlocked(m as Node):
			return true
	return false

static func editor_hint() -> bool:
	# thin wrapper around engine API
	return Engine.is_editor_hint()

static func debug_print(msg: String) -> void:
	if debug_enabled:
		print(msg)


static func normalize_res_path(raw_path: String) -> String:
	var path := raw_path.strip_edges().replace("\\", "/")
	if path.begins_with("\"") and path.ends_with("\"") and path.length() >= 2:
		path = path.substr(1, path.length() - 2)
	if path.is_empty():
		return ""
	if path.find("/../") != -1 or path.begins_with("../") or path.ends_with("/.."):
		return ""
	while path.find("//") != -1:
		path = path.replace("//", "/")
	if path.begins_with("res:/") and not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("res:/").trim_prefix("/")
	if path.begins_with("res://"):
		return path
	# Reject non-project URI schemes and absolute drive paths.
	if path.find("://") != -1 or path.find(":") != -1:
		return ""
	if path.begins_with("/"):
		return "res://" + path.substr(1)
	return "res://" + path


static func sanitize_allowed_resource_path(
		raw_path: String,
		allowed_roots: PackedStringArray,
		required_extension: String = ""
	) -> String:
	var path := normalize_res_path(raw_path)
	if path.is_empty():
		return ""
	var ext := required_extension.strip_edges().to_lower()
	if not ext.is_empty() and not path.to_lower().ends_with(ext):
		return ""

	var roots := allowed_roots
	if roots.is_empty():
		roots = PackedStringArray(["res://"])
	for root_v in roots:
		var root := normalize_res_path(String(root_v))
		if root.is_empty():
			continue
		if not root.ends_with("/"):
			root += "/"
		if path.begins_with(root):
			return path
	return ""
