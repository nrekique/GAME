class_name DialogueMarkdown
extends RefCounted
const Util := preload("res://scripts/core/util.gd")

# Lightweight authoring format:
# - Conversation keys: @id, @speaker, @start, @line_reveal_rate, @show_hints
# - Node heading: ## node_id | speaker=Name | line_reveal_rate=90 | show_hints=true
# - Choice line: - Text -> target_node | key=value | key=value
# - Target END marks a terminal choice.


static func parse_conversation(raw_text: String, source_id: String = "") -> Dictionary:
	var conv: Dictionary = {
		"id": _default_conversation_id(source_id),
		"speaker": "NPC",
		"start": "",
		"nodes": {}
	}
	var errors := PackedStringArray()
	var lines: PackedStringArray = raw_text.replace("\r", "").split("\n")

	var current_node_id: String = ""
	var current_node: Dictionary = {}
	var current_text_lines := PackedStringArray()
	var first_node_id: String = ""

	for i in range(lines.size()):
		var line_no: int = i + 1
		var line: String = String(lines[i]).strip_edges()
		if line.is_empty():
			if not current_node_id.is_empty():
				current_text_lines.append("")
			continue
		if line.begins_with("<!--") and line.ends_with("-->"):
			continue
		if line.begins_with("//"):
			continue
		if line.begins_with("# ") and current_node_id.is_empty():
			continue
		if line.begins_with("## "):
			_finalize_node(conv, current_node_id, current_node, current_text_lines)
			current_text_lines.clear()
			current_node = {}
			current_node_id = _parse_node_header(line.substr(3).strip_edges(), current_node, line_no, errors)
			if current_node_id.is_empty():
				continue
			if first_node_id.is_empty():
				first_node_id = current_node_id
			continue
		if line.begins_with("@"):
			var directive: String = line.substr(1).strip_edges()
			if current_node_id.is_empty():
				_apply_conversation_directive(conv, directive, line_no, errors)
			else:
				_apply_node_directive(current_node, directive, line_no, errors)
			continue
		if current_node_id.is_empty():
			errors.append("Line %d: content before first node heading (## node_id)." % line_no)
			continue
		if line.begins_with("- "):
			var choice: Dictionary = _parse_choice_line(line.substr(2).strip_edges(), line_no, errors)
			if not choice.is_empty():
				var choices: Array = current_node.get("choices", [])
				choices.append(choice)
				current_node["choices"] = choices
			continue
		current_text_lines.append(line)

	_finalize_node(conv, current_node_id, current_node, current_text_lines)

	var nodes_v: Variant = conv.get("nodes", {})
	var nodes: Dictionary = {}
	if nodes_v is Dictionary:
		nodes = nodes_v as Dictionary
	if nodes.is_empty():
		errors.append("No dialogue nodes were parsed.")
	if String(conv.get("start", "")).strip_edges().is_empty():
		conv["start"] = first_node_id
	if String(conv.get("start", "")).strip_edges().is_empty():
		errors.append("Missing @start and no node headings found.")
	elif not nodes.has(String(conv.get("start", "")).strip_edges()):
		errors.append("Start node '%s' not found." % String(conv.get("start", "")).strip_edges())

	if errors.is_empty():
		return {
			"ok": true,
			"conversation": conv,
			"error": ""
		}
	return {
		"ok": false,
		"conversation": {},
		"error": errors[0]
	}


static func _default_conversation_id(source_id: String) -> String:
	var trimmed: String = source_id.strip_edges()
	if trimmed.is_empty():
		return "dialogue"
	var file_name: String = trimmed.get_file().get_basename()
	if file_name.is_empty():
		return "dialogue"
	return file_name


static func _parse_node_header(header_line: String, out_node: Dictionary, line_no: int, errors: PackedStringArray) -> String:
	var parts: PackedStringArray = header_line.split("|")
	if parts.is_empty():
		errors.append("Line %d: invalid node heading." % line_no)
		return ""
	var node_id: String = String(parts[0]).strip_edges()
	if node_id.is_empty():
		errors.append("Line %d: node heading missing node id." % line_no)
		return ""
	for idx in range(1, parts.size()):
		var piece: String = String(parts[idx]).strip_edges()
		if piece.is_empty():
			continue
		_apply_node_directive(out_node, piece, line_no, errors)
	return node_id


static func _apply_conversation_directive(conv: Dictionary, directive: String, line_no: int, errors: PackedStringArray) -> void:
	var pair: Dictionary = _split_key_value(directive)
	if pair.is_empty():
		errors.append("Line %d: invalid conversation directive '%s'." % [line_no, directive])
		return
	var key: String = String(pair.get("key", "")).to_lower()
	var value: String = String(pair.get("value", ""))
	match key:
		"id", "speaker", "start":
			conv[key] = value.strip_edges()
		"line_reveal_rate":
			conv[key] = float(value)
		"show_hints":
			conv[key] = Util.to_bool(value, true)
		_:
			conv[key] = _parse_scalar(value)


static func _apply_node_directive(node: Dictionary, directive: String, line_no: int, errors: PackedStringArray) -> void:
	var pair: Dictionary = _split_key_value(directive)
	if pair.is_empty():
		errors.append("Line %d: invalid node directive '%s'." % [line_no, directive])
		return
	var key: String = String(pair.get("key", "")).to_lower()
	var value: String = String(pair.get("value", "")).strip_edges()
	match key:
		"speaker":
			node["speaker"] = value
		"line_reveal_rate":
			node["line_reveal_rate"] = float(value)
		"show_hints":
			node["show_hints"] = Util.to_bool(value, true)
		"text", "line":
			node["text"] = value
		"next":
			node["next"] = value
		_:
			node[key] = _parse_scalar(value)


static func _parse_choice_line(choice_line: String, line_no: int, errors: PackedStringArray) -> Dictionary:
	var arrow_idx: int = choice_line.find("->")
	if arrow_idx == -1:
		errors.append("Line %d: choice is missing '-> target'." % line_no)
		return {}
	var choice_text: String = choice_line.substr(0, arrow_idx).strip_edges()
	if choice_text.is_empty():
		errors.append("Line %d: choice text is empty." % line_no)
		return {}
	var rhs: String = choice_line.substr(arrow_idx + 2).strip_edges()
	if rhs.is_empty():
		errors.append("Line %d: choice target is empty." % line_no)
		return {}

	var segments: PackedStringArray = rhs.split("|")
	var target: String = String(segments[0]).strip_edges()
	var choice: Dictionary = {"text": choice_text}
	if target.to_upper() == "END":
		choice["end"] = true
	else:
		choice["next"] = target

	for idx in range(1, segments.size()):
		var seg: String = String(segments[idx]).strip_edges()
		if seg.is_empty():
			continue
		var pair: Dictionary = _split_key_value(seg)
		if pair.is_empty():
			errors.append("Line %d: invalid choice attribute '%s'." % [line_no, seg])
			continue
		var key: String = String(pair.get("key", "")).to_lower()
		var value: String = String(pair.get("value", "")).strip_edges()
		_apply_choice_attribute(choice, key, value)
	return choice


static func _apply_choice_attribute(choice: Dictionary, key: String, raw_value: String) -> void:
	match key:
		"next", "next_on_fail", "check_skill", "skill", "faction", "io_target", "io_input", "io_arg":
			choice[key] = raw_value
		"check_skill_min", "min_skill", "min_faction_rep":
			choice[key] = int(raw_value)
		"hide_if_locked", "end":
			choice[key] = Util.to_bool(raw_value, false)
		"require_fact", "exclude_fact", "set_fact", "clear_fact", "require_quest", "exclude_quest":
			choice[key] = _parse_string_list(raw_value)
		"add_skill", "set_skill", "add_faction_rep", "set_faction_rep", "add_quest_stage", "set_quest_stage", "min_quest_stage":
			choice[key] = _parse_number_map(raw_value)
		_:
			choice[key] = _parse_scalar(raw_value)


static func _parse_string_list(raw_value: String) -> Array[String]:
	var out: Array[String] = []
	var parts: PackedStringArray = raw_value.split(",")
	for part in parts:
		var item: String = String(part).strip_edges()
		if not item.is_empty():
			out.append(item)
	return out


static func _parse_number_map(raw_value: String) -> Dictionary:
	var out: Dictionary = {}
	var parts: PackedStringArray = raw_value.split(",")
	for part in parts:
		var item: String = String(part).strip_edges()
		if item.is_empty():
			continue
		var sep_idx: int = item.find(":")
		if sep_idx == -1:
			sep_idx = item.find("=")
		if sep_idx == -1:
			continue
		var key: String = item.substr(0, sep_idx).strip_edges()
		var value_s: String = item.substr(sep_idx + 1).strip_edges()
		if key.is_empty() or value_s.is_empty():
			continue
		out[key] = int(value_s)
	return out


static func _parse_scalar(raw_value: String) -> Variant:
	var value: String = raw_value.strip_edges()
	var lower: String = value.to_lower()
	if lower in ["true", "false", "yes", "no", "on", "off", "1", "0"]:
		return Util.to_bool(value, false)
	if _looks_like_int(value):
		return int(value)
	if _looks_like_float(value):
		return float(value)
	return value


static func _looks_like_int(value: String) -> bool:
	if value.is_empty():
		return false
	var start: int = 0
	if value.begins_with("+") or value.begins_with("-"):
		if value.length() == 1:
			return false
		start = 1
	for i in range(start, value.length()):
		var c: String = value.substr(i, 1)
		if c < "0" or c > "9":
			return false
	return true


static func _looks_like_float(value: String) -> bool:
	if value.is_empty():
		return false
	if value.find(".") == -1:
		return false
	return value.is_valid_float()


static func _split_key_value(text: String) -> Dictionary:
	var work: String = text.strip_edges()
	var sep_idx: int = work.find(":")
	var eq_idx: int = work.find("=")
	if eq_idx != -1 and (sep_idx == -1 or eq_idx < sep_idx):
		sep_idx = eq_idx
	if sep_idx == -1:
		return {}
	var key: String = work.substr(0, sep_idx).strip_edges()
	var value: String = work.substr(sep_idx + 1).strip_edges()
	if key.is_empty():
		return {}
	return {"key": key, "value": value}


static func _finalize_node(conv: Dictionary, node_id: String, node: Dictionary, text_lines: PackedStringArray) -> void:
	if node_id.is_empty():
		return
	if not node.has("text"):
		var text: String = _join_text_lines(text_lines).strip_edges()
		if text.is_empty():
			text = "..."
		node["text"] = text
	var nodes_v: Variant = conv.get("nodes", {})
	var nodes: Dictionary = {}
	if nodes_v is Dictionary:
		nodes = nodes_v as Dictionary
	nodes[node_id] = node
	conv["nodes"] = nodes


static func _join_text_lines(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return ""
	var out := PackedStringArray(lines)
	while not out.is_empty() and String(out[out.size() - 1]).strip_edges().is_empty():
		out.remove_at(out.size() - 1)
	if out.is_empty():
		return ""
	var joined: String = ""
	for i in range(out.size()):
		if i > 0:
			joined += "\n"
		joined += String(out[i])
	return joined
