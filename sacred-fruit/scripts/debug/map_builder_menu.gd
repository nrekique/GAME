extends Control
class_name MapBuilderMenu

## Map Builder & TrenchBroom Entity Generator
## Handles runtime map loading and FGD entity creation

# UI references
@onready var search: LineEdit = %Search
@onready var include_autosave: CheckBox = %IncludeAutosave
@onready var map_list: ItemList = %MapList
@onready var build_run_button: Button = %BuildRun
@onready var photo_mode_button: Button = %PhotoMode

@onready var model_filter: LineEdit = %ModelFilter
@onready var model_list: ItemList = %ModelList
@onready var model_scale: LineEdit = %ModelScale
@onready var size_mode: OptionButton = %SizeMode
@onready var manual_size_x: LineEdit = %ManualSizeX
@onready var manual_size_y: LineEdit = %ManualSizeY
@onready var manual_size_z: LineEdit = %ManualSizeZ
@onready var tb_config_path: LineEdit = %TBConfigPath
@onready var generate_prop_button: Button = %GeneratePropEntity
@onready var generate_actor_button: Button = %GenerateActorEntity

@onready var status: Label = %Status
@onready var close_button: Button = %Close

# Constants
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


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect signals
	search.text_changed.connect(_on_map_filter_changed)
	include_autosave.toggled.connect(_on_map_filter_changed)
	map_list.item_activated.connect(_on_item_activated)
	build_run_button.pressed.connect(_on_build_run_pressed)
	photo_mode_button.pressed.connect(_on_photo_mode_pressed)
	
	model_filter.text_changed.connect(_on_model_filter_changed)
	model_list.item_activated.connect(_on_model_item_activated)
	size_mode.item_selected.connect(_on_size_mode_changed)
	generate_prop_button.pressed.connect(_on_generate_prop_pressed)
	generate_actor_button.pressed.connect(_on_generate_actor_pressed)
	
	close_button.pressed.connect(_on_close_pressed)
	
	# Set default TB path
	if tb_config_path.text.strip_edges().is_empty():
		tb_config_path.text = TB_GAME_FOLDER_DEFAULT
	
	# Update manual size state
	_update_size_mode_state()


func open_menu() -> void:
	visible = true
	refresh()


func refresh() -> void:
	_paths = _scan_maps(include_autosave.button_pressed)
	_model_paths = _scan_models()
	_apply_map_filter(search.text)
	_apply_model_filter(model_filter.text)
	status.text = "Found %d maps and %d models" % [_paths.size(), _model_paths.size()]
	
	if map_list.item_count > 0:
		map_list.select(0)
	if model_list.item_count > 0:
		model_list.select(0)


func _on_map_filter_changed(_arg = null) -> void:
	_apply_map_filter(search.text)


func _on_model_filter_changed(_arg = null) -> void:
	_apply_model_filter(model_filter.text)


func _on_size_mode_changed(_index: int) -> void:
	_update_size_mode_state()


func _update_size_mode_state() -> void:
	var manual_enabled := _size_mode_is_manual()
	manual_size_x.editable = manual_enabled
	manual_size_y.editable = manual_enabled
	manual_size_z.editable = manual_enabled
	
	var alpha := 1.0 if manual_enabled else 0.5
	manual_size_x.modulate = Color(1.0, 1.0, 1.0, alpha)
	manual_size_y.modulate = Color(1.0, 1.0, 1.0, alpha)
	manual_size_z.modulate = Color(1.0, 1.0, 1.0, alpha)


func _apply_map_filter(filter_text: String) -> void:
	map_list.clear()
	var f := filter_text.strip_edges().to_lower()
	
	for p in _paths:
		var should_show := true
		if not f.is_empty():
			should_show = p.to_lower().find(f) != -1
		
		if should_show:
			var label := p.replace("res://", "")
			map_list.add_item(label)
			map_list.set_item_metadata(map_list.item_count - 1, p)


func _apply_model_filter(filter_text: String) -> void:
	model_list.clear()
	var f := filter_text.strip_edges().to_lower()
	
	for p in _model_paths:
		var should_show := true
		if not f.is_empty():
			should_show = p.to_lower().find(f) != -1
		
		if should_show:
			var label := p.replace("res://", "")
			model_list.add_item(label)
			model_list.set_item_metadata(model_list.item_count - 1, p)


func _selected_map_path() -> String:
	var idx := map_list.get_selected_items()
	if idx.size() == 0:
		return ""
	return str(map_list.get_item_metadata(idx[0]))


func _selected_model_path() -> String:
	var idx := model_list.get_selected_items()
	if idx.size() == 0:
		return ""
	return str(model_list.get_item_metadata(idx[0]))


func _on_item_activated(_index: int) -> void:
	_on_build_run_pressed()


func _on_model_item_activated(_index: int) -> void:
	_on_generate_prop_pressed()


func _on_build_run_pressed() -> void:
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


func _on_close_pressed() -> void:
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
			if full.find("/textures/") != -1 or full.find("/fgd/") != -1:
				continue
			if (not include_autosaves) and full.find("/autosave") != -1:
				continue
			_scan_map_dir_recursive(full, out, include_autosaves)
		else:
			if not entry_name.to_lower().ends_with(".map"):
				continue
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


func _size_mode_is_manual() -> bool:
	return size_mode.selected == 1


# [Entity generation functions continue from old debug_menu.gd - about 600 more lines]
# NOTE: Keeping the entity generation logic for reference but marking as "to be implemented"
# These functions handle TrenchBroom FGD entity creation from models

func _generate_model_entity(_as_actor: bool) -> void:
	status.text = "Entity generation not yet fully implemented in refactored menu"
	# TODO: Port the full entity generation logic from old debug_menu.gd
	# Functions needed:
	# - _generate_model_entity()
	# - _build_wrapper_scene()
	# - _upsert_entity_definition()
	# - _compute_model_size_meta()
	# - _export_trenchbroom_bundle()
	# ... etc
