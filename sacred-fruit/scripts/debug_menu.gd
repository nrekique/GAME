extends Control

var search: LineEdit
var include_autosave: CheckBox
var map_list: ItemList
var status: Label
var build_run: Button
var photo_mode_button: Button
var close_button: Button

const MAP_ROOT := "res://tb"

var _paths: Array[String] = []


func _resolve_nodes() -> void:
	search = _find_node("Search", "LineEdit") as LineEdit
	include_autosave = _find_node("IncludeAutosave", "CheckBox") as CheckBox
	map_list = _find_node("MapList", "ItemList") as ItemList
	status = _find_node("Status", "Label") as Label
	build_run = _find_node("BuildRun", "Button") as Button
	photo_mode_button = _find_node("PhotoMode", "Button") as Button
	close_button = _find_node("Close", "Button") as Button


func _find_node(name_hint: String, type_hint: String) -> Node:
	# 1) Unique-name lookup
	var by_unique := get_node_or_null("%" + name_hint)
	if by_unique != null and (type_hint.is_empty() or by_unique.is_class(type_hint)):
		return by_unique

	# 2) Exact name anywhere
	var by_name := find_child(name_hint, true, false)
	if by_name != null and (type_hint.is_empty() or by_name.is_class(type_hint)):
		return by_name

	# 3) Substring match (for mangled names like "...#MapList")
	var any := find_children("*", type_hint, true, false)
	for n in any:
		if n != null and String(n.name).find(name_hint) != -1:
			return n
	return null


func _ready() -> void:
	visible = false
	# Don’t let the panel eat clicks behind it when hidden.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Ensure full-rect anchors for layout containers.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := get_node_or_null("Backdrop") as Control
	if backdrop:
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := get_node_or_null("Center") as Control
	if center:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_resolve_nodes()
	call_deferred("_ensure_layout_and_resolve")
	if search:
		search.text_changed.connect(_on_filter_changed)
	if include_autosave:
		include_autosave.toggled.connect(_on_filter_changed)
	if map_list:
		map_list.item_activated.connect(_on_item_activated)
	if build_run:
		build_run.pressed.connect(_on_build_run_pressed)
	if photo_mode_button:
		photo_mode_button.pressed.connect(_on_photo_mode_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)


func _ensure_layout_and_resolve() -> void:
	_ensure_layout()
	_resolve_nodes()


func _ensure_layout() -> void:
	var center := _get_or_create_container("Center", CenterContainer, self) as Control
	if center:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.layout_mode = 1

	var panel := _get_or_create_container("Panel", PanelContainer, center)
	var margin := _get_or_create_container("Margin", MarginContainer, panel)
	var vbox := _get_or_create_container("VBox", VBoxContainer, margin)
	if panel is Control:
		(panel as Control).layout_mode = 2
	if margin is Control:
		(margin as Control).layout_mode = 2
	if vbox is Control:
		(vbox as Control).layout_mode = 2
	if vbox is VBoxContainer:
		(vbox as VBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
		(vbox as VBoxContainer).add_theme_constant_override("separation", 10)

	if margin is MarginContainer:
		(margin as MarginContainer).add_theme_constant_override("margin_left", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_right", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_top", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_bottom", 24)

	var topbar := _get_or_create_container("TopBar", HBoxContainer, vbox)
	var buttons := _get_or_create_container("Buttons", HBoxContainer, vbox)
	if topbar is HBoxContainer:
		(topbar as HBoxContainer).add_theme_constant_override("separation", 10)
	if buttons is HBoxContainer:
		(buttons as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		(buttons as HBoxContainer).add_theme_constant_override("separation", 10)

	_reparent_by_name("Title", vbox)
	_reparent(topbar, vbox)
	_reparent_by_name("MapList", vbox)
	_reparent_by_name("Status", vbox)
	_reparent(buttons, vbox)
	var map_list_node := _find_node("MapList", "ItemList") as ItemList
	if map_list_node:
		map_list_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		map_list_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_list_node.custom_minimum_size = Vector2(0, 240)
		map_list_node.visible = true

	# Top bar children
	_reparent_by_name("Search", topbar)
	_reparent_by_name("IncludeAutosave", topbar)

	# Buttons row children
	_reparent_by_name("PhotoMode", buttons)
	_reparent_by_name("BuildRun", buttons)
	_reparent_by_name("Close", buttons)

	# Sweep stray controls that got dragged to root or Margin.
	var top_level := get_children().duplicate()
	for ch in top_level:
		if ch is Control and ch != center and ch.name != "Backdrop":
			_reparent(ch, vbox)
	var margin_children := margin.get_children().duplicate() if margin else []
	for ch in margin_children:
		if ch is Control and ch != vbox:
			_reparent(ch, vbox)


func refresh() -> void:
	_ensure_layout_and_resolve()
	if include_autosave == null or map_list == null or status == null or search == null:
		_resolve_nodes()
		if include_autosave == null or map_list == null or status == null or search == null:
			return
	_paths = _scan_maps(include_autosave.button_pressed)
	_apply_filter(search.text)
	status.text = "Found %d maps" % _paths.size()
	if map_list.item_count > 0:
		map_list.select(0)
		map_list.grab_focus()


func _on_filter_changed(_arg = null) -> void:
	if search:
		_apply_filter(search.text)


func _apply_filter(filter_text: String) -> void:
	if map_list == null:
		return
	map_list.clear()
	var f := filter_text.strip_edges().to_lower()
	for p in _paths:
		var map_name := p.get_file()
		var should_show := true
		if not f.is_empty():
			should_show = (p.to_lower().find(f) != -1) or (map_name.to_lower().find(f) != -1)
		if should_show:
			map_list.add_item(p.replace("res://", ""))


func _selected_map_path() -> String:
	if map_list == null:
		return ""
	var idx := map_list.get_selected_items()
	if idx.size() == 0:
		return ""
	var label := map_list.get_item_text(idx[0])
	if label.begins_with("res://"):
		return label
	return "res://" + label


func _on_item_activated(_index: int) -> void:
	_on_build_run_pressed()


func _on_build_run_pressed() -> void:
	if status == null:
		return
	var path := _selected_map_path()
	if path.is_empty():
		status.text = "No map selected"
		return
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".import"):
		status.text = "Missing file: %s" % path
		return

	status.text = "Launching runtime build: %s" % path
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("request_play_runtime_map"):
		dbg.call("request_play_runtime_map", path)
	else:
		status.text = "DEBUG autoload missing (/root/DEBUG)"


func _on_photo_mode_pressed() -> void:
	if status == null:
		return
	var path := _selected_map_path()
	if path.is_empty():
		status.text = "No map selected"
		return
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".import"):
		status.text = "Missing file: %s" % path
		return

	status.text = "Launching photo mode: %s" % path
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("request_photo_mode"):
		dbg.call("request_photo_mode", path)
	else:
		status.text = "DEBUG autoload missing (/root/DEBUG)"


func _on_close_pressed() -> void:
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("toggle_menu"):
		dbg.call("toggle_menu")
	else:
		visible = false


func _scan_maps(include_autosaves: bool) -> Array[String]:
	var results: Array[String] = []
	_scan_dir_recursive(MAP_ROOT, results, include_autosaves)
	results.sort()
	return results


func _scan_dir_recursive(dir_path: String, out: Array[String], include_autosaves: bool) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry_name := dir.get_next()
		if entry_name == "":
			break
		if entry_name.begins_with("."):
			continue
		var full := dir_path.path_join(entry_name)
		if dir.current_is_dir():
			# Skip irrelevant directories.
			if full.find("/textures/") != -1:
				continue
			if full.find("/fgd/") != -1:
				continue
			if (not include_autosaves) and full.find("/autosave") != -1:
				continue
			_scan_dir_recursive(full, out, include_autosaves)
		else:
			if not entry_name.to_lower().ends_with(".map"):
				continue
			# Avoid texture ‘.map’ files in tb/textures.
			if full.find("/textures/") != -1:
				continue
			out.append(full)

	dir.list_dir_end()


func _get_or_create_container(name: String, type_class: Variant, parent: Node) -> Node:
	if parent == null:
		return null
	var existing := parent.get_node_or_null(name)
	if existing != null:
		return existing
	var node: Node = type_class.new() as Node
	node.name = name
	parent.add_child(node)
	return node


func _reparent_by_name(name: String, new_parent: Node) -> void:
	if new_parent == null:
		return
	var node := find_child(name, true, false)
	if node != null:
		_reparent(node, new_parent)


func _reparent(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null:
		return
	if node.get_parent() == new_parent:
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)
