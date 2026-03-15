class_name DialogueManager
extends Node
const Util := preload("res://scripts/core/util.gd")
const DialogueUIScript := preload("res://scripts/ui/dialogue_ui.gd")
const DialogueMarkdown := preload("res://scripts/core/dialogue_markdown.gd")

const DIALOGUE_STATE_PATH := "user://dialogue_state.cfg"
const DIALOGUE_STATE_BACKUP_PATH := DIALOGUE_STATE_PATH + ".bak"

signal dialogue_started(conversation_id: String, speaker: String)
signal dialogue_closed(conversation_id: String)
signal dialogue_node_changed(conversation_id: String, node_id: String)
signal dialogue_choice_selected(conversation_id: String, node_id: String, choice_text: String)

var _ui: Node = null
var _active: bool = false
var _conversation_id: String = ""
var _conversation: Dictionary = {}
var _nodes: Dictionary = {}
var _current_node_id: String = ""
var _speaker_override: String = ""
var _dialogue_activator: Node = null
var _dialogue_source: Node3D = null
var _mouse_mode_before_dialogue: int = Input.MOUSE_MODE_CAPTURED

var _facts: Dictionary = {}
var _skills: Dictionary = {"speech": 25}
var _faction_rep: Dictionary = {}
var _quest_stage: Dictionary = {}


func _ready() -> void:
	if Util.editor_hint():
		return
	_load_state()
	_ensure_ui()


func is_dialogue_active() -> bool:
	return _active


func start_dialogue_from_resource(resource_path: String, speaker_override: String = "", activator: Node = null, speaker_node: Node = null) -> bool:
	if resource_path.strip_edges().is_empty():
		return false
	if not FileAccess.file_exists(resource_path):
		push_warning("DialogueManager: missing dialogue file: %s" % resource_path)
		return false
	var raw: String = FileAccess.get_file_as_string(resource_path)
	if raw.strip_edges().is_empty():
		push_warning("DialogueManager: dialogue file is empty: %s" % resource_path)
		return false
	var conv: Dictionary = {}
	if _is_markdown_dialogue_path(resource_path):
		var parsed_md: Dictionary = DialogueMarkdown.parse_conversation(raw, resource_path)
		if not bool(parsed_md.get("ok", false)):
			push_warning("DialogueManager: invalid dialogue markdown: %s (%s)" % [resource_path, String(parsed_md.get("error", "parse error"))])
			return false
		var conv_v: Variant = parsed_md.get("conversation", {})
		if conv_v is Dictionary:
			conv = conv_v as Dictionary
	else:
		var parsed: Variant = JSON.parse_string(raw)
		if not (parsed is Dictionary):
			push_warning("DialogueManager: invalid dialogue json: %s" % resource_path)
			return false
		conv = parsed as Dictionary
	if conv.is_empty():
		push_warning("DialogueManager: parsed dialogue is empty: %s" % resource_path)
		return false
	var conv_id: String = String(conv.get("id", resource_path)).strip_edges()
	if conv_id.is_empty():
		conv_id = resource_path
	return start_dialogue(conv_id, conv, speaker_override, activator, speaker_node)


func _is_markdown_dialogue_path(resource_path: String) -> bool:
	var lower: String = resource_path.strip_edges().to_lower()
	return lower.ends_with(".md") or lower.ends_with(".markdown")


func start_dialogue(conversation_id: String, conversation: Dictionary, speaker_override: String = "", activator: Node = null, speaker_node: Node = null) -> bool:
	if conversation.is_empty():
		return false
	if not conversation.has("nodes"):
		push_warning("DialogueManager: conversation missing 'nodes': %s" % conversation_id)
		return false
	var nodes_v: Variant = conversation.get("nodes", {})
	if not (nodes_v is Dictionary):
		push_warning("DialogueManager: conversation nodes must be a dictionary: %s" % conversation_id)
		return false
	var start_node: String = String(conversation.get("start", "")).strip_edges()
	if start_node.is_empty():
		push_warning("DialogueManager: conversation missing 'start' node: %s" % conversation_id)
		return false
	if _active:
		end_dialogue()
	_ensure_ui()
	_conversation_id = conversation_id
	_conversation = conversation
	_nodes = nodes_v as Dictionary
	_current_node_id = start_node
	_speaker_override = speaker_override.strip_edges()
	_dialogue_activator = activator
	_dialogue_source = speaker_node as Node3D
	_active = true
	_mouse_mode_before_dialogue = Input.get_mouse_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_begin_dialogue_focus()
	emit_signal("dialogue_started", _conversation_id, _resolve_current_speaker())
	_refresh_current_node_view()
	return true


func end_dialogue() -> void:
	if not _active:
		return
	_active = false
	if _ui != null and is_instance_valid(_ui):
		_ui.close_dialogue()
	_end_dialogue_focus()
	Input.set_mouse_mode(_mouse_mode_before_dialogue)
	var closed_id: String = _conversation_id
	_conversation_id = ""
	_conversation.clear()
	_nodes.clear()
	_current_node_id = ""
	_speaker_override = ""
	_dialogue_activator = null
	_dialogue_source = null
	emit_signal("dialogue_closed", closed_id)


func get_skill(skill_name: String, default_value: int = 0) -> int:
	var key: String = skill_name.strip_edges().to_lower()
	if key.is_empty():
		return default_value
	if not _skills.has(key):
		return default_value
	return int(_skills[key])


func set_skill(skill_name: String, value: int) -> void:
	var key: String = skill_name.strip_edges().to_lower()
	if key.is_empty():
		return
	_skills[key] = value
	_save_state()


func add_skill(skill_name: String, delta: int) -> void:
	set_skill(skill_name, get_skill(skill_name, 0) + delta)


func get_faction_rep(faction_name: String, default_value: int = 0) -> int:
	var key: String = faction_name.strip_edges().to_lower()
	if key.is_empty():
		return default_value
	if not _faction_rep.has(key):
		return default_value
	return int(_faction_rep[key])


func set_faction_rep(faction_name: String, value: int) -> void:
	var key: String = faction_name.strip_edges().to_lower()
	if key.is_empty():
		return
	_faction_rep[key] = value
	_save_state()


func add_faction_rep(faction_name: String, delta: int) -> void:
	set_faction_rep(faction_name, get_faction_rep(faction_name, 0) + delta)


func get_quest_stage(quest_id: String, default_value: int = 0) -> int:
	var key: String = quest_id.strip_edges().to_lower()
	if key.is_empty():
		return default_value
	if not _quest_stage.has(key):
		return default_value
	return int(_quest_stage[key])


func set_quest_stage(quest_id: String, stage: int) -> void:
	var key: String = quest_id.strip_edges().to_lower()
	if key.is_empty():
		return
	_quest_stage[key] = stage
	_save_state()


func add_quest_stage(quest_id: String, delta: int) -> void:
	set_quest_stage(quest_id, get_quest_stage(quest_id, 0) + delta)


func has_started_quest(quest_id: String) -> bool:
	return get_quest_stage(quest_id, 0) > 0


func has_fact(fact_name: String) -> bool:
	var key: String = fact_name.strip_edges().to_lower()
	if key.is_empty():
		return false
	return Util.to_bool(_facts.get(key, false), false)


func set_fact(fact_name: String, value: bool = true) -> void:
	var key: String = fact_name.strip_edges().to_lower()
	if key.is_empty():
		return
	if value:
		_facts[key] = true
	else:
		_facts.erase(key)
	_save_state()


func clear_fact(fact_name: String) -> void:
	set_fact(fact_name, false)


func choose_option(choice_index: int) -> void:
	if not _active:
		return
	var node: Dictionary = _get_current_node()
	if node.is_empty():
		end_dialogue()
		return
	if choice_index < 0:
		var next_auto: String = String(node.get("next", "")).strip_edges()
		if next_auto.is_empty():
			end_dialogue()
		else:
			_go_to_node(next_auto)
		return

	var choices_v: Variant = node.get("choices", [])
	if not (choices_v is Array):
		end_dialogue()
		return
	var choices: Array = choices_v as Array
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice_v: Variant = choices[choice_index]
	if not (choice_v is Dictionary):
		return
	var choice: Dictionary = choice_v as Dictionary
	var choice_state: Dictionary = _evaluate_choice_state(choice)
	if not bool(choice_state.get("enabled", false)):
		return

	var choice_text: String = String(choice.get("text", "")).strip_edges()
	emit_signal("dialogue_choice_selected", _conversation_id, _current_node_id, choice_text)
	_apply_choice_effects(choice)

	if Util.to_bool(choice.get("end", false), false):
		end_dialogue()
		return

	var next_id: String = _resolve_next_node(choice)
	if next_id.is_empty():
		next_id = String(node.get("next", "")).strip_edges()
	if next_id.is_empty():
		end_dialogue()
		return
	_go_to_node(next_id)


func _on_ui_option_selected(choice_index: int) -> void:
	choose_option(choice_index)


func _on_ui_close_requested() -> void:
	end_dialogue()


func _go_to_node(node_id: String) -> void:
	var trimmed: String = node_id.strip_edges()
	if trimmed.is_empty():
		end_dialogue()
		return
	if not _nodes.has(trimmed):
		push_warning("DialogueManager: node not found: %s/%s" % [_conversation_id, trimmed])
		end_dialogue()
		return
	_current_node_id = trimmed
	_refresh_current_node_view()


func _refresh_current_node_view() -> void:
	if not _active:
		return
	_ensure_ui()
	var node: Dictionary = _get_current_node()
	if node.is_empty():
		end_dialogue()
		return

	var line_text: String = String(node.get("text", node.get("line", ""))).strip_edges()
	if line_text.is_empty():
		line_text = "..."
	var speaker: String = String(node.get("speaker", _resolve_current_speaker())).strip_edges()
	if speaker.is_empty():
		speaker = _resolve_current_speaker()

	var options: Array[Dictionary] = []
	var choices_v: Variant = node.get("choices", [])
	if choices_v is Array:
		var choices: Array = choices_v as Array
		for i in range(choices.size()):
			var choice_v: Variant = choices[i]
			if not (choice_v is Dictionary):
				continue
			var choice: Dictionary = choice_v as Dictionary
			var choice_state: Dictionary = _evaluate_choice_state(choice)
			if not bool(choice_state.get("visible", true)):
				continue
			var choice_text: String = String(choice.get("text", choice.get("label", ""))).strip_edges()
			if choice_text.is_empty():
				choice_text = "(continue)"
			options.append({
				"choice_index": i,
				"text": choice_text,
				"enabled": bool(choice_state.get("enabled", true)),
				"reason": String(choice_state.get("reason", "")),
				"requirement": _choice_requirement_label(choice)
			})

	if options.is_empty():
		var auto_next: String = String(node.get("next", "")).strip_edges()
		options.append({
			"choice_index": -1,
			"text": "Continue." if not auto_next.is_empty() else "Goodbye.",
			"enabled": true,
			"reason": ""
		})

	_ui.show_dialogue(speaker, line_text, options, _build_node_view_settings(node))
	emit_signal("dialogue_node_changed", _conversation_id, _current_node_id)


func _get_current_node() -> Dictionary:
	if _current_node_id.is_empty():
		return {}
	if not _nodes.has(_current_node_id):
		return {}
	var node_v: Variant = _nodes[_current_node_id]
	if node_v is Dictionary:
		return node_v as Dictionary
	return {}


func _resolve_current_speaker() -> String:
	if not _speaker_override.is_empty():
		return _speaker_override
	var conv_speaker: String = String(_conversation.get("speaker", "")).strip_edges()
	if not conv_speaker.is_empty():
		return conv_speaker
	return "NPC"


func _evaluate_choice_state(choice: Dictionary) -> Dictionary:
	var reason: String = _first_unmet_requirement_reason(choice)
	if reason.is_empty():
		return {"visible": true, "enabled": true, "reason": ""}
	var hide_if_locked: bool = Util.to_bool(choice.get("hide_if_locked", false), false)
	return {
		"visible": not hide_if_locked,
		"enabled": false,
		"reason": reason
	}


func _first_unmet_requirement_reason(choice: Dictionary) -> String:
	for fact in _to_string_array(choice.get("require_fact", [])):
		if not has_fact(fact):
			return "Requires %s" % fact
	for fact in _to_string_array(choice.get("exclude_fact", [])):
		if has_fact(fact):
			return "Blocked by %s" % fact

	var skill_name: String = String(choice.get("skill", "")).strip_edges().to_lower()
	if not skill_name.is_empty() and choice.has("min_skill"):
		var min_skill: int = int(choice.get("min_skill", 0))
		if get_skill(skill_name, 0) < min_skill:
			return "%s %d required" % [skill_name.capitalize(), min_skill]

	var faction_name: String = String(choice.get("faction", "")).strip_edges().to_lower()
	if not faction_name.is_empty() and choice.has("min_faction_rep"):
		var min_rep: int = int(choice.get("min_faction_rep", 0))
		if get_faction_rep(faction_name, 0) < min_rep:
			return "%s rep %d required" % [faction_name.capitalize(), min_rep]

	for quest in _to_string_array(choice.get("require_quest", [])):
		if not has_started_quest(quest):
			return "Requires quest %s" % quest
	for quest in _to_string_array(choice.get("exclude_quest", [])):
		if has_started_quest(quest):
			return "Blocked by quest %s" % quest

	var min_quest_stage_v: Variant = choice.get("min_quest_stage", {})
	if min_quest_stage_v is Dictionary:
		var min_quest_stage := min_quest_stage_v as Dictionary
		for quest_key in min_quest_stage.keys():
			var quest_name: String = String(quest_key).strip_edges()
			var min_stage: int = int(min_quest_stage[quest_key])
			if get_quest_stage(quest_name, 0) < min_stage:
				return "%s stage %d required" % [quest_name, min_stage]
	return ""


func _choice_requirement_label(choice: Dictionary) -> String:
	var labels := PackedStringArray()

	var min_skill_name: String = String(choice.get("skill", "")).strip_edges().to_lower()
	if not min_skill_name.is_empty() and choice.has("min_skill"):
		labels.append("%s %d" % [min_skill_name.capitalize(), int(choice.get("min_skill", 0))])

	var check_skill_name: String = String(choice.get("check_skill", "")).strip_edges().to_lower()
	if not check_skill_name.is_empty() and choice.has("check_skill_min"):
		labels.append("%s %d" % [check_skill_name.capitalize(), int(choice.get("check_skill_min", 0))])

	var min_faction_name: String = String(choice.get("faction", "")).strip_edges().to_lower()
	if not min_faction_name.is_empty() and choice.has("min_faction_rep"):
		labels.append("%s rep %d" % [min_faction_name.capitalize(), int(choice.get("min_faction_rep", 0))])

	var min_quest_stage_v: Variant = choice.get("min_quest_stage", {})
	if min_quest_stage_v is Dictionary:
		var min_quest_stage := min_quest_stage_v as Dictionary
		for quest_key in min_quest_stage.keys():
			labels.append("%s stage %d" % [String(quest_key), int(min_quest_stage[quest_key])])

	var facts_required: PackedStringArray = _to_string_array(choice.get("require_fact", []))
	if not facts_required.is_empty():
		if facts_required.size() == 1:
			labels.append("fact:%s" % facts_required[0])
		else:
			labels.append("facts:%d" % facts_required.size())

	if labels.is_empty():
		return ""
	var joined: String = ""
	for i in range(labels.size()):
		if i > 0:
			joined += " | "
		joined += labels[i]
	return joined


func _build_node_view_settings(node: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var rate_v: Variant = node.get("line_reveal_rate", _conversation.get("line_reveal_rate", 90.0))
	out["line_reveal_rate"] = clampf(float(rate_v), 24.0, 320.0)
	out["show_hints"] = Util.to_bool(node.get("show_hints", _conversation.get("show_hints", true)), true)
	return out


func _resolve_next_node(choice: Dictionary) -> String:
	var next_id: String = String(choice.get("next", "")).strip_edges()
	var check_skill_name: String = String(choice.get("check_skill", "")).strip_edges().to_lower()
	if check_skill_name.is_empty():
		return next_id
	var check_min: int = int(choice.get("check_skill_min", 0))
	if get_skill(check_skill_name, 0) < check_min:
		var fail_next: String = String(choice.get("next_on_fail", "")).strip_edges()
		if not fail_next.is_empty():
			return fail_next
	return next_id


func _apply_choice_effects(choice: Dictionary) -> void:
	for fact in _to_string_array(choice.get("set_fact", [])):
		set_fact(fact, true)
	for fact in _to_string_array(choice.get("clear_fact", [])):
		set_fact(fact, false)

	var add_skill_v: Variant = choice.get("add_skill", {})
	if add_skill_v is Dictionary:
		var add_skill_map: Dictionary = add_skill_v as Dictionary
		for skill_key in add_skill_map.keys():
			add_skill(String(skill_key), int(add_skill_map[skill_key]))
	var set_skill_v: Variant = choice.get("set_skill", {})
	if set_skill_v is Dictionary:
		var set_skill_map: Dictionary = set_skill_v as Dictionary
		for skill_key in set_skill_map.keys():
			set_skill(String(skill_key), int(set_skill_map[skill_key]))

	var add_rep_v: Variant = choice.get("add_faction_rep", {})
	if add_rep_v is Dictionary:
		var add_rep: Dictionary = add_rep_v as Dictionary
		for faction_key in add_rep.keys():
			add_faction_rep(String(faction_key), int(add_rep[faction_key]))
	var set_rep_v: Variant = choice.get("set_faction_rep", {})
	if set_rep_v is Dictionary:
		var set_rep: Dictionary = set_rep_v as Dictionary
		for faction_key in set_rep.keys():
			set_faction_rep(String(faction_key), int(set_rep[faction_key]))

	var add_quest_stage_v: Variant = choice.get("add_quest_stage", {})
	if add_quest_stage_v is Dictionary:
		var add_quest_stage_map := add_quest_stage_v as Dictionary
		for quest_key in add_quest_stage_map.keys():
			add_quest_stage(String(quest_key), int(add_quest_stage_map[quest_key]))
	var set_quest_stage_v: Variant = choice.get("set_quest_stage", {})
	if set_quest_stage_v is Dictionary:
		var set_quest_stage_map := set_quest_stage_v as Dictionary
		for quest_key in set_quest_stage_map.keys():
			set_quest_stage(String(quest_key), int(set_quest_stage_map[quest_key]))

	var io_target: String = String(choice.get("io_target", "")).strip_edges()
	if not io_target.is_empty():
		var game := get_node_or_null("/root/GAME")
		if game != null and game.has_method("use_targets"):
			var input_name: String = String(choice.get("io_input", "use")).strip_edges()
			if input_name.is_empty():
				input_name = "use"
			var overrides: Dictionary = {"input": input_name}
			if choice.has("io_arg"):
				overrides["arg"] = choice["io_arg"]
			game.call("use_targets", _dialogue_activator if _dialogue_activator != null else self, io_target, overrides)


func _to_string_array(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is String:
		var single: String = String(value).strip_edges()
		if not single.is_empty():
			out.append(single)
		return out
	if value is PackedStringArray:
		for s in value:
			var v: String = String(s).strip_edges()
			if not v.is_empty():
				out.append(v)
		return out
	if value is Array:
		var arr: Array = value as Array
		for it in arr:
			var v: String = String(it).strip_edges()
			if not v.is_empty():
				out.append(v)
	return out


func _ensure_ui() -> void:
	if _ui != null and is_instance_valid(_ui):
		if not _ui.is_inside_tree():
			add_child(_ui)
		return
	_ui = DialogueUIScript.new()
	_ui.name = "DialogueUI"
	add_child(_ui)
	var on_option := Callable(self, "_on_ui_option_selected")
	if not _ui.option_selected.is_connected(on_option):
		_ui.option_selected.connect(on_option)
	var on_close := Callable(self, "_on_ui_close_requested")
	if not _ui.close_requested.is_connected(on_close):
		_ui.close_requested.connect(on_close)


func _begin_dialogue_focus() -> void:
	if _dialogue_activator == null:
		return
	if not _dialogue_activator.has_method("begin_dialogue_focus"):
		return
	_dialogue_activator.call_deferred("begin_dialogue_focus", _dialogue_source)


func _end_dialogue_focus() -> void:
	if _dialogue_activator == null:
		return
	if not _dialogue_activator.has_method("end_dialogue_focus"):
		return
	_dialogue_activator.call_deferred("end_dialogue_focus")


func _save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("dialogue", "facts", _facts)
	cfg.set_value("dialogue", "skills", _skills)
	cfg.set_value("dialogue", "faction_rep", _faction_rep)
	cfg.set_value("dialogue", "quest_stage", _quest_stage)
	_save_config_atomic(cfg, DIALOGUE_STATE_PATH, DIALOGUE_STATE_BACKUP_PATH, "dialogue_state")


func _save_config_atomic(cfg: ConfigFile, target_path: String, backup_path: String, label: String) -> bool:
	var tmp_path := target_path + ".tmp"
	var tmp_save_err := cfg.save(tmp_path)
	if tmp_save_err != OK:
		push_warning("DIALOGUE %s save failed (tmp): %s" % [label, str(tmp_save_err)])
		return false

	var abs_target := ProjectSettings.globalize_path(target_path)
	var abs_backup := ProjectSettings.globalize_path(backup_path)
	var abs_tmp := ProjectSettings.globalize_path(tmp_path)

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(abs_backup)
	if FileAccess.file_exists(target_path):
		var backup_err := DirAccess.rename_absolute(abs_target, abs_backup)
		if backup_err != OK:
			push_warning("DIALOGUE %s save failed (backup rotate): %s" % [label, str(backup_err)])
			DirAccess.remove_absolute(abs_tmp)
			return false

	var promote_err := DirAccess.rename_absolute(abs_tmp, abs_target)
	if promote_err != OK:
		push_warning("DIALOGUE %s save failed (promote tmp): %s" % [label, str(promote_err)])
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(target_path):
			DirAccess.rename_absolute(abs_backup, abs_target)
		return false

	return true


func _load_state() -> void:
	_facts.clear()
	_skills = {"speech": 25}
	_faction_rep.clear()
	_quest_stage.clear()
	var cfg := ConfigFile.new()
	var load_err := cfg.load(DIALOGUE_STATE_PATH)
	if load_err != OK:
		var backup_err := cfg.load(DIALOGUE_STATE_BACKUP_PATH)
		if backup_err != OK:
			return
		push_warning("DIALOGUE primary state load failed; using backup (%s)" % str(load_err))
	var facts_v: Variant = cfg.get_value("dialogue", "facts", {})
	if facts_v is Dictionary:
		_facts = facts_v as Dictionary
	var skills_v: Variant = cfg.get_value("dialogue", "skills", {})
	if skills_v is Dictionary:
		_skills = skills_v as Dictionary
	var reps_v: Variant = cfg.get_value("dialogue", "faction_rep", {})
	if reps_v is Dictionary:
		_faction_rep = reps_v as Dictionary
	var quest_v: Variant = cfg.get_value("dialogue", "quest_stage", {})
	if quest_v is Dictionary:
		_quest_stage = quest_v as Dictionary
