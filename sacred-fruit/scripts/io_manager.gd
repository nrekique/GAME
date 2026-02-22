class_name IOManager
extends Node
const Util := preload("res://scripts/util.gd")

signal io_event_dispatched(event: Dictionary)

# configurable runtime state (GameManager will propagate its exports here)
var io_debug_logging: bool = false
var io_trace_capacity: int = 256

# internal tracing state
var _io_trace: Array[Dictionary] = []
var _io_seq: int = 0
var _io_once_keys: Dictionary = {}

# helpers that delegate to GAME for shared utilities
func _get_node_prop(node: Node, key: String, default_value: Variant = null) -> Variant:
	# delegate to GAME which already has robust logic
	if Engine.has_singleton("GAME"):
		return GAME._get_node_prop(node, key, default_value)
	if node == null or key.is_empty():
		return default_value
	if key in node:
		return node.get(key)
	# check func_godot_properties field
	if "func_godot_properties" in node:
		var props_var: Variant = node.func_godot_properties
		if props_var is Dictionary:
			var props := props_var as Dictionary
			if props.has(key):
				return props[key]
	# check metadata
	if node.has_meta("func_godot_properties"):
		var meta_props_var: Variant = node.get_meta("func_godot_properties")
		if meta_props_var is Dictionary:
			var meta_props := meta_props_var as Dictionary
			if meta_props.has(key):
				return meta_props[key]
	# missing property
	if io_debug_logging or Util.debug_enabled:
		Util.debug_print("[io] missing prop '%s' on %s" % [key, str(node)])
	return default_value

func _is_master_unlocked(master_node: Node) -> bool:
	if master_node == null:
		return false
	if master_node.has_method("is_unlocked"):
		return Util.to_bool(master_node.call("is_unlocked"), false)
	for method_name in ["is_active", "is_enabled", "is_open", "is_on"]:
		if master_node.has_method(method_name):
			return Util.to_bool(master_node.call(method_name), false)
	for property_name in ["unlocked", "active", "enabled", "open", "on", "button_pressed"]:
		var value: Variant = _get_node_prop(master_node, property_name, null)
		if value != null:
			return Util.to_bool(value, false)
	# default unlocked
	return true

func _master_allows(activator: Node) -> bool:
	var master_name := String(_get_node_prop(activator, "master", "")).strip_edges()
	if master_name.is_empty():
		return true
	var masters := get_tree().get_nodes_in_group(master_name)
	if masters.is_empty():
		return false
	for m in masters:
		if m is Node and _is_master_unlocked(m as Node):
			return true
	return false

func _apply_killtarget(activator: Node) -> void:
	var killtarget_raw := String(_get_node_prop(activator, "killtarget", ""))
	if killtarget_raw.is_empty():
		return
	var killed := {}
	for chunk in killtarget_raw.split(","):
		var group_name := String(chunk).strip_edges()
		if group_name.is_empty():
			continue
		for target_node in get_tree().get_nodes_in_group(group_name):
			var node := target_node as Node
			if node == null:
				continue
			var node_id := node.get_instance_id()
			if killed.has(node_id):
				continue
			killed[node_id] = true
			node.queue_free()

func _append_io_trace(event: Dictionary) -> void:
	_io_trace.append(event)
	while _io_trace.size() > io_trace_capacity:
		_io_trace.remove_at(0)
	io_event_dispatched.emit(event)
	if io_debug_logging:
		var source_name: String = String(event.get("source_name", ""))
		var group_name: String = String(event.get("target_group", ""))
		var input_name: String = String(event.get("input", "use"))
		var delay_value: float = float(event.get("delay", 0.0))
		var invoked: int = int(event.get("invoked_count", 0))
		var target_count: int = int(event.get("target_count", 0))
		print("[io] src=%s target=%s input=%s delay=%.3f invoked=%d/%d" % [source_name, group_name, input_name, delay_value, invoked, target_count])

func io_get_trace() -> Array[Dictionary]:
	return _io_trace.duplicate(true)

func io_clear_trace() -> void:
	_io_trace.clear()
	_io_once_keys.clear()

func _get_method_signature(node: Node, method_name: String) -> Dictionary:
	var info_out: Dictionary = {"found": false, "min_args": 0, "max_args": 0}
	if node == null or method_name.is_empty():
		return info_out
	var methods: Array[Dictionary] = node.get_method_list()
	for method_info: Dictionary in methods:
		if String(method_info.get("name", "")) != method_name:
			continue
		var args_v: Variant = method_info.get("args", [])
		var defaults_v: Variant = method_info.get("default_args", [])
		var arg_count: int = 0
		var default_count: int = 0
		if args_v is Array:
			arg_count = (args_v as Array).size()
		if defaults_v is Array:
			default_count = (defaults_v as Array).size()
		info_out["found"] = true
		info_out["max_args"] = arg_count
		info_out["min_args"] = maxi(arg_count - default_count, 0)
		return info_out
	return info_out

func _call_method_best_effort(node: Node, method_name: String, args: Array) -> bool:
	if node == null or method_name.is_empty():
		return false
	var sig: Dictionary = _get_method_signature(node, method_name)
	if not bool(sig.get("found", false)):
		return false
	var min_args: int = int(sig.get("min_args", 0))
	var max_args: int = int(sig.get("max_args", 0))
	var call_count: int = mini(args.size(), max_args)
	if call_count < min_args:
		return false
	var call_args: Array = []
	for i in range(call_count):
		call_args.append(args[i])
	node.callv(method_name, call_args)
	return true

func _invoke_io_on_target(target_node: Node, input_name: String, arg: Variant, activator: Node, caller: Node) -> bool:
	if target_node == null:
		return false
	if _call_method_best_effort(target_node, "io_input", [input_name, arg, activator, caller]):
		return true
	if _call_method_best_effort(target_node, input_name, [arg, activator, caller]):
		return true
	if input_name != "use":
		if _call_method_best_effort(target_node, "use", [arg, activator, caller]):
			return true
	return false

func _make_io_once_key(source_id: int, source_output: String, target_group: String, input_name: String) -> String:
	return "%d|%s|%s|%s" % [source_id, source_output, target_group, input_name]

func _apply_killtarget_after_delay(activator: Node, seconds: float) -> void:
	await get_tree().create_timer(maxf(seconds, 0.0)).timeout
	_apply_killtarget(activator)

func _dispatch_target_group_now(
		activator: Node,
		target_group: String,
		input_name: String,
		arg: Variant,
		delay_seconds: float,
		source_output: String = "",
		caller: Node = null
	) -> void:
	var target_list: Array[Node] = get_tree().get_nodes_in_group(target_group)
	if target_list.size() == 0:
		Util.debug_print("[io] no nodes found in group '%s'" % target_group)
		return
	var invoked_count: int = 0
	for targ: Node in target_list:
		if _invoke_io_on_target(targ, input_name, arg, activator, caller):
			invoked_count += 1
	_io_seq += 1
	var source_name: String = ""
	if activator != null:
		source_name = activator.name
	var event: Dictionary = {
		"seq": _io_seq,
		"time_ms": Time.get_ticks_msec(),
		"source_id": activator.get_instance_id() if activator != null else 0,
		"source_name": source_name,
		"source_output": source_output,
		"target_group": target_group,
		"input": input_name,
		"arg": arg,
		"delay": delay_seconds,
		"target_count": target_list.size(),
		"invoked_count": invoked_count
	}
	_append_io_trace(event)

func _dispatch_target_group_after_delay(
		activator: Node,
		target_group: String,
		input_name: String,
		arg: Variant,
		delay_seconds: float,
		source_output: String = "",
		caller: Node = null
	) -> void:
	await get_tree().create_timer(maxf(delay_seconds, 0.0)).timeout
	_dispatch_target_group_now(activator, target_group, input_name, arg, delay_seconds, source_output, caller)

func _dispatch_target_group(
		activator: Node,
		target_group: String,
		input_name: String,
		arg: Variant,
		delay_seconds: float,
		source_output: String = "",
		once: bool = false,
		caller: Node = null
	) -> void:
	if target_group.is_empty():
		return
	if activator != null and once:
		var once_key: String = _make_io_once_key(activator.get_instance_id(), source_output, target_group, input_name)
		if _io_once_keys.has(once_key):
			return
		_io_once_keys[once_key] = true
	if delay_seconds > 0.0:
		call_deferred("_dispatch_target_group_after_delay", activator, target_group, input_name, arg, delay_seconds, source_output, caller)
	else:
		_dispatch_target_group_now(activator, target_group, input_name, arg, delay_seconds, source_output, caller)

func use_targets(activator: Node, target: String, overrides: Dictionary = {}) -> void:
	if activator != null and not _master_allows(activator):
		return
	var f: String = String(overrides.get("input", String(_get_node_prop(activator, "targetfunc", "")))).strip_edges()
	if f.is_empty():
		f = "use"
	var arg: Variant = overrides.get("arg", _get_node_prop(activator, "targetarg", null))
	var delay_seconds: float = maxf(float(overrides.get("delay", _get_node_prop(activator, "targetdelay", 0.0))), 0.0)
	var source_output: String = String(overrides.get("source_output", "target"))
	var once: bool = Util.to_bool(overrides.get("once", false), false)
	var caller: Node = overrides.get("caller", activator) as Node
	var seen_groups := {}
	for chunk in target.split(","):
		var group_name := String(chunk).strip_edges()
		if group_name.is_empty() or seen_groups.has(group_name):
			continue
		seen_groups[group_name] = true
		_dispatch_target_group(activator, group_name, f, arg, delay_seconds, source_output, once, caller)
	if activator != null:
		if delay_seconds > 0.0:
			call_deferred("_apply_killtarget_after_delay", activator, delay_seconds)
		else:
			_apply_killtarget(activator)

func _parse_output_bool(value: String) -> bool:
	var s: String = value.strip_edges().to_lower()
	return s in ["1", "true", "yes", "on", "once"]

func _parse_output_arg(value: String) -> Variant:
	var trimmed: String = value.strip_edges()
	if trimmed.is_empty():
		return null
	if trimmed.is_valid_int():
		return int(trimmed)
	if trimmed.is_valid_float():
		return float(trimmed)
	return trimmed

func io_fire_output(activator: Node, output_value: String, source_output: String = "", default_input: String = "use") -> void:
	var raw: String = output_value.strip_edges()
	if raw.is_empty():
		return
	var lines: PackedStringArray = raw.split(";", false)
	for ln in lines:
		var line: String = String(ln).strip_edges()
		if line.is_empty():
			continue
		var parts: PackedStringArray = line.split(",", false)
		var target_group: String = String(parts[0]).strip_edges()
		if target_group.is_empty():
			continue
		var input_name: String = default_input
		var arg: Variant = null
		var delay_seconds: float = 0.0
		var once: bool = false
		if parts.size() >= 2 and not String(parts[1]).strip_edges().is_empty():
			input_name = String(parts[1]).strip_edges()
		if parts.size() >= 3:
			arg = _parse_output_arg(String(parts[2]))
		if parts.size() >= 4:
			delay_seconds = maxf(float(String(parts[3]).to_float()), 0.0)
		if parts.size() >= 5:
			once = _parse_output_bool(String(parts[4]))
		_dispatch_target_group(activator, target_group, input_name, arg, delay_seconds, source_output, once, activator)
	if activator != null:
		_apply_killtarget(activator)

func fire_output(activator: Node, output_key: String, fallback_target: String = "", default_input: String = "use") -> void:
	if activator == null:
		return
	var raw_value: String = String(_get_node_prop(activator, output_key, "")).strip_edges()
	if raw_value.is_empty():
		if not fallback_target.strip_edges().is_empty():
			use_targets(activator, fallback_target, {"source_output": output_key, "input": default_input})
		return
	io_fire_output(activator, raw_value, output_key, default_input)

func set_targetname(node: Node, targetname: String) -> void:
	if node == null:
		return
	if targetname.is_empty():
		return
	# Allow comma-delimited targetnames (Quake convention).
	for t in targetname.split(","):
		var name := String(t).strip_edges()
		if not name.is_empty():
			node.add_to_group(name)