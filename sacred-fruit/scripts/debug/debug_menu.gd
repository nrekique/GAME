extends Control

var search: LineEdit
var include_autosave: CheckBox
var map_list: ItemList
var model_filter: LineEdit
var model_list: ItemList
var model_scale: LineEdit
var size_mode: OptionButton
var manual_size_x: LineEdit
var manual_size_y: LineEdit
var manual_size_z: LineEdit
var tb_config_path: LineEdit
var generate_prop_button: Button
var generate_actor_button: Button
var status: Label
var build_run: Button
var photo_mode_button: Button
var close_button: Button

const MAP_ROOT := "res://tb/maps"
const MAP_AUTOSAVE_ROOT := "res://tb/autosave"
const MODEL_ROOT := "res://tb/models"
const FGD_POINT_FILE := "res://tb/fgd/fgd_point.tres"
const GENERATED_FGD_DIR := "res://tb/fgd/point/generated"
const GENERATED_SCENE_DIR := "res://entities/generated"
const GENERATED_MODEL_SCRIPT := "res://entities/generated/generated_model_static.gd"
const POINT_CLASS_SCRIPT := "res://addons/func_godot/src/fgd/func_godot_fgd_point_class.gd"
const TARGETNAME_BASE_CLASS := "res://tb/fgd/base/targetname_base.tres"
const ACTOR_BASE_CLASS := "res://tb/fgd/base/actor_base.tres"
const MAIN_FGD_FILE := "res://tb/fgd/sf_fgd.tres"
const TB_GAME_CONFIG_FILE := "res://tb/fgd/sfGameConfig.tres"
const TB_GAME_FOLDER_DEFAULT := "/Users/nre/Library/Application Support/TrenchBroom/games/sacredFruit"
const TRENCHBROOM_EDITOR_TARGET := 1

var _paths: Array[String] = []
var _model_paths: Array[String] = []


func _resolve_nodes() -> void:
	search = _find_node("Search", "LineEdit") as LineEdit
	include_autosave = _find_node("IncludeAutosave", "CheckBox") as CheckBox
	map_list = _find_node("MapList", "ItemList") as ItemList
	model_filter = _find_node("ModelFilter", "LineEdit") as LineEdit
	model_list = _find_node("ModelList", "ItemList") as ItemList
	model_scale = _find_node("ModelScale", "LineEdit") as LineEdit
	size_mode = _find_node("SizeMode", "OptionButton") as OptionButton
	manual_size_x = _find_node("ManualSizeX", "LineEdit") as LineEdit
	manual_size_y = _find_node("ManualSizeY", "LineEdit") as LineEdit
	manual_size_z = _find_node("ManualSizeZ", "LineEdit") as LineEdit
	tb_config_path = _find_node("TBConfigPath", "LineEdit") as LineEdit
	generate_prop_button = _find_node("GeneratePropEntity", "Button") as Button
	generate_actor_button = _find_node("GenerateActorEntity", "Button") as Button
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
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := get_node_or_null("Backdrop") as Control
	if backdrop:
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := get_node_or_null("Center") as Control
	if center:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_resolve_nodes()
	call_deferred("_ensure_layout_and_resolve")


func _ensure_layout_and_resolve() -> void:
	_ensure_layout()
	_resolve_nodes()
	_connect_signals()
	_update_size_mode_state()


func _connect_signals() -> void:
	if search and not search.is_connected("text_changed", Callable(self, "_on_map_filter_changed")):
		search.text_changed.connect(_on_map_filter_changed)
	if include_autosave and not include_autosave.is_connected("toggled", Callable(self, "_on_map_filter_changed")):
		include_autosave.toggled.connect(_on_map_filter_changed)
	if map_list and not map_list.is_connected("item_activated", Callable(self, "_on_item_activated")):
		map_list.item_activated.connect(_on_item_activated)
	if model_filter and not model_filter.is_connected("text_changed", Callable(self, "_on_model_filter_changed")):
		model_filter.text_changed.connect(_on_model_filter_changed)
	if model_list and not model_list.is_connected("item_activated", Callable(self, "_on_model_item_activated")):
		model_list.item_activated.connect(_on_model_item_activated)
	if size_mode and not size_mode.is_connected("item_selected", Callable(self, "_on_size_mode_changed")):
		size_mode.item_selected.connect(_on_size_mode_changed)
	if build_run and not build_run.is_connected("pressed", Callable(self, "_on_build_run_pressed")):
		build_run.pressed.connect(_on_build_run_pressed)
	if photo_mode_button and not photo_mode_button.is_connected("pressed", Callable(self, "_on_photo_mode_pressed")):
		photo_mode_button.pressed.connect(_on_photo_mode_pressed)
	if close_button and not close_button.is_connected("pressed", Callable(self, "_on_close_pressed")):
		close_button.pressed.connect(_on_close_pressed)
	if generate_prop_button and not generate_prop_button.is_connected("pressed", Callable(self, "_on_generate_prop_pressed")):
		generate_prop_button.pressed.connect(_on_generate_prop_pressed)
	if generate_actor_button and not generate_actor_button.is_connected("pressed", Callable(self, "_on_generate_actor_pressed")):
		generate_actor_button.pressed.connect(_on_generate_actor_pressed)


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
	var model_header := _get_or_create_container("ModelHeader", Label, vbox) as Label
	if model_header:
		model_header.text = "Model Entity Generator (TrenchBroom FGD)"
	var model_topbar := _get_or_create_container("ModelTopBar", HBoxContainer, vbox)
	var model_options := _get_or_create_container("ModelOptions", VBoxContainer, vbox)
	var model_buttons := _get_or_create_container("ModelButtons", HBoxContainer, vbox)
	var buttons := _get_or_create_container("Buttons", HBoxContainer, vbox)

	if topbar is HBoxContainer:
		(topbar as HBoxContainer).add_theme_constant_override("separation", 10)
	if model_topbar is HBoxContainer:
		(model_topbar as HBoxContainer).add_theme_constant_override("separation", 10)
	if model_options is VBoxContainer:
		(model_options as VBoxContainer).add_theme_constant_override("separation", 6)
	if model_buttons is HBoxContainer:
		(model_buttons as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		(model_buttons as HBoxContainer).add_theme_constant_override("separation", 10)
	if buttons is HBoxContainer:
		(buttons as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		(buttons as HBoxContainer).add_theme_constant_override("separation", 10)

	var model_filter_node := _get_or_create_container("ModelFilter", LineEdit, model_topbar) as LineEdit
	if model_filter_node:
		model_filter_node.placeholder_text = "Filter models (glb/gltf)..."
		model_filter_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var model_list_node := _get_or_create_container("ModelList", ItemList, vbox) as ItemList
	if model_list_node:
		model_list_node.allow_reselect = true
		model_list_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		model_list_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		model_list_node.custom_minimum_size = Vector2(0, 170)

	var scale_row := _get_or_create_container("ScaleRow", HBoxContainer, model_options)
	if scale_row is HBoxContainer:
		(scale_row as HBoxContainer).add_theme_constant_override("separation", 8)

	var scale_label := _get_or_create_container("ScaleLabel", Label, scale_row) as Label
	if scale_label:
		scale_label.text = "Uniform Scale"

	var model_scale_node := _get_or_create_container("ModelScale", LineEdit, scale_row) as LineEdit
	if model_scale_node:
		model_scale_node.custom_minimum_size = Vector2(90, 0)
		if model_scale_node.text.strip_edges().is_empty():
			model_scale_node.text = "1.0"

	var size_mode_label := _get_or_create_container("SizeModeLabel", Label, scale_row) as Label
	if size_mode_label:
		size_mode_label.text = "Collision"

	var size_mode_node := _get_or_create_container("SizeMode", OptionButton, scale_row) as OptionButton
	if size_mode_node:
		if size_mode_node.item_count == 0:
			size_mode_node.add_item("Auto from Mesh AABB")
			size_mode_node.add_item("Manual Size")
		if size_mode_node.selected == -1:
			size_mode_node.select(0)
		size_mode_node.custom_minimum_size = Vector2(200, 0)

	var manual_row := _get_or_create_container("ManualSizeRow", HBoxContainer, model_options)
	if manual_row is HBoxContainer:
		(manual_row as HBoxContainer).add_theme_constant_override("separation", 8)

	var manual_label := _get_or_create_container("ManualSizeLabel", Label, manual_row) as Label
	if manual_label:
		manual_label.text = "Manual Size (X Y Z)"

	var manual_x_node := _get_or_create_container("ManualSizeX", LineEdit, manual_row) as LineEdit
	if manual_x_node:
		manual_x_node.custom_minimum_size = Vector2(70, 0)
		if manual_x_node.text.strip_edges().is_empty():
			manual_x_node.text = "32"
	var manual_y_node := _get_or_create_container("ManualSizeY", LineEdit, manual_row) as LineEdit
	if manual_y_node:
		manual_y_node.custom_minimum_size = Vector2(70, 0)
		if manual_y_node.text.strip_edges().is_empty():
			manual_y_node.text = "32"
	var manual_z_node := _get_or_create_container("ManualSizeZ", LineEdit, manual_row) as LineEdit
	if manual_z_node:
		manual_z_node.custom_minimum_size = Vector2(70, 0)
		if manual_z_node.text.strip_edges().is_empty():
			manual_z_node.text = "32"

	var tb_row := _get_or_create_container("TBPathRow", HBoxContainer, model_options)
	if tb_row is HBoxContainer:
		(tb_row as HBoxContainer).add_theme_constant_override("separation", 8)

	var tb_label := _get_or_create_container("TBPathLabel", Label, tb_row) as Label
	if tb_label:
		tb_label.text = "TB Game Folder"

	var tb_path_node := _get_or_create_container("TBConfigPath", LineEdit, tb_row) as LineEdit
	if tb_path_node:
		tb_path_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if tb_path_node.text.strip_edges().is_empty():
			tb_path_node.text = TB_GAME_FOLDER_DEFAULT

	var gen_prop := _get_or_create_container("GeneratePropEntity", Button, model_buttons) as Button
	if gen_prop:
		gen_prop.text = "Generate Prop Entity"
	var gen_actor := _get_or_create_container("GenerateActorEntity", Button, model_buttons) as Button
	if gen_actor:
		gen_actor.text = "Generate Actor Entity"

	_reparent_by_name("Title", vbox)
	_reparent(topbar, vbox)
	_reparent_by_name("MapList", vbox)
	_reparent_by_name("ModelHeader", vbox)
	_reparent(model_topbar, vbox)
	_reparent_by_name("ModelList", vbox)
	_reparent(model_options, vbox)
	_reparent(model_buttons, vbox)
	_reparent_by_name("Status", vbox)
	_reparent(buttons, vbox)

	var map_list_node := _find_node("MapList", "ItemList") as ItemList
	if map_list_node:
		map_list_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		map_list_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_list_node.custom_minimum_size = Vector2(0, 220)
		map_list_node.visible = true

	# Top bar children
	_reparent_by_name("Search", topbar)
	_reparent_by_name("IncludeAutosave", topbar)

	# Model rows
	_reparent_by_name("ModelFilter", model_topbar)
	_reparent_by_name("ScaleRow", model_options)
	_reparent_by_name("ManualSizeRow", model_options)
	_reparent_by_name("TBPathRow", model_options)
	_reparent_by_name("GeneratePropEntity", model_buttons)
	_reparent_by_name("GenerateActorEntity", model_buttons)

	# Bottom buttons row children
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
	_model_paths = _scan_models()
	_apply_map_filter(search.text)
	_apply_model_filter(model_filter.text if model_filter else "")
	status.text = "Found %d maps and %d models" % [_paths.size(), _model_paths.size()]
	if map_list.item_count > 0:
		map_list.select(0)
	if model_list and model_list.item_count > 0:
		model_list.select(0)


func _on_map_filter_changed(_arg = null) -> void:
	if search:
		_apply_map_filter(search.text)


func _on_model_filter_changed(_arg = null) -> void:
	if model_filter:
		_apply_model_filter(model_filter.text)


func _on_size_mode_changed(_index: int) -> void:
	_update_size_mode_state()


func _update_size_mode_state() -> void:
	var manual_enabled := _size_mode_is_manual()
	_set_line_edit_enabled(manual_size_x, manual_enabled)
	_set_line_edit_enabled(manual_size_y, manual_enabled)
	_set_line_edit_enabled(manual_size_z, manual_enabled)


func _set_line_edit_enabled(line_edit: LineEdit, enabled: bool) -> void:
	if line_edit == null:
		return
	line_edit.editable = enabled
	line_edit.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(0.65, 0.65, 0.65, 1.0)


func _apply_map_filter(filter_text: String) -> void:
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
			var label := p.replace("res://", "")
			map_list.add_item(label)
			map_list.set_item_metadata(map_list.item_count - 1, p)


func _apply_model_filter(filter_text: String) -> void:
	if model_list == null:
		return
	model_list.clear()
	var f := filter_text.strip_edges().to_lower()
	for p in _model_paths:
		var model_name := p.get_file()
		var should_show := true
		if not f.is_empty():
			should_show = (p.to_lower().find(f) != -1) or (model_name.to_lower().find(f) != -1)
		if should_show:
			var label := p.replace("res://", "")
			model_list.add_item(label)
			model_list.set_item_metadata(model_list.item_count - 1, p)


func _selected_map_path() -> String:
	if map_list == null:
		return ""
	var idx := map_list.get_selected_items()
	if idx.size() == 0:
		return ""
	var meta: Variant = map_list.get_item_metadata(idx[0])
	if meta is String:
		return String(meta)
	var label := map_list.get_item_text(idx[0])
	if label.begins_with("res://"):
		return label
	return "res://" + label


func _selected_model_path() -> String:
	if model_list == null:
		return ""
	var idx := model_list.get_selected_items()
	if idx.size() == 0:
		return ""
	var meta: Variant = model_list.get_item_metadata(idx[0])
	if meta is String:
		return String(meta)
	var label := model_list.get_item_text(idx[0])
	if label.begins_with("res://"):
		return label
	return "res://" + label


func _on_item_activated(_index: int) -> void:
	_on_build_run_pressed()


func _on_model_item_activated(_index: int) -> void:
	_on_generate_prop_pressed()


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


func _on_generate_prop_pressed() -> void:
	_generate_model_entity(false)


func _on_generate_actor_pressed() -> void:
	_generate_model_entity(true)


func _generate_model_entity(as_actor: bool) -> void:
	if status == null:
		return
	var model_path := _selected_model_path()
	if model_path.is_empty():
		status.text = "No model selected"
		return
	if not FileAccess.file_exists(model_path) and not FileAccess.file_exists(model_path + ".import"):
		status.text = "Missing model: %s" % model_path
		return

	var model_scene := load(model_path) as PackedScene
	if model_scene == null:
		status.text = "Model not loadable as PackedScene: %s" % model_path.get_file()
		return

	var wrapper_script := load(GENERATED_MODEL_SCRIPT) as Script
	if wrapper_script == null:
		status.text = "Missing wrapper script: %s" % GENERATED_MODEL_SCRIPT
		return

	var point_script := load(POINT_CLASS_SCRIPT) as Script
	if point_script == null:
		status.text = "Missing point class script: %s" % POINT_CLASS_SCRIPT
		return

	var point_fgd := load(FGD_POINT_FILE) as Resource
	if point_fgd == null:
		status.text = "Missing FGD: %s" % FGD_POINT_FILE
		return

	var model_name := _sanitize_token(model_path.get_file().get_basename())
	var classname := "prop_" + model_name
	if as_actor:
		classname = "actor_" + model_name

	var entity_res_path := GENERATED_FGD_DIR.path_join("%s.tres" % classname)
	var scene_res_path := GENERATED_SCENE_DIR.path_join("%s.tscn" % classname)

	var scale_factor := _read_uniform_scale()
	var auto_meta := _compute_model_size_meta(model_scene)
	var scaled_auto_meta := _scale_size_meta(auto_meta, scale_factor)
	var auto_center := _size_meta_center(scaled_auto_meta)
	var auto_size := _size_meta_dimensions(scaled_auto_meta)

	var use_manual_size := _size_mode_is_manual()
	var manual_size := _read_manual_size(auto_size)
	var final_size := manual_size if use_manual_size else auto_size
	var final_meta := _make_size_meta_from_center_and_size(auto_center, final_size)

	var collision_from_aabb := not use_manual_size
	var collision_size := final_size
	var collision_offset := Vector3.ZERO
	if use_manual_size:
		collision_offset = auto_center
		if scale_factor > 0.0001:
			collision_size /= scale_factor
			collision_offset /= scale_factor

	var wrapper_scene := _build_wrapper_scene(
		wrapper_script,
		model_scene,
		collision_from_aabb,
		collision_size,
		collision_offset,
		scale_factor
	)
	if wrapper_scene == null:
		status.text = "Failed creating wrapper scene for %s" % model_path.get_file()
		return

	var scene_dir_err := _ensure_res_dir(GENERATED_SCENE_DIR)
	if scene_dir_err != OK and scene_dir_err != ERR_ALREADY_EXISTS:
		status.text = "Failed creating generated scene dir (%s)" % str(scene_dir_err)
		return
	var fgd_dir_err := _ensure_res_dir(GENERATED_FGD_DIR)
	if fgd_dir_err != OK and fgd_dir_err != ERR_ALREADY_EXISTS:
		status.text = "Failed creating generated FGD dir (%s)" % str(fgd_dir_err)
		return

	var save_wrapper_err := ResourceSaver.save(wrapper_scene, scene_res_path)
	if save_wrapper_err != OK:
		status.text = "Failed saving wrapper scene (%s)" % str(save_wrapper_err)
		return
	var saved_wrapper_scene := load(scene_res_path) as PackedScene
	if saved_wrapper_scene == null:
		saved_wrapper_scene = wrapper_scene

	var entity_def := load(entity_res_path) as Resource
	if entity_def == null:
		entity_def = point_script.new() as Resource
	if entity_def == null:
		status.text = "Failed creating point class resource"
		return

	var base_class_path := TARGETNAME_BASE_CLASS
	if as_actor:
		base_class_path = ACTOR_BASE_CLASS
	var base_class_res := load(base_class_path) as Resource
	if base_class_res == null:
		status.text = "Missing base class: %s" % base_class_path
		return

	var model_meta_path := _model_path_for_meta(model_path)
	var debug_color := Color(0.92, 0.78, 0.34, 1.0)
	if as_actor:
		debug_color = Color(0.45, 0.78, 0.96, 1.0)

	entity_def.set("classname", classname)
	entity_def.set("description", "Auto-generated from %s" % model_path.get_file())
	entity_def.set("func_godot_internal", false)
	entity_def.set("base_classes", [base_class_res])
	entity_def.set("class_properties", {
		"scale": 1.0
	})
	entity_def.set("class_property_descriptions", {
		"scale": "Uniform scale multiplier. 1.0 keeps authored size."
	})
	entity_def.set("auto_apply_to_matching_node_properties", false)
	entity_def.set("meta_properties", {
		"model": "\"%s\"" % model_meta_path,
		"size": final_meta,
		"color": debug_color
	})
	entity_def.set("node_class", "")
	entity_def.set("name_property", "")
	entity_def.set("scene_file", saved_wrapper_scene)
	entity_def.set("apply_rotation_on_map_build", true)
	entity_def.set("apply_scale_on_map_build", true)

	var save_entity_err := ResourceSaver.save(entity_def, entity_res_path)
	if save_entity_err != OK:
		status.text = "Failed saving entity def (%s)" % str(save_entity_err)
		return
	var saved_entity := load(entity_res_path) as Resource
	if saved_entity == null:
		saved_entity = entity_def

	_upsert_entity_definition(point_fgd, saved_entity, classname)
	var save_fgd_err := ResourceSaver.save(point_fgd, FGD_POINT_FILE)
	if save_fgd_err != OK:
		status.text = "Saved entity, but failed to update fgd_point.tres (%s)" % str(save_fgd_err)
		return

	var export_err := _export_trenchbroom_bundle(_read_tb_config_path())
	if export_err.is_empty():
		status.text = "Generated %s from %s and exported TrenchBroom config." % [classname, model_path.get_file()]
	else:
		status.text = "Generated %s, but TB export failed: %s" % [classname, export_err]


func _build_wrapper_scene(
	wrapper_script: Script,
	model_scene: PackedScene,
	collision_from_aabb: bool,
	collision_size: Vector3,
	collision_offset: Vector3,
	uniform_scale: float
) -> PackedScene:
	if wrapper_script == null or model_scene == null:
		return null

	var root := StaticBody3D.new()
	root.name = "GeneratedModelStatic"
	root.set_script(wrapper_script)
	root.set("model_scene", model_scene)
	root.set("collision_from_model_aabb", collision_from_aabb)
	root.set("collision_size", collision_size)
	root.set("collision_offset", collision_offset)
	root.scale = Vector3.ONE * maxf(uniform_scale, 0.001)

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.free()
	if pack_err != OK:
		return null
	return packed


func _upsert_entity_definition(point_fgd: Resource, entity_def: Resource, classname: String) -> void:
	var defs_variant: Variant = point_fgd.get("entity_definitions")
	var defs: Array = []
	if defs_variant is Array:
		defs = (defs_variant as Array).duplicate()
	var replaced := false
	for i in range(defs.size()):
		var def_item: Variant = defs[i]
		if not (def_item is Resource):
			continue
		var def_res := def_item as Resource
		if String(def_res.get("classname")) == classname:
			defs[i] = entity_def
			replaced = true
			break
	if not replaced:
		defs.append(entity_def)
	point_fgd.set("entity_definitions", defs)


func _model_path_for_meta(model_path: String) -> String:
	var rel := model_path
	var prefix := MODEL_ROOT + "/"
	if model_path.begins_with(prefix):
		rel = model_path.substr(prefix.length())
	else:
		rel = model_path.get_file()
	return "models/%s" % rel


func _compute_model_size_meta(scene: PackedScene) -> AABB:
	var fallback := AABB(Vector3(-8, -8, -8), Vector3(8, 8, 8))
	if scene == null:
		return fallback
	var root := scene.instantiate()
	if root == null:
		return fallback

	var mins := Vector3(1000000.0, 1000000.0, 1000000.0)
	var maxs := Vector3(-1000000.0, -1000000.0, -1000000.0)
	var found_mesh := false

	var stack: Array[Node] = []
	stack.append(root)
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh != null:
				var mesh_aabb := mesh_node.mesh.get_aabb()
				var corners := _aabb_corners(mesh_aabb)
				for c in corners:
					var p := mesh_node.global_transform * c
					mins.x = minf(mins.x, p.x)
					mins.y = minf(mins.y, p.y)
					mins.z = minf(mins.z, p.z)
					maxs.x = maxf(maxs.x, p.x)
					maxs.y = maxf(maxs.y, p.y)
					maxs.z = maxf(maxs.z, p.z)
				found_mesh = true
		for child in node.get_children():
			if child is Node:
				stack.append(child as Node)

	root.free()

	if not found_mesh:
		return fallback

	var min_i := Vector3(floor(mins.x), floor(mins.y), floor(mins.z))
	var max_i := Vector3(ceil(maxs.x), ceil(maxs.y), ceil(maxs.z))
	for axis in 3:
		if max_i[axis] <= min_i[axis]:
			max_i[axis] = min_i[axis] + 8.0
	return AABB(min_i, max_i)


func _scale_size_meta(size_meta: AABB, uniform_scale: float) -> AABB:
	var f := maxf(uniform_scale, 0.001)
	return AABB(size_meta.position * f, size_meta.size * f)


func _size_meta_center(size_meta: AABB) -> Vector3:
	return (size_meta.position + size_meta.size) * 0.5


func _size_meta_dimensions(size_meta: AABB) -> Vector3:
	var size := size_meta.size - size_meta.position
	size.x = maxf(absf(size.x), 0.1)
	size.y = maxf(absf(size.y), 0.1)
	size.z = maxf(absf(size.z), 0.1)
	return size


func _make_size_meta_from_center_and_size(center: Vector3, size: Vector3) -> AABB:
	var final_size := Vector3(maxf(size.x, 0.1), maxf(size.y, 0.1), maxf(size.z, 0.1))
	var half := final_size * 0.5
	var mins := center - half
	var maxs := center + half
	return AABB(mins, maxs)


func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p := aabb.position
	var s := aabb.size
	return [
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, s.y, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, s.y, 0.0),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(0.0, s.y, s.z),
		p + Vector3(s.x, s.y, s.z),
	]


func _sanitize_token(raw: String) -> String:
	var lower := raw.to_lower()
	var out := ""
	for i in lower.length():
		var ch := lower.substr(i, 1)
		var is_alpha := ch >= "a" and ch <= "z"
		var is_digit := ch >= "0" and ch <= "9"
		if is_alpha or is_digit or ch == "_":
			out += ch
		else:
			out += "_"
	while out.find("__") != -1:
		out = out.replace("__", "_")
	while out.begins_with("_"):
		out = out.substr(1)
	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	if out.is_empty():
		return "model"
	return out


func _size_mode_is_manual() -> bool:
	return size_mode != null and size_mode.selected == 1


func _read_uniform_scale() -> float:
	var value := _line_float(model_scale, 1.0)
	return maxf(value, 0.001)


func _read_manual_size(fallback: Vector3) -> Vector3:
	var sx := _line_float(manual_size_x, fallback.x)
	var sy := _line_float(manual_size_y, fallback.y)
	var sz := _line_float(manual_size_z, fallback.z)
	return Vector3(maxf(sx, 0.1), maxf(sy, 0.1), maxf(sz, 0.1))


func _line_float(line_edit: LineEdit, fallback: float) -> float:
	if line_edit == null:
		return fallback
	var raw := line_edit.text.strip_edges()
	if raw.is_empty():
		return fallback
	if not raw.is_valid_float():
		return fallback
	return raw.to_float()


func _read_tb_config_path() -> String:
	if tb_config_path:
		var path := tb_config_path.text.strip_edges()
		if not path.is_empty():
			return path
	return TB_GAME_FOLDER_DEFAULT


func _export_trenchbroom_bundle(raw_target_path: String) -> String:
	var target_path := _to_absolute_path(raw_target_path)
	if target_path.is_empty():
		return "empty TrenchBroom path"

	var mk_err := DirAccess.make_dir_recursive_absolute(target_path)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		return "failed creating folder (%s)" % str(mk_err)

	var fgd := load(MAIN_FGD_FILE) as Resource
	if fgd == null or not fgd.has_method("build_class_text"):
		return "missing FGD resource: %s" % MAIN_FGD_FILE

	var fgd_name := String(fgd.get("fgd_name"))
	if fgd_name.is_empty():
		fgd_name = "sacredFruit"
	var fgd_text := String(fgd.call("build_class_text", TRENCHBROOM_EDITOR_TARGET))
	var fgd_save_error := _write_text_file(target_path.path_join("%s.fgd" % fgd_name), fgd_text)
	if not fgd_save_error.is_empty():
		return fgd_save_error

	var game_config := load(TB_GAME_CONFIG_FILE) as Resource
	if game_config == null or not game_config.has_method("build_class_text"):
		return "missing game config resource: %s" % TB_GAME_CONFIG_FILE

	var cfg_text := String(game_config.call("build_class_text"))
	var cfg_save_error := _write_text_file(target_path.path_join("GameConfig.cfg"), cfg_text)
	if not cfg_save_error.is_empty():
		return cfg_save_error

	var icon_variant: Variant = game_config.get("icon")
	if icon_variant is Texture2D:
		var icon_image := (icon_variant as Texture2D).get_image()
		if icon_image != null:
			icon_image.resize(32, 32, Image.INTERPOLATE_LANCZOS)
			var icon_err := icon_image.save_png(target_path.path_join("icon.png"))
			if icon_err != OK:
				return "failed writing icon (%s)" % str(icon_err)

	return ""


func _write_text_file(path: String, text: String) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "failed writing %s (%s)" % [path, str(FileAccess.get_open_error())]
	file.store_string(text)
	file.close()
	return ""


func _to_absolute_path(path: String) -> String:
	var clean := path.strip_edges()
	if clean.is_empty():
		return ""
	if clean.begins_with("res://") or clean.begins_with("user://"):
		return ProjectSettings.globalize_path(clean)
	return clean


func _ensure_res_dir(dir_path: String) -> int:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))


func _on_close_pressed() -> void:
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("toggle_menu"):
		dbg.call("toggle_menu")
	else:
		visible = false


func _scan_maps(include_autosaves: bool) -> Array[String]:
	var results: Array[String] = []
	_scan_map_dir_recursive(MAP_ROOT, results, include_autosaves)
	if include_autosaves:
		_scan_map_dir_recursive(MAP_AUTOSAVE_ROOT, results, include_autosaves)
	results.sort()
	return results


func _scan_map_dir_recursive(dir_path: String, out: Array[String], include_autosaves: bool) -> void:
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
			_scan_map_dir_recursive(full, out, include_autosaves)
		else:
			if not entry_name.to_lower().ends_with(".map"):
				continue
			# Avoid texture '.map' files in tb/textures.
			if full.find("/textures/") != -1:
				continue
			out.append(full)

	dir.list_dir_end()


func _scan_models() -> Array[String]:
	var results: Array[String] = []
	_scan_model_dir_recursive(MODEL_ROOT, results)
	results.sort()
	return results


func _scan_model_dir_recursive(dir_path: String, out: Array[String]) -> void:
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
			_scan_model_dir_recursive(full, out)
		else:
			var lower := entry_name.to_lower()
			if lower.ends_with(".glb") or lower.ends_with(".gltf"):
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
