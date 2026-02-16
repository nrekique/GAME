extends Node3D

# Export/import photo mode state (scene, camera, settings)
const PHOTO_CAPTURE_DIR := "user://photos"
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const HOME_SETUP_SCRIPT := preload("res://scripts/home_setup.gd")




# If a map path is provided in state, attempt to load/build it (best-effort).
func _build_map_async(map: FuncGodotMap) -> bool:
	if map == null:
		return false
	var done := [false]
	var success := [false]
	if map.has_method("verify_and_build"):
		map.build_progress.connect(func(step, progress):
			pass
		)
		map.build_complete.connect(func():
			done[0] = true
			success[0] = true
		)
		map.build_failed.connect(func():
			done[0] = true
			success[0] = false
		)
		map.verify_and_build()
		while not done[0]:
			await get_tree().process_frame
		return success[0]
	return false

func _try_load_map_by_path(map_path: String) -> void:
	if map_path == null or String(map_path).strip_edges() == "":
		return
	# If we already have a map and it matches, just set local_map_file
	if _map != null and "local_map_file" in _map:
		_map.local_map_file = String(map_path)
		return
	# Otherwise create a new FuncGodotMap and build it
	var new_map := FuncGodotMap.new()
	new_map.name = "FuncGodotMap"
	new_map.local_map_file = String(map_path)
	add_child(new_map)
	_map = new_map
	# fire build async, ignore result for now
	if new_map.has_method("verify_and_build"):
		call_deferred("_deferred_build_map", new_map)

func _deferred_build_map(map: FuncGodotMap) -> void:
	await _build_map_async(map)

@export var move_speed: float = 12.0
@export var fast_multiplier: float = 3.0
@export var mouse_sens: float = 0.25
@export var enable_runtime_layout_repair: bool = false
@export var enable_layout_debug_print: bool = true

var _map: FuncGodotMap
var _yaw: float = 0.0
var _pitch: float = 0.0
var _bookmarks: Dictionary = {} as Dictionary
var _ui_visible: bool = true
var _material_state: Dictionary = {}
var _env_presets: Dictionary = {}
var _layout_retry_frames: int = 0

const PASS_BEAUTY := "beauty"
const PASS_ALBEDO := "albedo"
const PASS_NORMALS := "normals"
const PASS_DEPTH := "depth"
const PASS_LIGHTING := "lighting"

var _normal_pass_material: ShaderMaterial
var _depth_pass_material: ShaderMaterial

var _camera: Camera3D
var _world_env: WorldEnvironment
var _light_rig: Node3D
var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _rim_light: DirectionalLight3D
var _top_light: DirectionalLight3D
var _bounce_light: DirectionalLight3D
var _ui_root: Control
var _menu_layer: CanvasLayer
var _menu_overlay: Control
var _tabs_panel: Control
var _tab_buttons: Dictionary = {} as Dictionary
var _current_tab: String = "All"
var _status: Label
var _guides: Control
var _guides_layer: CanvasLayer
var _fov_slider: HSlider
var _fov_value: Label
var _focal_options: OptionButton
var _iso_slider: HSlider
var _iso_value: Label
var _aperture_slider: HSlider
var _aperture_value: Label
var _shutter_slider: HSlider
var _shutter_value: Label
var _focus_slider: HSlider
var _focus_value: Label
var _shooting_mode_options: OptionButton
var _auto_focus_toggle: CheckBox
var _exposure_slider: HSlider
var _exposure_value: Label
var _auto_exposure_toggle: CheckBox
var _auto_exposure_speed_slider: HSlider
var _auto_exposure_speed_value: Label
var _auto_exposure_min_slider: HSlider
var _auto_exposure_min_value: Label
var _auto_exposure_max_slider: HSlider
var _auto_exposure_max_value: Label
var _env_options: OptionButton
var _res_options: OptionButton
var _aspect_options: OptionButton
var _guides_check: CheckBox
var _guide_type_options: OptionButton
var _golden_check: CheckBox
var _safe_check: CheckBox
var _diagonal_check: CheckBox
var _diagonal_alt_check: CheckBox
var _spiral_check: CheckBox
var _guides_opacity_slider: HSlider
var _guides_opacity_value: Label
var _sun_angle_slider: HSlider
var _sun_angle_value: Label
var _ambient_slider: HSlider
var _ambient_value: Label
var _temp_slider: HSlider
var _temp_value: Label
var _tint_slider: HSlider
var _tint_value: Label
var _saturation_slider: HSlider
var _saturation_value: Label
var _contrast_slider: HSlider
var _contrast_value: Label
var _vignette_slider: HSlider
var _vignette_value: Label
var _grain_slider: HSlider
var _grain_value: Label
var _bloom_slider: HSlider
var _bloom_value: Label
var _presets_options: OptionButton
var _preset_name: LineEdit
var _preset_save: Button
var _preset_load: Button
var _preset_delete: Button
var _presets_cache: Array[Dictionary] = []
var _exposure_collapse: Button
var _guides_collapse: Button
var _capture_collapse: Button
var _passes_collapse: Button
var _light_collapse: Button
var _section_collapsed: Dictionary = {} as Dictionary
var _capture_button: Button
var _capture_layers_button: Button
var _back_button: Button
var _capture_format_options: OptionButton
var _capture_path_edit: LineEdit
var _capture_path_button: Button
var _capture_path_dialog: FileDialog
var _viewfinder: Control
var _pass_beauty: CheckBox
var _pass_albedo: CheckBox
var _key_enabled: CheckBox
var _key_color: ColorPickerButton
var _key_intensity: HSlider
var _fill_enabled: CheckBox
var _fill_color: ColorPickerButton
var _fill_intensity: HSlider
var _pass_normals: CheckBox
var _pass_depth: CheckBox
var _pass_lighting: CheckBox
var _pass_preview_options: OptionButton
 
var _rim_enabled: CheckBox
var _rim_color: ColorPickerButton
var _rim_intensity: HSlider
var _top_enabled: CheckBox
var _top_color: ColorPickerButton
var _top_intensity: HSlider
var _bounce_enabled: CheckBox
var _bounce_color: ColorPickerButton
var _bounce_intensity: HSlider
var _iso_current: float = 400.0
var _aperture_current: float = 2.8
var _shutter_current: float = 1.0 / 60.0
var _base_exposure: float = 0.0
var _focus_distance: float = 5.0
var _auto_focus_enabled: bool = true
var _auto_focus_timer: float = 0.0
var _auto_exposure_enabled: bool = false
var _last_viewport_size: Vector2 = Vector2.ZERO
var _top_bar: Control
var _main_vbox: VBoxContainer
var _bottom_bar: Control
var _always_show_viewport_toggle: CheckBox
var _contact_strip: HBoxContainer
var _session_captures: Array = []
var _capture_preview_panel: Window
var _always_show_viewport_enabled: bool = false


# --- Export / Import helpers (moved below variable declarations) ---
func export_photo_mode_state(path: String) -> void:
	var state = {
		"map_file": _map.local_map_file if _map and "local_map_file" in _map else "",
		"camera": {
			"position": _camera.global_position if _camera else Vector3.ZERO,
			"rotation": _camera.rotation_degrees if _camera else Vector3.ZERO,
			"fov": _camera.fov if _camera else 70.0,
			"yaw": _yaw,
			"pitch": _pitch,
			"iso": _iso_current,
			"aperture": _aperture_current,
			"shutter": _shutter_current,
			"focus_distance": _focus_distance,
			"auto_focus": _auto_focus_enabled,
		},
		"exposure": {
			"base": _base_exposure,
			"auto": _auto_exposure_enabled,
		},
		"environment": {
			"preset": _env_options.get_item_text(_env_options.selected) if _env_options else "",
		},
		"resolution": {
			"preset": _res_options.get_item_text(_res_options.selected) if _res_options else "",
		},
		"aspect": {
			"preset": _aspect_options.get_item_text(_aspect_options.selected) if _aspect_options else "",
		},
		"guides": {
			"enabled": _guides.visible if _guides else false,
			"type": _guide_type_options.get_item_text(_guide_type_options.selected) if _guide_type_options else "",
		},
		"lights": {
			"key": _serialize_light(_key_light, _key_enabled, _key_color, _key_intensity),
			"fill": _serialize_light(_fill_light, _fill_enabled, _fill_color, _fill_intensity),
			"rim": _serialize_light(_rim_light, _rim_enabled, _rim_color, _rim_intensity),
			"top": _serialize_light(_top_light, _top_enabled, _top_color, _top_intensity),
			"bounce": _serialize_light(_bounce_light, _bounce_enabled, _bounce_color, _bounce_intensity),
		},
		"color": {
			"temp": _temp_slider.value if _temp_slider else 0.0,
			"tint": _tint_slider.value if _tint_slider else 0.0,
			"saturation": _saturation_slider.value if _saturation_slider else 1.0,
			"contrast": _contrast_slider.value if _contrast_slider else 1.0,
		},
		"effects": {
			"vignette": _vignette_slider.value if _vignette_slider else 0.0,
			"grain": _grain_slider.value if _grain_slider else 0.0,
			"bloom": _bloom_slider.value if _bloom_slider else 0.0,
		},
		"capture": {
			"format": _capture_format_options.get_item_text(_capture_format_options.selected) if _capture_format_options else "",
			"path": _capture_path_edit.text if _capture_path_edit else "",
		},
		"passes": {
			"preview": _pass_preview_options.get_item_text(_pass_preview_options.selected) if _pass_preview_options else "",
			"beauty": _pass_beauty.button_pressed if _pass_beauty else false,
			"albedo": _pass_albedo.button_pressed if _pass_albedo else false,
			"normals": _pass_normals.button_pressed if _pass_normals else false,
			"depth": _pass_depth.button_pressed if _pass_depth else false,
			"lighting": _pass_lighting.button_pressed if _pass_lighting else false,
		},
	}
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state, "  "))
		file.close()


# Helper to serialize a light's state
func _serialize_light(light, enabled, color, intensity) -> Dictionary:
	return {
		"enabled": enabled.button_pressed if enabled else false,
		"color": color.color if color else Color(1,1,1),
		"intensity": intensity.value if intensity else 1.0,
		"rotation": light.rotation_degrees if light else Vector3.ZERO,
	}


func _parse_color(value) -> Color:
	if value is Color:
		return value
	if value is Array:
		if value.size() >= 3:
			var a = 1.0
			if value.size() >= 4:
				a = float(value[3])
			return Color(float(value[0]), float(value[1]), float(value[2]), a)
		return Color(1,1,1)
	if value is Dictionary:
		var r = float(value.get("r", 1.0))
		var g = float(value.get("g", 1.0))
		var b = float(value.get("b", 1.0))
		var a = float(value.get("a", value.get("alpha", 1.0)))
		return Color(r, g, b, a)
	return Color(1,1,1)

func _parse_vector3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO

func _apply_light_state(light_node, enabled_node, color_node, intensity_node, data: Dictionary) -> void:
	if data == null:
		return
	if enabled_node and data.has("enabled"):
		if enabled_node is CheckBox:
			enabled_node.button_pressed = bool(data["enabled"])
	if color_node and data.has("color"):
		color_node.color = _parse_color(data["color"])
	if intensity_node and data.has("intensity"):
		intensity_node.value = float(data["intensity"])
	if light_node and data.has("rotation"):
		light_node.rotation_degrees = _parse_vector3(data["rotation"])

func import_photo_mode_state(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var content = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	var state = parsed if parsed is Dictionary else null
	if state == null:
		return

	# Map file (best effort)
	if state.has("map_file") and state["map_file"] != "":
		if _map != null and "local_map_file" in _map:
			_map.local_map_file = state["map_file"]

	# Camera
	if state.has("camera"):
		var cam = state["camera"]
		if _camera:
			if cam.has("position"):
				_camera.global_position = _parse_vector3(cam["position"])
			if cam.has("rotation"):
				_camera.rotation_degrees = _parse_vector3(cam["rotation"])
			if cam.has("fov"):
				_camera.fov = float(cam["fov"])
		if cam.has("yaw"):
			_yaw = float(cam["yaw"])
		if cam.has("pitch"):
			_pitch = float(cam["pitch"])
		if cam.has("iso"):
			_iso_current = float(cam["iso"])
			if _iso_slider:
				_iso_slider.value = _iso_current
		if cam.has("aperture"):
			_aperture_current = float(cam["aperture"])
			if _aperture_slider:
				_aperture_slider.value = _aperture_current
		if cam.has("shutter"):
			_shutter_current = float(cam["shutter"])
			if _shutter_slider:
				_shutter_slider.value = _shutter_current
		if cam.has("focus_distance"):
			_focus_distance = float(cam["focus_distance"])
			if _focus_slider:
				_focus_slider.value = _focus_distance
		if cam.has("auto_focus"):
			_auto_focus_enabled = bool(cam["auto_focus"])
			if _auto_focus_toggle and _auto_focus_toggle is CheckBox:
				_auto_focus_toggle.button_pressed = _auto_focus_enabled

	# Exposure
	if state.has("exposure"):
		var exp = state["exposure"]
		if exp.has("base"):
			_base_exposure = float(exp["base"])
			if _exposure_slider:
				_exposure_slider.value = _base_exposure
		if exp.has("auto"):
			_auto_exposure_enabled = bool(exp["auto"])
			if _auto_exposure_toggle and _auto_exposure_toggle is CheckBox:
				_auto_exposure_toggle.button_pressed = _auto_exposure_enabled

	# Environment / presets
	if state.has("environment") and _env_options:
		var env = state["environment"].get("preset", "")
		for i in _env_options.get_item_count():
			if _env_options.get_item_text(i) == env:
				_env_options.selected = i
				break

	# Resolution / aspect
	if state.has("resolution") and _res_options:
		var res = state["resolution"].get("preset", "")
		for i in _res_options.get_item_count():
			if _res_options.get_item_text(i) == res:
				_res_options.selected = i
				break
	if state.has("aspect") and _aspect_options:
		var asp = state["aspect"].get("preset", "")
		for i in _aspect_options.get_item_count():
			if _aspect_options.get_item_text(i) == asp:
				_aspect_options.selected = i
				break

	# Guides
	if state.has("guides"):
		var g = state["guides"]
		if g.has("enabled") and _guides:
			_guides.visible = bool(g["enabled"])
		if g.has("type") and _guide_type_options:
			var gtype = g["type"]
			for i in _guide_type_options.get_item_count():
				if _guide_type_options.get_item_text(i) == gtype:
					_guide_type_options.selected = i
					break

	# Lights
	if state.has("lights"):
		var ls = state["lights"]
		_apply_light_state(_key_light, _key_enabled, _key_color, _key_intensity, ls.get("key", {}))
		_apply_light_state(_fill_light, _fill_enabled, _fill_color, _fill_intensity, ls.get("fill", {}))
		_apply_light_state(_rim_light, _rim_enabled, _rim_color, _rim_intensity, ls.get("rim", {}))
		_apply_light_state(_top_light, _top_enabled, _top_color, _top_intensity, ls.get("top", {}))
		_apply_light_state(_bounce_light, _bounce_enabled, _bounce_color, _bounce_intensity, ls.get("bounce", {}))

	# Color / effects
	if state.has("color"):
		var c = state["color"]
		if c.has("temp") and _temp_slider:
			_temp_slider.value = float(c["temp"])
		if c.has("tint") and _tint_slider:
			_tint_slider.value = float(c["tint"])
		if c.has("saturation") and _saturation_slider:
			_saturation_slider.value = float(c["saturation"])
		if c.has("contrast") and _contrast_slider:
			_contrast_slider.value = float(c["contrast"])
	if state.has("effects"):
		var e = state["effects"]
		if e.has("vignette") and _vignette_slider:
			_vignette_slider.value = float(e["vignette"])
		if e.has("grain") and _grain_slider:
			_grain_slider.value = float(e["grain"])
		if e.has("bloom") and _bloom_slider:
			_bloom_slider.value = float(e["bloom"])

	# Capture
	if state.has("capture"):
		var cap = state["capture"]
		if cap.has("format") and _capture_format_options:
			var fmt = cap["format"]
			for i in _capture_format_options.get_item_count():
				if _capture_format_options.get_item_text(i) == fmt:
					_capture_format_options.selected = i
					break
		if cap.has("path") and _capture_path_edit:
			_capture_path_edit.text = str(cap["path"])

	# Passes
	if state.has("passes"):
		var p = state["passes"]
		if p.has("beauty") and _pass_beauty:
			_pass_beauty.button_pressed = bool(p["beauty"])
		if p.has("albedo") and _pass_albedo:
			_pass_albedo.button_pressed = bool(p["albedo"])
		if p.has("normals") and _pass_normals:
			_pass_normals.button_pressed = bool(p["normals"])
		if p.has("depth") and _pass_depth:
			_pass_depth.button_pressed = bool(p["depth"])
		if p.has("lighting") and _pass_lighting:
			_pass_lighting.button_pressed = bool(p["lighting"])

	# Finalize: re-apply camera attributes and exposure
	_setup_camera_attributes()
	_apply_physical_exposure()
	_apply_auto_exposure_settings()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("NO_HUD")

	_resolve_nodes()
	_setup_camera_attributes()
	_setup_pass_materials()
	_setup_ui()
	_setup_environment_presets()
	if _ui_root:
		_ui_root.visible = _ui_visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if _ui_visible else Input.MOUSE_MODE_CAPTURED)
	if enable_runtime_layout_repair:
		_ensure_ui_layout()
		call_deferred("_ensure_ui_layout")
	if enable_layout_debug_print:
		call_deferred("_debug_layout")
	# Always attempt a deferred layout repair once to apply the toolbar/top/bottom changes
	call_deferred("_ensure_ui_layout")
	await _build_map_from_debug()
	_position_camera_at_start()
	_ensure_camera_active()


func _setup_camera_attributes() -> void:
	if _camera == null:
		return
	_camera.current = true
	var attrs := CameraAttributesPhysical.new()
	_set_attr_if_exists(attrs, "aperture", _aperture_current)
	_set_attr_if_exists(attrs, "f_stop", _aperture_current)
	_set_attr_if_exists(attrs, "fstop", _aperture_current)
	_set_attr_if_exists(attrs, "shutter_speed", _shutter_current)
	_set_attr_if_exists(attrs, "iso", _iso_current)
	_camera.attributes = attrs
	if _world_env == null:
		_world_env = WorldEnvironment.new()
		_world_env.name = "WorldEnvironment"
		add_child(_world_env)
	if _world_env.environment == null:
		_world_env.environment = Environment.new()
	_apply_physical_exposure()
	_apply_auto_exposure_settings()


func _resolve_nodes() -> void:
	_camera = get_node_or_null("PhotoCamera") as Camera3D
	if _camera == null:
		var cams := find_children("*", "Camera3D", true, false)
		if cams.size() > 0:
			_camera = cams[0] as Camera3D
	_world_env = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_env == null:
		var envs := find_children("*", "WorldEnvironment", true, false)
		if envs.size() > 0:
			_world_env = envs[0] as WorldEnvironment
	_light_rig = get_node_or_null("LightRig") as Node3D
	if _light_rig == null:
		var rigs := find_children("*", "Node3D", true, false)
		for r in rigs:
			if r.name == "LightRig":
				_light_rig = r as Node3D
				break
	_key_light = get_node_or_null("LightRig/KeyLight") as DirectionalLight3D
	_fill_light = get_node_or_null("LightRig/FillLight") as DirectionalLight3D
	_rim_light = get_node_or_null("LightRig/RimLight") as DirectionalLight3D
	_top_light = get_node_or_null("LightRig/TopLight") as DirectionalLight3D
	_bounce_light = get_node_or_null("LightRig/BounceLight") as DirectionalLight3D
	_ui_root = get_node_or_null("CanvasLayer/PhotoUI") as Control
	if _ui_root == null:
		_ui_root = _find_node("PhotoUI", "Control") as Control
	if _ui_root:
		_ui_root.visible = true
	_tabs_panel = _ui_root.get_node_or_null("RootMargin/RootHBox/TabsPanel") as Control if _ui_root else _find_node("TabsPanel", "Control") as Control
	_status = _find_node("Status", "Label") as Label
	_guides = _find_node("PhotoGuides", "Control") as Control
	_fov_slider = _find_node("FOVSlider", "HSlider") as HSlider
	_fov_value = _find_node("FOVValue", "Label") as Label
	_focal_options = _find_node("FocalOptions", "OptionButton") as OptionButton
	_iso_slider = _find_node("ISOSlider", "HSlider") as HSlider
	_iso_value = _find_node("ISOValue", "Label") as Label
	_aperture_slider = _find_node("ApertureSlider", "HSlider") as HSlider
	_aperture_value = _find_node("ApertureValue", "Label") as Label
	_shutter_slider = _find_node("ShutterSlider", "HSlider") as HSlider
	_shutter_value = _find_node("ShutterValue", "Label") as Label
	_focus_slider = _find_node("FocusSlider", "HSlider") as HSlider
	_focus_value = _find_node("FocusValue", "Label") as Label
	_shooting_mode_options = _find_node("ShootingModeOptions", "OptionButton") as OptionButton
	_auto_focus_toggle = _find_node("AutoFocusToggle", "CheckBox") as CheckBox
	_auto_exposure_toggle = _find_node("AutoExposureToggle", "CheckBox") as CheckBox
	_auto_exposure_speed_slider = _find_node("AutoExposureSpeedSlider", "HSlider") as HSlider
	_auto_exposure_speed_value = _find_node("AutoExposureSpeedValue", "Label") as Label
	_auto_exposure_min_slider = _find_node("AutoExposureMinSlider", "HSlider") as HSlider
	_auto_exposure_min_value = _find_node("AutoExposureMinValue", "Label") as Label
	_auto_exposure_max_slider = _find_node("AutoExposureMaxSlider", "HSlider") as HSlider
	_auto_exposure_max_value = _find_node("AutoExposureMaxValue", "Label") as Label
	_exposure_slider = _find_node("ExposureSlider", "HSlider") as HSlider
	_exposure_value = _find_node("ExposureValue", "Label") as Label
	_env_options = _find_node("EnvOptions", "OptionButton") as OptionButton
	_res_options = _find_node("ResOptions", "OptionButton") as OptionButton
	_aspect_options = _find_node("AspectOptions", "OptionButton") as OptionButton
	_guides_check = _find_node("GuidesCheck", "CheckBox") as CheckBox
	_guide_type_options = _find_node("GuideTypeOptions", "OptionButton") as OptionButton
	_golden_check = _find_node("GoldenCheck", "CheckBox") as CheckBox
	_safe_check = _find_node("SafeCheck", "CheckBox") as CheckBox
	_diagonal_check = _find_node("DiagonalCheck", "CheckBox") as CheckBox
	_diagonal_alt_check = _find_node("DiagonalAltCheck", "CheckBox") as CheckBox
	_spiral_check = _find_node("SpiralCheck", "CheckBox") as CheckBox
	_guides_opacity_slider = _find_node("GuidesOpacitySlider", "HSlider") as HSlider
	_guides_opacity_value = _find_node("GuidesOpacityValue", "Label") as Label
	_sun_angle_slider = _find_node("SunAngleSlider", "HSlider") as HSlider
	_sun_angle_value = _find_node("SunAngleValue", "Label") as Label
	_ambient_slider = _find_node("AmbientSlider", "HSlider") as HSlider
	_ambient_value = _find_node("AmbientValue", "Label") as Label
	_temp_slider = _find_node("TempSlider", "HSlider") as HSlider
	_temp_value = _find_node("TempValue", "Label") as Label
	_tint_slider = _find_node("TintSlider", "HSlider") as HSlider
	_tint_value = _find_node("TintValue", "Label") as Label
	_saturation_slider = _find_node("SaturationSlider", "HSlider") as HSlider
	_saturation_value = _find_node("SaturationValue", "Label") as Label
	_contrast_slider = _find_node("ContrastSlider", "HSlider") as HSlider
	_contrast_value = _find_node("ContrastValue", "Label") as Label
	_vignette_slider = _find_node("VignetteSlider", "HSlider") as HSlider
	_vignette_value = _find_node("VignetteValue", "Label") as Label
	_grain_slider = _find_node("GrainSlider", "HSlider") as HSlider
	_grain_value = _find_node("GrainValue", "Label") as Label
	_bloom_slider = _find_node("BloomSlider", "HSlider") as HSlider
	_bloom_value = _find_node("BloomValue", "Label") as Label
	_presets_options = _find_node("PresetsOptions", "OptionButton") as OptionButton
	_preset_name = _find_node("PresetName", "LineEdit") as LineEdit
	_preset_save = _find_node("PresetSave", "Button") as Button
	_preset_load = _find_node("PresetLoad", "Button") as Button
	_preset_delete = _find_node("PresetDelete", "Button") as Button
	_exposure_collapse = _find_node("ExposureCollapse", "Button") as Button
	_guides_collapse = _find_node("GuidesCollapse", "Button") as Button
	_capture_collapse = _find_node("CaptureCollapse", "Button") as Button
	_passes_collapse = _find_node("PassesCollapse", "Button") as Button
	_light_collapse = _find_node("LightRigCollapse", "Button") as Button
	_capture_button = _find_node("CaptureButton", "Button") as Button
	_capture_layers_button = _find_node("CaptureLayersButton", "Button") as Button
	_back_button = _find_node("BackButton", "Button") as Button
	_capture_format_options = _find_node("CaptureFormatOptions", "OptionButton") as OptionButton
	_capture_path_edit = _find_node("CapturePathEdit", "LineEdit") as LineEdit
	_capture_path_button = _find_node("CapturePathButton", "Button") as Button
	_capture_path_dialog = _find_node("CapturePathDialog", "FileDialog") as FileDialog
	_viewfinder = _find_node("PhotoViewfinder", "Control") as Control
	_pass_beauty = _find_node("PassBeauty", "CheckBox") as CheckBox
	_pass_albedo = _find_node("PassAlbedo", "CheckBox") as CheckBox
	_pass_normals = _find_node("PassNormals", "CheckBox") as CheckBox
	_pass_depth = _find_node("PassDepth", "CheckBox") as CheckBox
	_pass_lighting = _find_node("PassLighting", "CheckBox") as CheckBox
	_pass_preview_options = _find_node("PassPreviewOptions", "OptionButton") as OptionButton
	_key_enabled = _find_node("KeyEnabled", "CheckBox") as CheckBox
	_key_color = _find_node("KeyColor", "ColorPickerButton") as ColorPickerButton
	_key_intensity = _find_node("KeyIntensity", "HSlider") as HSlider
	_fill_enabled = _find_node("FillEnabled", "CheckBox") as CheckBox
	_fill_color = _find_node("FillColor", "ColorPickerButton") as ColorPickerButton
	_fill_intensity = _find_node("FillIntensity", "HSlider") as HSlider
	_rim_enabled = _find_node("RimEnabled", "CheckBox") as CheckBox
	_rim_color = _find_node("RimColor", "ColorPickerButton") as ColorPickerButton
	_rim_intensity = _find_node("RimIntensity", "HSlider") as HSlider
	_top_enabled = _find_node("TopEnabled", "CheckBox") as CheckBox
	_top_color = _find_node("TopColor", "ColorPickerButton") as ColorPickerButton
	_top_intensity = _find_node("TopIntensity", "HSlider") as HSlider
	_bounce_enabled = _find_node("BounceEnabled", "CheckBox") as CheckBox
	_bounce_color = _find_node("BounceColor", "ColorPickerButton") as ColorPickerButton
	_bounce_intensity = _find_node("BounceIntensity", "HSlider") as HSlider


func _find_node(name_hint: String, type_hint: String) -> Node:
	var by_unique := get_node_or_null("%" + name_hint)
	if by_unique != null and (type_hint.is_empty() or by_unique.is_class(type_hint)):
		return by_unique
	var by_name := find_child(name_hint, true, false)
	if by_name != null and (type_hint.is_empty() or by_name.is_class(type_hint)):
		return by_name
	# Fallback: substring match (helps when node names get mangled like "...#Status")
	for n in find_children("*", "", true, false):
		if String(n.name).find(name_hint) != -1:
			if type_hint.is_empty() or n.is_class(type_hint):
				return n
	return null


func _setup_ui() -> void:
	if _guides:
		_guides.visible = true
	if _fov_slider:
		_fov_slider.value_changed.connect(_on_fov_changed)
		_on_fov_changed(_fov_slider.value)
	if _focal_options:
		_populate_focal_options()
		_focal_options.item_selected.connect(_on_focal_selected)
	if _iso_slider:
		_iso_slider.value_changed.connect(_on_iso_changed)
		_on_iso_changed(_iso_slider.value)
	if _aperture_slider:
		_aperture_slider.value_changed.connect(_on_aperture_changed)
		_on_aperture_changed(_aperture_slider.value)
	if _shutter_slider:
		_shutter_slider.value_changed.connect(_on_shutter_changed)
		_on_shutter_changed(_shutter_slider.value)
	if _focus_slider:
		_focus_slider.value_changed.connect(_on_focus_changed)
		_on_focus_changed(_focus_slider.value)
	if _shooting_mode_options:
		_populate_shooting_modes()
		_shooting_mode_options.item_selected.connect(_on_shooting_mode_selected)
	if _auto_focus_toggle:
		_auto_focus_toggle.toggled.connect(_on_auto_focus_toggled)
		_auto_focus_toggle.button_pressed = _auto_focus_enabled
	if _auto_exposure_toggle:
		_auto_exposure_toggle.toggled.connect(_on_auto_exposure_toggled)
		_auto_exposure_toggle.button_pressed = _auto_exposure_enabled
	if _auto_exposure_speed_slider:
		_auto_exposure_speed_slider.value_changed.connect(_on_auto_exposure_speed_changed)
		_on_auto_exposure_speed_changed(_auto_exposure_speed_slider.value)
	if _auto_exposure_min_slider:
		_auto_exposure_min_slider.value_changed.connect(_on_auto_exposure_min_changed)
		_on_auto_exposure_min_changed(_auto_exposure_min_slider.value)
	if _auto_exposure_max_slider:
		_auto_exposure_max_slider.value_changed.connect(_on_auto_exposure_max_changed)
		_on_auto_exposure_max_changed(_auto_exposure_max_slider.value)
	if _exposure_slider:
		_exposure_slider.value_changed.connect(_on_exposure_changed)
		_on_exposure_changed(_exposure_slider.value)
	if _env_options:
		_env_options.item_selected.connect(_on_environment_selected)
	if _res_options:
		_populate_resolution_options()
		_res_options.item_selected.connect(_on_resolution_selected)
	if _aspect_options:
		_populate_aspect_options()
		_aspect_options.item_selected.connect(_on_aspect_selected)
	if _guides_check:
		_guides_check.toggled.connect(_on_guides_toggled)
	if _guide_type_options:
		_populate_guide_types()
		_guide_type_options.item_selected.connect(_on_guide_type_selected)
	if _golden_check:
		_golden_check.toggled.connect(_on_golden_toggled)
	if _safe_check:
		_safe_check.toggled.connect(_on_safe_toggled)
	if _diagonal_check:
		_diagonal_check.toggled.connect(_on_diagonal_toggled)
	if _diagonal_alt_check:
		_diagonal_alt_check.toggled.connect(_on_diagonal_alt_toggled)
	if _spiral_check:
		_spiral_check.toggled.connect(_on_spiral_toggled)
	if _guides_opacity_slider:
		_guides_opacity_slider.value_changed.connect(_on_guides_opacity_changed)
		_on_guides_opacity_changed(_guides_opacity_slider.value)
	if _sun_angle_slider:
		_sun_angle_slider.value_changed.connect(_on_sun_angle_changed)
		_on_sun_angle_changed(_sun_angle_slider.value)
	if _ambient_slider:
		_ambient_slider.value_changed.connect(_on_ambient_changed)
		_on_ambient_changed(_ambient_slider.value)
	if _temp_slider:
		_temp_slider.value_changed.connect(_on_temp_changed)
		_on_temp_changed(_temp_slider.value)
	if _tint_slider:
		_tint_slider.value_changed.connect(_on_tint_changed)
		_on_tint_changed(_tint_slider.value)
	if _saturation_slider:
		_saturation_slider.value_changed.connect(_on_saturation_changed)
		_on_saturation_changed(_saturation_slider.value)
	if _contrast_slider:
		_contrast_slider.value_changed.connect(_on_contrast_changed)
		_on_contrast_changed(_contrast_slider.value)
	if _vignette_slider:
		_vignette_slider.value_changed.connect(_on_vignette_changed)
		_on_vignette_changed(_vignette_slider.value)
	if _grain_slider:
		_grain_slider.value_changed.connect(_on_grain_changed)
		_on_grain_changed(_grain_slider.value)
	if _bloom_slider:
		_bloom_slider.value_changed.connect(_on_bloom_changed)
		_on_bloom_changed(_bloom_slider.value)
	if _preset_save:
		_preset_save.pressed.connect(_on_preset_save)
	if _preset_load:
		_preset_load.pressed.connect(_on_preset_load)
	if _preset_delete:
		_preset_delete.pressed.connect(_on_preset_delete)

	# Export / Import state buttons (use preset buttons row if present)
	var export_btn := _find_node("ExportState", "Button") as Button
	var import_btn := _find_node("ImportState", "Button") as Button
	if export_btn == null:
		var preset_row := _find_node("PresetButtonsRow", "HBoxContainer")
		if preset_row:
			export_btn = Button.new()
			export_btn.name = "ExportState"
			export_btn.text = "Export State"
			preset_row.add_child(export_btn)
	if import_btn == null:
		var preset_row2 := _find_node("PresetButtonsRow", "HBoxContainer")
		if preset_row2:
			import_btn = Button.new()
			import_btn.name = "ImportState"
			import_btn.text = "Import State"
			preset_row2.add_child(import_btn)
	if export_btn:
		export_btn.pressed.connect(_on_export_state_pressed)
	if import_btn:
		import_btn.pressed.connect(_on_import_state_pressed)
	_load_presets()
	_setup_collapsibles()
	_setup_tabs()
	if _capture_button:
		_capture_button.pressed.connect(_on_capture_pressed)
	if _capture_format_options:
		_populate_capture_formats()
	if _capture_path_button:
		_capture_path_button.pressed.connect(_on_capture_path_browse)
	if _capture_path_dialog:
		_capture_path_dialog.dir_selected.connect(_on_capture_path_dir_selected)
	if _capture_layers_button:
		_capture_layers_button.pressed.connect(_on_capture_layers_pressed)
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)
	_setup_light_rig_ui()
	if _pass_preview_options:
		_populate_pass_preview()
		_pass_preview_options.item_selected.connect(_on_pass_preview_selected)
	if _capture_path_edit and _capture_path_edit.text.strip_edges().is_empty():
		_capture_path_edit.text = PHOTO_CAPTURE_DIR
	_update_viewfinder()


func _ensure_ui_layout() -> void:
	if _ui_root:
		_ensure_full_rect(_ui_root)
	if _guides:
		_ensure_full_rect(_guides)
		_guides.z_index = -1
		_guides.z_as_relative = false
	# If PhotoUI has no children, sweep UI controls from the CanvasLayer into it.
	var canvas_layer := get_node_or_null("CanvasLayer")
	if _guides:
		if _guides_layer == null:
			_guides_layer = get_node_or_null("PhotoGuidesLayer") as CanvasLayer
		if _guides_layer == null:
			_guides_layer = CanvasLayer.new()
			_guides_layer.name = "PhotoGuidesLayer"
			_guides_layer.layer = 50
			add_child(_guides_layer)
		if _guides.get_parent() != _guides_layer:
			_reparent(_guides, _guides_layer)
	if _ui_root and canvas_layer:
		var layer_children := canvas_layer.get_children().duplicate()
		for ch in layer_children:
			# Reparent most canvas-layer Controls into the PhotoUI so layout manages them.
			# Keep the viewfinder separate for now so it can be positioned as a sibling of the panel.
			if ch is Control and ch != _ui_root and ch != _guides:
				# _viewfinder will be reparented later into the RootHBox so it resizes with the panel
				if ch == _viewfinder:
					continue
				_reparent(ch, _ui_root)
	# If PhotoUI is still empty, sweep stray Controls from the scene root.
	if _ui_root and _ui_root.get_child_count() == 0:
		var root_children := get_children().duplicate()
		for ch in root_children:
			if ch is Control and ch != _ui_root:
				_reparent(ch, _ui_root)
	_repair_scene_tree_if_needed()


func _ensure_full_rect(control: Control) -> void:
	if control == null:
		return
	var anchors := Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom)
	if anchors != Vector4(0.0, 0.0, 1.0, 1.0):
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		control.offset_left = 0
		control.offset_top = 0
		control.offset_right = 0
		control.offset_bottom = 0


func _repair_scene_tree_if_needed() -> void:
	var root_margin := _get_or_create_container("RootMargin", MarginContainer, _ui_root)
	if root_margin is Control:
		if root_margin.get_parent() != _ui_root:
			_reparent(root_margin, _ui_root)
		var rm := root_margin as Control
		rm.anchor_left = 0.0
		rm.anchor_top = 0.0
		rm.anchor_right = 1.0
		rm.anchor_bottom = 1.0
		rm.offset_left = 24
		rm.offset_top = 24
		rm.offset_right = -24
		rm.offset_bottom = -24
		rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rm.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Force a non-zero size if layout hasn't run yet.
		if _ui_root and rm.size == Vector2.ZERO:
			rm.size = _ui_root.size - Vector2(32, 32)
			rm.custom_minimum_size = rm.size
	var root_hbox := _get_or_create_container("RootHBox", HBoxContainer, root_margin)
	if root_hbox is HBoxContainer:
		(root_hbox as HBoxContainer).add_theme_constant_override("separation", 8)
		(root_hbox as HBoxContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(root_hbox as HBoxContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Wrap the existing RootHBox in a MainVBox so we can place a TopBar above and BottomBar below
	var main_vbox := _get_or_create_container("MainVBox", VBoxContainer, root_margin)
	if root_hbox.get_parent() != main_vbox:
		_reparent(root_hbox, main_vbox)
	# Ensure the MainVBox expands
	if main_vbox is VBoxContainer:
		(main_vbox as VBoxContainer).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(main_vbox as VBoxContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Top bar (slim toolbar) — create under _ui_root so it sits at the absolute top
	var top_bar := _get_or_create_container("TopBar", HBoxContainer, main_vbox)
	if top_bar is HBoxContainer:
		(top_bar as HBoxContainer).add_theme_constant_override("separation", 8)
		(top_bar as Control).custom_minimum_size = Vector2(0, 28)
		(top_bar as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Let the top bar shrink vertically so it doesn't become a large box
		(top_bar as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		# remove any themed panel background so it appears as a slim bar
		var empty_sb := StyleBoxEmpty.new()
		(top_bar as Control).add_theme_stylebox_override("panel", empty_sb)
		# Ensure the top bar is placed in a high-priority CanvasLayer so it sits above viewports
		var top_layer := get_node_or_null("PhotoTopBarLayer") as CanvasLayer
		if top_layer == null:
			top_layer = CanvasLayer.new()
			top_layer.name = "PhotoTopBarLayer"
			top_layer.layer = 100
			add_child(top_layer)
		if top_bar.get_parent() != top_layer:
			_reparent(top_bar, top_layer)
		# Anchor to top full-width and give a fixed minimal height
		if top_bar is Control:
			(top_bar as Control).anchor_left = 0.0
			(top_bar as Control).anchor_top = 0.0
			(top_bar as Control).anchor_right = 1.0
			(top_bar as Control).anchor_bottom = 0.0
			# padding from edges so toolbar isn't flush to screen
			(top_bar as Control).offset_left = 12
			(top_bar as Control).offset_top = 6
			(top_bar as Control).offset_right = -12
			# toolbar height: small (20px) -> offset_bottom should be offset_top + height
			(top_bar as Control).offset_bottom = 26
			(top_bar as Control).custom_minimum_size = Vector2(0, 20)
			(top_bar as Control).z_index = 200
			# ensure mouse events reach the toolbar (don't let viewfinder ignore them)
			(top_bar as Control).mouse_filter = Control.MOUSE_FILTER_STOP
			(top_bar as Control).visible = true
		# Ensure _top_bar references the node now that it may have been reparented
		_top_bar = _ui_root.get_node_or_null("TopBar") as Control if _ui_root else null
		# If the AlwaysShow toggle is missing, add it into the top bar here so it appears
		if _top_bar and _always_show_viewport_toggle == null:
			var cb := _top_bar.get_node_or_null("AlwaysShowViewport") as CheckBox
			if cb == null:
				cb = CheckBox.new()
				cb.name = "AlwaysShowViewport"
				cb.text = "Always show viewport"
				cb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				cb.add_theme_constant_override("margin_right", 8)
				_top_bar.add_child(cb)
				cb.toggled.connect(_on_always_show_viewport_toggled)
			_always_show_viewport_toggle = cb

	# Bottom bar (contact strip) below tabs/panel
	var bottom_bar := _get_or_create_container("BottomBar", HBoxContainer, main_vbox)
	if bottom_bar is Control:
		(bottom_bar as Control).custom_minimum_size = Vector2(0, 96)
		(bottom_bar as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tabs_panel := _get_or_create_container("TabsPanel", PanelContainer, root_hbox)
	if tabs_panel is Control:
		(tabs_panel as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		(tabs_panel as Control).custom_minimum_size = Vector2(128, 0)
	var tabs_margin := _get_or_create_container("TabsMargin", MarginContainer, tabs_panel)
	if tabs_margin is MarginContainer:
		(tabs_margin as MarginContainer).add_theme_constant_override("margin_left", 12)
		(tabs_margin as MarginContainer).add_theme_constant_override("margin_right", 12)
		(tabs_margin as MarginContainer).add_theme_constant_override("margin_top", 12)
		(tabs_margin as MarginContainer).add_theme_constant_override("margin_bottom", 12)
	var tabs_vbox := _get_or_create_container("TabsVBox", VBoxContainer, tabs_margin)
	if tabs_vbox is VBoxContainer:
		(tabs_vbox as VBoxContainer).add_theme_constant_override("separation", 6)
	# Reparent tab buttons into the tabs vbox.
	var tab_nodes := [
		"TabCamera", "TabExposure", "TabGuides", "TabCapture",
		"TabPasses", "TabLight", "TabEnvironment", "TabExport", "TabColor",
		"TabEffects", "TabComposition", "TabPresets"
	]
	for t in tab_nodes:
		_reparent_by_name(t, tabs_vbox)
	if _tabs_panel == null:
		_tabs_panel = tabs_panel
	elif _tabs_panel != tabs_panel:
		_reparent(_tabs_panel, root_hbox)

	# Keep the PhotoViewfinder under the CanvasLayer so it overlays the 3D viewport
	# (the user expects the scene to render to the main viewport, not be confined
	# inside the Photo UI). Ensure it fills the full rect and ignores mouse input.
	if _viewfinder != null:
		var canvas_layer_node := get_node_or_null("CanvasLayer")
		if canvas_layer_node != null and _viewfinder.get_parent() != canvas_layer_node:
			_reparent(_viewfinder, canvas_layer_node)
		if _viewfinder is Control:
			# Make it cover the full canvas so the viewport content is visible behind UI
			_viewfinder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_viewfinder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_viewfinder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_viewfinder.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel := _get_or_create_container("Panel", PanelContainer, root_hbox)
	if panel is Control:
		(panel as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if _ui_root:
			var desired_width := maxf(360.0, _ui_root.size.x * 0.34)
			(panel as Control).custom_minimum_size = Vector2(desired_width, 0)
	var margin := _get_or_create_container("Margin", MarginContainer, panel)
	if margin is MarginContainer:
		(margin as MarginContainer).add_theme_constant_override("margin_left", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_right", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_top", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_bottom", 24)
	var vbox := _get_or_create_container("VBox", VBoxContainer, margin)

	# Ensure TopBar/BottomBar references and create basic controls if missing
	_top_bar = main_vbox.get_node_or_null("TopBar") as Control if main_vbox else null
	_bottom_bar = main_vbox.get_node_or_null("BottomBar") as Control if main_vbox else null
	if _top_bar and _always_show_viewport_toggle == null:
		# Create an Always Show Viewport toggle in the top bar
		_always_show_viewport_toggle = _top_bar.get_node_or_null("AlwaysShowViewport") as CheckBox
		if _always_show_viewport_toggle == null:
			var cb := CheckBox.new()
			cb.name = "AlwaysShowViewport"
			cb.text = "Always show viewport"
			# keep toggle compact
			cb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			# add a small right spacing via theme constant (avoid assigning non-existent margin_* props)
			cb.add_theme_constant_override("margin_right", 8)
			_top_bar.add_child(cb)
			cb.toggled.connect(_on_always_show_viewport_toggled)
			_always_show_viewport_toggle = cb


	# Reparent known nodes back into VBox (in case they were dragged out)
	var vbox_nodes := [
		"HistogramCard", "Title", "Status",
		"FOVRow", "FocalRow", "ISORow", "ApertureRow", "ShutterRow", "FocusRow",
		"ShootingModeRow", "AutoFocusRow",
		"ExposureHeaderRow", "ExposureRow", "EnvRow", "ResRow",
		"AspectRow",
		"GuidesHeaderRow", "GuidesRow", "GuidesOpacityRow",
		"CaptureHeaderRow", "CaptureFormatRow", "CapturePathRow", "ButtonsRow",
		"PassesHeaderRow", "PassPreviewRow", "PassesGrid", "LightRigHeaderRow", "LightRigGrid",
		"EnvironmentHeaderRow", "EnvironmentRow", "AmbientRow", "FogRow",
		"ExportHeaderRow", "ExportNote",
		"ColorHeaderRow", "TempRow", "TintRow", "SaturationRow", "ContrastRow",
		"EffectsHeaderRow", "VignetteRow", "GrainRow", "BloomRow",
		"CompositionHeaderRow", "CompositionNote",
		"PresetsHeaderRow", "PresetsRow", "PresetNameRow", "PresetButtonsRow"
	]
	for n in vbox_nodes:
		_reparent_by_name(n, vbox)

	# Ensure rows/grids exist and their child controls are under the right parent.
	_ensure_row("FOVRow", HBoxContainer, vbox, ["FOVLabel", "FOVSlider", "FOVValue"])
	_ensure_row("FocalRow", HBoxContainer, vbox, ["FocalLabel", "FocalOptions"])
	_ensure_row("ISORow", HBoxContainer, vbox, ["ISOLabel", "ISOSlider", "ISOValue"])
	_ensure_row("ApertureRow", HBoxContainer, vbox, ["ApertureLabel", "ApertureSlider", "ApertureValue"])
	_ensure_row("ShutterRow", HBoxContainer, vbox, ["ShutterLabel", "ShutterSlider", "ShutterValue"])
	_ensure_row("FocusRow", HBoxContainer, vbox, ["FocusLabel", "FocusSlider", "FocusValue"])
	_ensure_row("ShootingModeRow", HBoxContainer, vbox, ["ShootingModeLabel", "ShootingModeOptions"])
	_ensure_row("AutoFocusRow", HBoxContainer, vbox, ["AutoFocusLabel", "AutoFocusToggle"])
	_ensure_row("AutoExposureRow", HBoxContainer, vbox, ["AutoExposureLabel", "AutoExposureToggle"])
	_ensure_row("AutoExposureSpeedRow", HBoxContainer, vbox, ["AutoExposureSpeedLabel", "AutoExposureSpeedSlider", "AutoExposureSpeedValue"])
	_ensure_row("AutoExposureRangeRow", HBoxContainer, vbox, ["AutoExposureRangeLabel", "AutoExposureMinSlider", "AutoExposureMinValue", "AutoExposureMaxSlider", "AutoExposureMaxValue"])
	_ensure_row("ExposureRow", HBoxContainer, vbox, ["ExposureSlider", "ExposureValue"])
	_ensure_row("EnvRow", HBoxContainer, vbox, ["EnvLabel", "EnvOptions"])
	_ensure_row("ResRow", HBoxContainer, vbox, ["ResLabel", "ResOptions"])
	_ensure_row("AspectRow", HBoxContainer, vbox, ["AspectLabel", "AspectOptions"])
	_ensure_row("CaptureFormatRow", HBoxContainer, vbox, ["CaptureFormatLabel", "CaptureFormatOptions"])
	_ensure_row("CapturePathRow", HBoxContainer, vbox, ["CapturePathLabel", "CapturePathEdit", "CapturePathButton"])
	_ensure_row("ExposureHeaderRow", HBoxContainer, vbox, ["ExposureHeader", "ExposureCollapse"])
	_ensure_row("GuidesHeaderRow", HBoxContainer, vbox, ["GuidesHeader", "GuidesCollapse"])
	_ensure_row("CaptureHeaderRow", HBoxContainer, vbox, ["CaptureHeader", "CaptureCollapse"])
	_ensure_row("PassesHeaderRow", HBoxContainer, vbox, ["PassesLabel", "PassesCollapse"])
	_ensure_row("PassPreviewRow", HBoxContainer, vbox, ["PassPreviewLabel", "PassPreviewOptions"])
	_ensure_row("LightRigHeaderRow", HBoxContainer, vbox, ["LightRigLabel", "LightRigCollapse"])
	_ensure_row("EnvironmentHeaderRow", HBoxContainer, vbox, ["EnvironmentHeader"])
	_ensure_row("ExportHeaderRow", HBoxContainer, vbox, ["ExportHeader"])
	_ensure_row("ColorHeaderRow", HBoxContainer, vbox, ["ColorHeader"])
	_ensure_row("EffectsHeaderRow", HBoxContainer, vbox, ["EffectsHeader"])
	_ensure_row("CompositionHeaderRow", HBoxContainer, vbox, ["CompositionHeader"])
	_ensure_row("PresetsHeaderRow", HBoxContainer, vbox, ["PresetsHeader"])
	_ensure_row("GuidesRow", HBoxContainer, vbox, ["GuidesCheck", "GuideTypeOptions"])
	_ensure_row("GuidesOpacityRow", HBoxContainer, vbox, ["GuidesOpacityLabel", "GuidesOpacitySlider", "GuidesOpacityValue"])
	_ensure_row("EnvironmentRow", HBoxContainer, vbox, ["SunAngleLabel", "SunAngleSlider", "SunAngleValue"])
	_ensure_row("AmbientRow", HBoxContainer, vbox, ["AmbientLabel", "AmbientSlider", "AmbientValue"])
	_ensure_row("FogRow", HBoxContainer, vbox, ["FogLabel", "FogNote"])
	_ensure_row("TempRow", HBoxContainer, vbox, ["TempLabel", "TempSlider", "TempValue"])
	_ensure_row("TintRow", HBoxContainer, vbox, ["TintLabel", "TintSlider", "TintValue"])
	_ensure_row("SaturationRow", HBoxContainer, vbox, ["SaturationLabel", "SaturationSlider", "SaturationValue"])
	_ensure_row("ContrastRow", HBoxContainer, vbox, ["ContrastLabel", "ContrastSlider", "ContrastValue"])
	_ensure_row("VignetteRow", HBoxContainer, vbox, ["VignetteLabel", "VignetteSlider", "VignetteValue"])
	_ensure_row("GrainRow", HBoxContainer, vbox, ["GrainLabel", "GrainSlider", "GrainValue"])
	_ensure_row("BloomRow", HBoxContainer, vbox, ["BloomLabel", "BloomSlider", "BloomValue"])
	_ensure_row("PresetsRow", HBoxContainer, vbox, ["PresetsLabel", "PresetsOptions"])
	_ensure_row("PresetNameRow", HBoxContainer, vbox, ["PresetNameLabel", "PresetName"])
	_ensure_row("PresetButtonsRow", HBoxContainer, vbox, ["PresetSave", "PresetLoad", "PresetDelete"])
	_ensure_row("ButtonsRow", HBoxContainer, vbox, ["CaptureButton", "CaptureLayersButton", "BackButton"])
	_ensure_row("PassesGrid", GridContainer, vbox, ["PassBeauty", "PassAlbedo", "PassNormals", "PassDepth", "PassLighting"])
	_ensure_row("LightRigGrid", GridContainer, vbox, [
		"LightColEnable", "LightColColor", "LightColIntensity", "LightColSpacer",
		"LightSectionKey", "LightSectionKeySep1", "LightSectionKeySep2", "LightSectionKeySep3",
		"KeyEnabled", "KeyColor", "KeyIntensity", "KeySpacer",
		"LightSectionFill", "LightSectionFillSep1", "LightSectionFillSep2", "LightSectionFillSep3",
		"FillEnabled", "FillColor", "FillIntensity", "FillSpacer",
		"LightSectionRim", "LightSectionRimSep1", "LightSectionRimSep2", "LightSectionRimSep3",
		"RimEnabled", "RimColor", "RimIntensity", "RimSpacer",
		"LightSectionTop", "LightSectionTopSep1", "LightSectionTopSep2", "LightSectionTopSep3",
		"TopEnabled", "TopColor", "TopIntensity", "TopSpacer",
		"LightSectionBounce", "LightSectionBounceSep1", "LightSectionBounceSep2", "LightSectionBounceSep3",
		"BounceEnabled", "BounceColor", "BounceIntensity", "BounceSpacer"
	])

	# Sweep stray Controls under PhotoUI into VBox
	if _ui_root and vbox:
		var ui_children := _ui_root.get_children().duplicate()
		for ch in ui_children:
			if ch is Control and ch != panel and ch != _guides and ch != _tabs_panel and ch != _viewfinder:
				_reparent(ch, vbox)
	# Sweep stray Controls under Margin into VBox
	if margin and vbox:
		var margin_children := margin.get_children().duplicate()
		for ch in margin_children:
			if ch is Control and ch != vbox:
				_reparent(ch, vbox)

func _on_always_show_viewport_toggled(pressed: bool) -> void:
	_always_show_viewport_enabled = pressed
	if pressed:
		_set_viewfinder_visible(true)
	else:
		# restore visibility based on current tab
		_set_viewfinder_visible(_current_tab == "Capture")

	# Setup contact strip container
	if _bottom_bar and _contact_strip == null:
		_contact_strip = _bottom_bar.get_node_or_null("ContactStrip") as HBoxContainer
		if _contact_strip == null:
			_contact_strip = HBoxContainer.new()
			_contact_strip.name = "ContactStrip"
			_contact_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_contact_strip.custom_minimum_size = Vector2(0, 88)
			_bottom_bar.add_child(_contact_strip)

	# Create capture preview dialog (lazy)
	if _capture_preview_panel == null:
		_capture_preview_panel = Window.new()
		_capture_preview_panel.name = "CapturePreview"
		_capture_preview_panel.window_title = "Capture Preview"
		_capture_preview_panel.resizable = true
		_capture_preview_panel.rect_min_size = Vector2(400, 300)
		add_child(_capture_preview_panel)
		var img = TextureRect.new()
		img.name = "PreviewImage"
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_capture_preview_panel.add_child(img)

func _debug_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _ui_root and _ui_root.get_node_or_null("RootMargin") == null:
		_ensure_ui_layout()
		await get_tree().process_frame
	if _ui_root == null:
		print("[PhotoMode] _ui_root missing")
		return

	var c := _ui_root
	var p := c.get_parent()
	var parent_ctrl := p as Control
	var root_margin := _ui_root.get_node_or_null("RootMargin") as Control
	var root_hbox := _ui_root.get_node_or_null("RootMargin/RootHBox") as Control
	var panel := _ui_root.get_node_or_null("RootMargin/RootHBox/Panel") as Control

	print("[PhotoMode] ui_root size=", c.size, " global=", c.global_position,
		" anchors=", Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom),
		" offsets=", Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom))
	if root_margin == null:
		print("[PhotoMode] RootMargin missing. PhotoUI children:", c.get_children())
		var canvas_layer := get_node_or_null("CanvasLayer")
		if canvas_layer:
			var layer_controls: Array[String] = []
			for ch in canvas_layer.get_children():
				if ch is Control:
					layer_controls.append(ch.name)
			print("[PhotoMode] CanvasLayer controls:", layer_controls)
		var root_controls: Array[String] = []
		for ch in get_children():
			if ch is Control:
				root_controls.append(ch.name)
		print("[PhotoMode] Root controls:", root_controls)
		var mangled: Array[String] = []
		for n in find_children("*", "Control", true, false):
			if String(n.name).find("CanvasLayer_PhotoUI") != -1:
				mangled.append(String(n.name))
		print("[PhotoMode] Mangled controls:", mangled)
	if root_margin:
		print("[PhotoMode] RootMargin size=", root_margin.size, " global=", root_margin.global_position,
			" anchors=", Vector4(root_margin.anchor_left, root_margin.anchor_top, root_margin.anchor_right, root_margin.anchor_bottom),
			" offsets=", Vector4(root_margin.offset_left, root_margin.offset_top, root_margin.offset_right, root_margin.offset_bottom))
	if root_hbox:
		print("[PhotoMode] RootHBox size=", root_hbox.size, " global=", root_hbox.global_position)
	if panel:
		print("[PhotoMode] Panel size=", panel.size, " global=", panel.global_position)

	print("[PhotoMode] parent=", p, " parent_is_control=", parent_ctrl != null,
		" parent_size=", (parent_ctrl.size if parent_ctrl else Vector2(-1, -1)))

	var tabs := _ui_root.get_node_or_null("RootMargin/RootHBox/TabsPanel") as Control
	if tabs:
		print("[PhotoMode] Tabs anchors:", tabs.anchor_left, tabs.anchor_top, tabs.anchor_right, tabs.anchor_bottom,
			" offsets:", tabs.offset_left, tabs.offset_top, tabs.offset_right, tabs.offset_bottom,
			" size:", tabs.size)


func _ensure_row(row_name: String, type_class: Variant, parent: Node, child_names: Array) -> void:
	if parent == null:
		return
	var row := _get_or_create_container(row_name, type_class, parent)
	if row is Control:
		(row as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child_name in child_names:
		_reparent_by_name(child_name, row)
		var node := row.get_node_or_null(child_name)
		if node == null and (child_name.ends_with("Label") or child_name.ends_with("Header")):
			var label := Label.new()
			label.name = child_name
			label.text = _label_text_for(child_name)
			row.add_child(label)
			node = label
		if node is Control:
			(node as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if node is Label:
				(node as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				(node as Label).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				(node as Label).custom_minimum_size = Vector2(90, 0)


func _label_text_for(name_hint: String) -> String:
	var map := {
		"FOVLabel": "FOV",
		"FocalLabel": "Focal",
		"ISOLabel": "ISO",
		"ApertureLabel": "Aperture",
		"ShutterLabel": "Shutter",
		"FocusLabel": "Focus",
		"ShootingModeLabel": "Shooting",
		"AutoFocusLabel": "Auto Focus",
		"ExposureLabel": "Exposure",
		"AutoExposureLabel": "Auto Exposure",
		"AutoExposureSpeedLabel": "AE Speed",
		"AutoExposureRangeLabel": "AE Range",
		"EnvLabel": "Environment",
		"ResLabel": "Resolution",
		"AspectLabel": "Aspect",
		"CaptureFormatLabel": "Format",
		"CapturePathLabel": "Save Path",
		"GuidesOpacityLabel": "Opacity",
		"SunAngleLabel": "Sun",
		"AmbientLabel": "Ambient",
		"FogLabel": "Fog",
		"TempLabel": "Temperature",
		"TintLabel": "Tint",
		"SaturationLabel": "Saturation",
		"ContrastLabel": "Contrast",
		"VignetteLabel": "Vignette",
		"GrainLabel": "Grain",
		"BloomLabel": "Bloom",
		"PresetsLabel": "Preset",
		"PresetNameLabel": "Name",
		"PassesLabel": "Passes",
		"PassPreviewLabel": "Preview",
		"LightRigLabel": "Lighting",
		"LightColEnable": "Enable",
		"LightColColor": "Color",
		"LightColIntensity": "Intensity",
		"LightSectionKey": "Key",
		"LightSectionFill": "Fill",
		"LightSectionRim": "Rim",
		"LightSectionTop": "Top",
		"LightSectionBounce": "Bounce",
		"ExposureHeader": "Exposure",
		"GuidesHeader": "Guides",
		"CaptureHeader": "Capture",
		"PassesHeader": "Passes",
		"LightRigHeader": "Lighting",
		"EnvironmentHeader": "Environment",
		"ExportHeader": "Export",
		"ColorHeader": "Color",
		"EffectsHeader": "Effects",
		"CompositionHeader": "Composition",
		"PresetsHeader": "Presets"
	}
	if name_hint in map:
		return map[name_hint]
	var cleaned := name_hint
	cleaned = cleaned.replace("Header", "")
	cleaned = cleaned.replace("Label", "")
	cleaned = cleaned.replace("Row", "")
	return cleaned


func _ensure_camera_active() -> void:
	if _camera == null:
		return
	_camera.current = true


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
	if node == null:
		for n in find_children("*", "", true, false):
			if String(n.name).find(name) != -1:
				node = n
				break
	if node != null:
		_reparent(node, new_parent)


func _reparent(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null:
		return
	if node == new_parent:
		return
	if node.is_ancestor_of(new_parent):
		return
	if node.get_parent() == new_parent:
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)


func _setup_pass_materials() -> void:
	_normal_pass_material = ShaderMaterial.new()
	_normal_pass_material.shader = Shader.new()
	_normal_pass_material.shader.code = """
shader_type spatial;
render_mode unshaded;
void fragment() {
	vec3 n = normalize(NORMAL);
	ALBEDO = n * 0.5 + vec3(0.5);
}
"""

	_depth_pass_material = ShaderMaterial.new()
	_depth_pass_material.shader = Shader.new()
	_depth_pass_material.shader.code = """
shader_type spatial;
render_mode unshaded;
uniform float u_far = 2000.0;
varying float v_depth;
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v_depth = clamp(-view.z / max(u_far, 0.001), 0.0, 1.0);
}
void fragment() {
	ALBEDO = vec3(v_depth);
}
"""


func _setup_light_rig_ui() -> void:
	_setup_single_light(_key_light, _key_enabled, _key_color, _key_intensity)
	_setup_single_light(_fill_light, _fill_enabled, _fill_color, _fill_intensity)
	_setup_single_light(_rim_light, _rim_enabled, _rim_color, _rim_intensity)
	_setup_single_light(_top_light, _top_enabled, _top_color, _top_intensity)
	_setup_single_light(_bounce_light, _bounce_enabled, _bounce_color, _bounce_intensity)


func _setup_single_light(light: DirectionalLight3D, enabled: CheckBox, color: ColorPickerButton, intensity: HSlider) -> void:
	if light == null:
		return
	if enabled:
		if enabled.has_method("set_pressed_no_signal"):
			enabled.set_pressed_no_signal(light.visible)
		else:
			enabled.button_pressed = light.visible
		enabled.toggled.connect(func(pressed: bool):
			light.visible = pressed
		)
	if color:
		color.color = light.light_color
		color.color_changed.connect(func(c: Color):
			light.light_color = c
		)
	if intensity:
		if intensity.has_method("set_value_no_signal"):
			intensity.set_value_no_signal(light.light_energy)
		else:
			intensity.value = light.light_energy
		intensity.value_changed.connect(func(v: float):
			light.light_energy = v
		)


func _on_export_state_pressed() -> void:
	var path := "user://photo_mode_state.json"
	if _capture_path_edit and _capture_path_edit.text.strip_edges() != "":
		path = _capture_path_edit.text.strip_edges()
	export_photo_mode_state(path)


func _on_import_state_pressed() -> void:
	var path := "user://photo_mode_state.json"
	if _capture_path_edit and _capture_path_edit.text.strip_edges() != "":
		path = _capture_path_edit.text.strip_edges()
	import_photo_mode_state(path)


func _build_map_from_debug() -> void:
	if _status:
		_status.text = "Building map…"
	var dbg := get_node_or_null("/root/DEBUG")
	var map_path := ""
	if dbg != null and "pending_photo_map_path" in dbg:
		map_path = String(dbg.pending_photo_map_path)
	if map_path.is_empty():
		if _status:
			_status.text = "No map selected (open debug menu with F1)"
		return

	_map = FuncGodotMap.new()
	_map.name = "FuncGodotMap"
	_map.local_map_file = map_path
	add_child(_map)

	var ok := await _build_map(_map, _status)
	if not ok:
		return

	# Spawn fallback entities after build.
	var setup := Node3D.new()
	setup.name = "HomeSetup"
	setup.set_script(HOME_SETUP_SCRIPT)
	add_child(setup)
	if "auto_run" in setup:
		setup.auto_run = false
	if setup.has_method("run_setup"):
		await setup.call("run_setup")

	if _status:
		_status.text = ""


func _build_map(map: FuncGodotMap, status: Label) -> bool:
	var done := [false]
	var success := [false]

	map.build_progress.connect(func(step, progress):
		if status:
			status.text = "Building %s (%d%%)" % [String(step), int(progress * 100.0)]
	)
	map.build_complete.connect(func():
		done[0] = true
		success[0] = true
	)
	map.build_failed.connect(func():
		done[0] = true
		success[0] = false
		if status:
			status.text = "Build failed (see output)"
	)

	map.verify_and_build()
	while not done[0]:
		await get_tree().process_frame
	return success[0]


func _position_camera_at_start() -> void:
	if _camera == null:
		return
	var starts := find_children("*", "Marker3D", true, false)
	for s in starts:
		if s is InfoPlayerStart and (s as InfoPlayerStart).active:
			_camera.global_position = (s as InfoPlayerStart).global_position
			_camera.rotation_degrees = (s as InfoPlayerStart).angles
			return
	# Fallback: place near first mesh.
	if _map:
		var meshes := _map.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() > 0:
			var mesh := meshes[0] as MeshInstance3D
			if mesh:
				_camera.global_position = mesh.global_position + Vector3(0, 2.0, 0)



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_main_menu_overlay()
		get_viewport().set_input_as_handled()
		return

	if _menu_overlay and _menu_overlay.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_toggle_guides()
			return
		elif event.keycode == KEY_F3:
			_exit_to_spectator_mode()
			return
		elif event.keycode == KEY_F4:
			_toggle_ui()
			return
		elif event.shift_pressed and event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_toggle_light_shortcut(event.keycode)
			return
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			var idx := int(event.keycode - KEY_1) + 1
			if event.ctrl_pressed:
				_bookmarks[idx] = {
					"position": _camera.global_position,
					"rotation": _camera.rotation_degrees
				}
				if _status:
					_status.text = "Saved bookmark %d" % idx
				return
			if idx in _bookmarks:
				var bm: Dictionary = _bookmarks[idx] as Dictionary
				_camera.global_position = bm["position"] as Vector3
				_camera.rotation_degrees = bm["rotation"] as Vector3
				_yaw = _camera.rotation_degrees.y
				_pitch = _camera.rotation_degrees.x
				if _status:
					_status.text = "Loaded bookmark %d" % idx
				return

	if _ui_visible:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sens
		_pitch = clamp(_pitch - event.relative.y * mouse_sens, -89.0, 89.0)
		_camera.rotation_degrees = Vector3(_pitch, _yaw, 0.0)


func _process(delta: float) -> void:
	if enable_runtime_layout_repair and _ui_root and _layout_retry_frames < 20:
		if _ui_root.get_node_or_null("RootMargin") == null:
			_layout_retry_frames += 1
			_ensure_ui_layout()
	if _auto_focus_enabled:
		_auto_focus_timer -= delta
		if _auto_focus_timer <= 0.0:
			_auto_focus_timer = 0.2
			_update_auto_focus()
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_update_viewfinder()
	if _camera == null:
		return
	var input_vec := Input.get_vector("left", "right", "forward", "back")
	var dir := (_camera.transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	var up := 0.0
	if Input.is_action_pressed("jump"):
		up += 1.0
	if Input.is_action_pressed("crouch"):
		up -= 1.0
	var vel := dir + Vector3.UP * up
	if vel.length() > 0.0:
		vel = vel.normalized()
	var speed := move_speed
	if Input.is_action_pressed("sprint"):
		speed *= fast_multiplier
	_camera.global_position += vel * speed * delta


func _exit_to_spectator_mode() -> void:
	var dbg := get_node_or_null("/root/DEBUG")
	var map_path := ""
	if _map and "local_map_file" in _map:
		map_path = String(_map.local_map_file)
	if map_path.is_empty() and dbg != null and "pending_photo_map_path" in dbg:
		map_path = String(dbg.pending_photo_map_path)
	if dbg != null:
		if "pending_runtime_map_path" in dbg:
			dbg.pending_runtime_map_path = map_path
		if "pending_force_spectator" in dbg:
			dbg.pending_force_spectator = true
	get_tree().change_scene_to_file("res://scenes/runtime_map_play.tscn")


func _update_auto_focus() -> void:
	if _camera == null:
		return
	var space_state := get_world_3d().direct_space_state if get_world_3d() else null
	if space_state == null:
		return
	var from_pos := _camera.global_position
	var to_pos := from_pos + (-_camera.global_transform.basis.z) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [self]
	var hit := space_state.intersect_ray(query)
	if hit and hit.has("position"):
		var dist := from_pos.distance_to(hit["position"])
		_focus_distance = dist
		_set_slider_value(_focus_slider, dist)
		if _focus_value:
			_focus_value.text = "%.1fm" % dist
		_apply_depth_of_field()


func _toggle_light_shortcut(keycode: int) -> void:
	match keycode:
		KEY_1:
			if _key_enabled:
				_key_enabled.button_pressed = not _key_enabled.button_pressed
		KEY_2:
			if _fill_enabled:
				_fill_enabled.button_pressed = not _fill_enabled.button_pressed
		KEY_3:
			if _rim_enabled:
				_rim_enabled.button_pressed = not _rim_enabled.button_pressed
		KEY_4:
			if _top_enabled:
				_top_enabled.button_pressed = not _top_enabled.button_pressed
		KEY_5:
			if _bounce_enabled:
				_bounce_enabled.button_pressed = not _bounce_enabled.button_pressed


func _toggle_ui() -> void:
	_ui_visible = not _ui_visible
	if _ui_root:
		_ui_root.visible = _ui_visible
	if _ui_visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _menu_overlay and _menu_overlay.visible:
		_menu_overlay.visible = false


func _toggle_guides() -> void:
	if _guides:
		_guides.visible = not _guides.visible
		if _guides_check:
			_guides_check.button_pressed = _guides.visible


func _setup_collapsibles() -> void:
	_section_collapsed = {
		"Exposure": false,
		"Guides": false,
		"Capture": false,
		"Passes": false,
		"Light": false
	}
	if _exposure_collapse:
		_exposure_collapse.toggled.connect(func(pressed: bool):
			_set_section_collapsed("Exposure", pressed)
		)
	if _guides_collapse:
		_guides_collapse.toggled.connect(func(pressed: bool):
			_set_section_collapsed("Guides", pressed)
		)
	if _capture_collapse:
		_capture_collapse.toggled.connect(func(pressed: bool):
			_set_section_collapsed("Capture", pressed)
		)
	if _passes_collapse:
		_passes_collapse.toggled.connect(func(pressed: bool):
			_set_section_collapsed("Passes", pressed)
		)
	if _light_collapse:
		_light_collapse.toggled.connect(func(pressed: bool):
			_set_section_collapsed("Light", pressed)
		)


func _set_section_collapsed(section: String, collapsed: bool) -> void:
	_section_collapsed[section] = collapsed
	_apply_collapsed()


func _setup_tabs() -> void:
	var tabs := {
		"Camera": _find_node("TabCamera", "Button"),
		"Exposure": _find_node("TabExposure", "Button"),
		"Guides": _find_node("TabGuides", "Button"),
		"Capture": _find_node("TabCapture", "Button"),
		"Passes": _find_node("TabPasses", "Button"),
		"Light": _find_node("TabLight", "Button"),
		"Environment": _find_node("TabEnvironment", "Button"),
		"Export": _find_node("TabExport", "Button"),
		"Color": _find_node("TabColor", "Button"),
		"Effects": _find_node("TabEffects", "Button"),
		"Composition": _find_node("TabComposition", "Button"),
		"Presets": _find_node("TabPresets", "Button")
	}
	_tab_buttons.clear()
	for key in tabs.keys():
		var btn: Variant = tabs[key]
		if btn is Button:
			var b := btn as Button
			b.toggle_mode = true
			b.pressed.connect(func():
				_apply_tab(key)
			)
			_tab_buttons[key] = b
	_apply_tab("Camera")


func _populate_focal_options() -> void:
	if _focal_options == null:
		return
	_focal_options.clear()
	var presets := [18, 24, 35, 50, 70, 85, 105, 135, 200]
	for f in presets:
		_focal_options.add_item("%dmm" % f)
	_focal_options.select(3)


func _populate_shooting_modes() -> void:
	if _shooting_mode_options == null:
		return
	_shooting_mode_options.clear()
	var modes := ["Auto", "Portrait", "Outside"]
	for mode in modes:
		_shooting_mode_options.add_item(mode)
	_shooting_mode_options.select(0)
	_on_shooting_mode_selected(0)


func _populate_pass_preview() -> void:
	if _pass_preview_options == null:
		return
	_pass_preview_options.clear()
	var items := ["Off", "Beauty", "Albedo", "Normals", "Depth", "Lighting"]
	for item in items:
		_pass_preview_options.add_item(item)
	_pass_preview_options.select(0)
	_on_pass_preview_selected(0)


func _populate_resolution_options() -> void:
	if _res_options == null:
		return
	_res_options.clear()
	var items := [
		{"label": "Viewport (1x)", "mode": "multiplier", "value": 1.0},
		{"label": "2x", "mode": "multiplier", "value": 2.0},
		{"label": "4x", "mode": "multiplier", "value": 4.0},
		{"label": "8 MP", "mode": "megapixels", "value": 8.0},
		{"label": "12 MP", "mode": "megapixels", "value": 12.0},
		{"label": "16 MP", "mode": "megapixels", "value": 16.0},
		{"label": "18 MP", "mode": "megapixels", "value": 18.0},
		{"label": "24 MP", "mode": "megapixels", "value": 24.0},
		{"label": "48 MP", "mode": "megapixels", "value": 48.0}
	]
	for i in range(items.size()):
		var item: Dictionary = items[i]
		_res_options.add_item(String(item["label"]))
		_res_options.set_item_metadata(i, item)
	_res_options.select(0)
	_on_resolution_selected(0)


func _populate_aspect_options() -> void:
	if _aspect_options == null:
		return
	_aspect_options.clear()
	var items := [
		{"label": "Viewport", "ratio": 0.0},
		{"label": "16:9", "ratio": 16.0 / 9.0},
		{"label": "3:2", "ratio": 3.0 / 2.0},
		{"label": "4:3", "ratio": 4.0 / 3.0},
		{"label": "1:1", "ratio": 1.0},
		{"label": "21:9", "ratio": 21.0 / 9.0},
		{"label": "9:16", "ratio": 9.0 / 16.0}
	]
	for i in range(items.size()):
		var item: Dictionary = items[i]
		_aspect_options.add_item(String(item["label"]))
		_aspect_options.set_item_metadata(i, item)
	_aspect_options.select(0)
	_on_aspect_selected(0)


func _apply_tab(tab_name: String) -> void:
	_current_tab = tab_name
	for k in _tab_buttons.keys():
		var b := _tab_buttons[k] as Button
		if b:
			b.button_pressed = (k == tab_name)
	if _status == null:
		_status = _find_node("Status", "Label") as Label
	var title_label := _find_node("Title", "Label") as Label
	if title_label:
		var title_map := {
			"Camera": "Camera",
			"Exposure": "Exposure",
			"Guides": "Guides",
			"Capture": "Capture",
			"Passes": "Passes",
			"Light": "Lighting",
			"Environment": "Environment",
			"Export": "Export",
			"Color": "Color",
			"Effects": "Effects",
			"Composition": "Composition",
			"Presets": "Presets"
		}
		title_label.text = String(title_map.get(tab_name, tab_name))

	var always := ["HistogramCard", "Title", "Status"]
	var camera := ["FOVRow", "FocalRow", "ISORow", "ApertureRow", "ShutterRow", "FocusRow", "ShootingModeRow", "AutoFocusRow"]
	var exposure := ["ExposureHeaderRow", "ExposureRow", "AutoExposureRow", "AutoExposureSpeedRow", "AutoExposureRangeRow"]
	var guides := ["GuidesHeaderRow", "GuidesRow", "GuideTypeOptions", "GuidesOpacityRow"]
	var capture := ["CaptureHeaderRow", "ResRow", "AspectRow", "CaptureFormatRow", "CapturePathRow", "ButtonsRow"]
	var passes := ["PassesHeaderRow", "PassPreviewRow", "PassesGrid"]
	var light := ["LightRigHeaderRow", "LightRigGrid"]
	var environment := ["EnvironmentHeaderRow", "EnvRow", "EnvironmentRow", "AmbientRow", "FogRow"]
	var export := ["ExportHeaderRow", "ExportNote", "CaptureHeaderRow", "ButtonsRow", "PassesHeaderRow", "PassesGrid"]
	var color := ["ColorHeaderRow", "TempRow", "TintRow", "SaturationRow", "ContrastRow"]
	var effects := ["EffectsHeaderRow", "VignetteRow", "GrainRow", "BloomRow"]
	var composition := ["CompositionHeaderRow", "CompositionNote"]
	var presets := ["PresetsHeaderRow", "PresetsRow", "PresetNameRow", "PresetButtonsRow"]
	var pass_leaves := ["PassBeauty", "PassNormals", "PassAlbedo", "PassDepth", "PassLighting"]
	var light_leaves := [
		"LightColEnable", "LightColColor", "LightColIntensity", "LightColSpacer",
		"LightSectionKey", "LightSectionKeySep1", "LightSectionKeySep2", "LightSectionKeySep3",
		"LightSectionFill", "LightSectionFillSep1", "LightSectionFillSep2", "LightSectionFillSep3",
		"LightSectionRim", "LightSectionRimSep1", "LightSectionRimSep2", "LightSectionRimSep3",
		"LightSectionTop", "LightSectionTopSep1", "LightSectionTopSep2", "LightSectionTopSep3",
		"LightSectionBounce", "LightSectionBounceSep1", "LightSectionBounceSep2", "LightSectionBounceSep3",
		"KeyEnabled", "FillEnabled", "RimEnabled", "TopEnabled", "BounceEnabled",
		"KeyColor", "FillColor", "RimColor", "TopColor", "BounceColor",
		"KeyIntensity", "FillIntensity", "RimIntensity", "TopIntensity", "BounceIntensity"
	]
	var non_camera_leaves := [
		"GoldenCheck", "SafeCheck", "DiagonalCheck", "DiagonalAltCheck", "SpiralCheck",
		"ExposureHeaderRow", "ExposureRow", "GuidesOpacityRow",
		"CaptureButton", "CaptureLayersButton", "BackButton",
		"PassBeauty", "PassNormals", "PassAlbedo", "PassDepth", "PassLighting",
		"LightColEnable", "LightColColor", "LightColIntensity", "LightColSpacer",
		"LightSectionKey", "LightSectionKeySep1", "LightSectionKeySep2", "LightSectionKeySep3",
		"LightSectionFill", "LightSectionFillSep1", "LightSectionFillSep2", "LightSectionFillSep3",
		"LightSectionRim", "LightSectionRimSep1", "LightSectionRimSep2", "LightSectionRimSep3",
		"LightSectionTop", "LightSectionTopSep1", "LightSectionTopSep2", "LightSectionTopSep3",
		"LightSectionBounce", "LightSectionBounceSep1", "LightSectionBounceSep2", "LightSectionBounceSep3",
		"KeyEnabled", "FillEnabled", "RimEnabled", "TopEnabled", "BounceEnabled",
		"KeyColor", "FillColor", "RimColor", "TopColor", "BounceColor",
		"KeyIntensity", "FillIntensity", "RimIntensity", "TopIntensity", "BounceIntensity"
	]

	var all_nodes := always + camera + exposure + guides + capture + passes + light + environment + export + color + effects + composition + presets + non_camera_leaves
	var vbox := _ui_root.get_node_or_null("RootMargin/RootHBox/Panel/Margin/VBox") if _ui_root else null
	if vbox is Control:
		for child in vbox.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
	for name in all_nodes:
		var node := _find_node(name, "")
		if node is CanvasItem:
			(node as CanvasItem).visible = false

	var show_list: Array = []
	match tab_name:
		"Camera":
			show_list = always + camera
		"Exposure":
			show_list = always + exposure
		"Guides":
			show_list = always + guides
		"Capture":
			show_list = always + capture
		"Passes":
			show_list = always + passes + pass_leaves
		"Light":
			show_list = always + light + light_leaves
		"Environment":
			show_list = always + environment
		"Export":
			show_list = always + export
		"Color":
			show_list = always + color
		"Effects":
			show_list = always + effects
		"Composition":
			show_list = always + composition
		"Presets":
			show_list = always + presets
		_:
			show_list = always + camera

	for name in show_list:
		var node2 := _find_node(name, "")
		if node2 is CanvasItem:
			(node2 as CanvasItem).visible = true
	_apply_collapsed()
	# Respect the Always Show Viewport toggle: keep viewfinder visible if enabled
	_set_viewfinder_visible(_always_show_viewport_enabled or tab_name == "Capture")
	if tab_name != "Passes":
		_clear_pass_preview()


func _apply_collapsed() -> void:
	var map := {
		"Exposure": ["ExposureRow"],
		"Guides": ["GuidesRow", "GuidesRow2", "GuidesOpacityRow"],
		"Capture": ["ResRow", "AspectRow", "CaptureFormatRow", "CapturePathRow", "ButtonsRow"],
		"Passes": ["PassPreviewRow", "PassesGrid"],
		"Light": ["LightRigGrid"]
	}
	for section in map.keys():
		var collapsed := bool(_section_collapsed.get(section, false))
		for node_name in map[section]:
			var node := _find_node(node_name, "")
			if node is CanvasItem and (node as CanvasItem).visible:
				(node as CanvasItem).visible = not collapsed


func _toggle_main_menu_overlay() -> void:
	if _menu_overlay == null:
		_create_main_menu_overlay()
	if _menu_overlay == null:
		return
	_menu_overlay.visible = not _menu_overlay.visible
	if _menu_overlay.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if _ui_root:
			_ui_root.visible = true
			_ui_visible = true
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if _ui_visible else Input.MOUSE_MODE_CAPTURED)


func _create_main_menu_overlay() -> void:
	if MAIN_MENU_SCENE == null:
		return
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "PhotoMenuLayer"
	_menu_layer.layer = 100
	add_child(_menu_layer)
	_menu_overlay = MAIN_MENU_SCENE.instantiate() as Control
	if _menu_overlay:
		_menu_overlay.name = "PhotoMenuOverlay"
		_menu_overlay.visible = false
		_menu_layer.add_child(_menu_overlay)
		_menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _on_fov_changed(value: float) -> void:
	if _camera:
		_camera.fov = value
	if _fov_value:
		_fov_value.text = "%d°" % int(round(value))


func _on_focal_selected(index: int) -> void:
	var focal := float(_focal_options.get_item_text(index).replace("mm", ""))
	# Approximate FOV for 36mm sensor width.
	var fov := rad_to_deg(2.0 * atan(36.0 / (2.0 * focal)))
	if _fov_slider:
		_fov_slider.value = fov


func _on_iso_changed(value: float) -> void:
	_iso_current = value
	if _camera and _camera.attributes is CameraAttributesPhysical:
		_set_attr_if_exists(_camera.attributes, "iso", value)
	if _iso_value:
		_iso_value.text = "%d" % int(value)
	_apply_physical_exposure()


func _on_aperture_changed(value: float) -> void:
	_aperture_current = value
	if _camera and _camera.attributes is CameraAttributesPhysical:
		_set_attr_if_exists(_camera.attributes, "aperture", value)
		_set_attr_if_exists(_camera.attributes, "f_stop", value)
		_set_attr_if_exists(_camera.attributes, "fstop", value)
	if _aperture_value:
		_aperture_value.text = "f/%.1f" % value
	_apply_physical_exposure()


func _on_shutter_changed(value: float) -> void:
	_shutter_current = value
	if _camera and _camera.attributes is CameraAttributesPhysical:
		_set_attr_if_exists(_camera.attributes, "shutter_speed", value)
	if _shutter_value:
		var denom := int(round(1.0 / maxf(value, 0.0001)))
		_shutter_value.text = "1/%d" % denom
	_apply_physical_exposure()


func _on_focus_changed(value: float) -> void:
	_focus_distance = value
	if _focus_value:
		_focus_value.text = "%.1fm" % value
	_apply_depth_of_field()


func _on_shooting_mode_selected(index: int) -> void:
	if _shooting_mode_options == null:
		return
	var mode := _shooting_mode_options.get_item_text(index)
	var iso := 400.0
	var aperture := 2.8
	var shutter := 1.0 / 60.0
	match mode:
		"Portrait":
			iso = 400.0
			aperture = 2.0
			shutter = 1.0 / 125.0
		"Outside":
			iso = 100.0
			aperture = 8.0
			shutter = 1.0 / 250.0
		_:
			pass
	_set_slider_value(_iso_slider, iso)
	_set_slider_value(_aperture_slider, aperture)
	_set_slider_value(_shutter_slider, shutter)
	_on_iso_changed(iso)
	_on_aperture_changed(aperture)
	_on_shutter_changed(shutter)


func _on_auto_focus_toggled(enabled: bool) -> void:
	_auto_focus_enabled = enabled
	if enabled:
		_auto_focus_timer = 0.0


func _on_auto_exposure_toggled(enabled: bool) -> void:
	_auto_exposure_enabled = enabled
	_apply_auto_exposure_settings()


func _on_auto_exposure_speed_changed(value: float) -> void:
	if _auto_exposure_speed_value:
		_auto_exposure_speed_value.text = "%.2f" % value
	_apply_auto_exposure_settings()


func _on_auto_exposure_min_changed(value: float) -> void:
	if _auto_exposure_min_value:
		_auto_exposure_min_value.text = "%.2f" % value
	_apply_auto_exposure_settings()


func _on_auto_exposure_max_changed(value: float) -> void:
	if _auto_exposure_max_value:
		_auto_exposure_max_value.text = "%.2f" % value
	_apply_auto_exposure_settings()


func _apply_auto_exposure_settings() -> void:
	if _world_env == null or _world_env.environment == null:
		return
	_set_attr_if_exists(_world_env.environment, "tonemap_auto_exposure_enabled", _auto_exposure_enabled)
	if _auto_exposure_speed_slider:
		_set_attr_if_exists(_world_env.environment, "tonemap_auto_exposure_speed", _auto_exposure_speed_slider.value)
	if _auto_exposure_min_slider:
		_set_attr_if_exists(_world_env.environment, "tonemap_auto_exposure_min_exposure", _auto_exposure_min_slider.value)
	if _auto_exposure_max_slider:
		_set_attr_if_exists(_world_env.environment, "tonemap_auto_exposure_max_exposure", _auto_exposure_max_slider.value)


func _set_slider_value(slider: HSlider, value: float) -> void:
	if slider == null:
		return
	if slider.has_method("set_value_no_signal"):
		slider.set_value_no_signal(value)
	else:
		slider.value = value


func _on_exposure_changed(value: float) -> void:
	_base_exposure = value
	if _world_env and _world_env.environment:
		_world_env.environment.tonemap_exposure = value
	if _exposure_value:
		_exposure_value.text = "%.2f" % value
	_apply_physical_exposure()


func _apply_physical_exposure() -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var ref_iso := 200.0
	var ref_aperture := 4.0
	var ref_shutter := 1.0 / 125.0
	var iso_factor := maxf(_iso_current, 1.0) / ref_iso
	var aperture_factor := (ref_aperture * ref_aperture) / maxf(_aperture_current * _aperture_current, 0.0001)
	var shutter_factor := maxf(_shutter_current, 0.000001) / ref_shutter
	var exposure_factor := iso_factor * aperture_factor * shutter_factor
	var exposure_comp := log(exposure_factor) / log(2.0)
	_world_env.environment.tonemap_exposure = _base_exposure + exposure_comp
	_apply_depth_of_field()
	_apply_motion_blur()


func _apply_depth_of_field() -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var focus := maxf(_focus_distance, 0.2)
	var ref_aperture := 4.0
	var blur_scale := clampf(ref_aperture / maxf(_aperture_current, 0.1), 0.5, 4.0)
	var amount := clampf((blur_scale - 1.0) * 0.15 + 0.04, 0.02, 0.6)
	_set_attr_if_exists(_world_env.environment, "dof_blur_far_enabled", amount > 0.03)
	_set_attr_if_exists(_world_env.environment, "dof_blur_near_enabled", amount > 0.03)
	_set_attr_if_exists(_world_env.environment, "dof_blur_far_distance", focus)
	_set_attr_if_exists(_world_env.environment, "dof_blur_near_distance", focus * 0.5)
	_set_attr_if_exists(_world_env.environment, "dof_blur_far_transition", maxf(1.0, focus * 0.25))
	_set_attr_if_exists(_world_env.environment, "dof_blur_near_transition", maxf(0.5, focus * 0.15))
	_set_attr_if_exists(_world_env.environment, "dof_blur_amount", amount)
	if _camera and _camera.attributes:
		_set_attr_if_exists(_camera.attributes, "dof_blur_far_enabled", amount > 0.03)
		_set_attr_if_exists(_camera.attributes, "dof_blur_near_enabled", amount > 0.03)
		_set_attr_if_exists(_camera.attributes, "dof_blur_far_distance", focus)
		_set_attr_if_exists(_camera.attributes, "dof_blur_near_distance", focus * 0.5)
		_set_attr_if_exists(_camera.attributes, "dof_blur_far_transition", maxf(1.0, focus * 0.25))
		_set_attr_if_exists(_camera.attributes, "dof_blur_near_transition", maxf(0.5, focus * 0.15))
		_set_attr_if_exists(_camera.attributes, "dof_blur_amount", amount)


func _apply_motion_blur() -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var ref_shutter := 1.0 / 125.0
	var ratio := maxf(_shutter_current, 0.000001) / ref_shutter
	var amount := clampf((ratio - 1.0) * 0.12, 0.0, 0.8)
	_set_attr_if_exists(_world_env.environment, "motion_blur_enabled", amount > 0.01)
	_set_attr_if_exists(_world_env.environment, "motion_blur_amount", amount)
	_set_attr_if_exists(_world_env.environment, "motion_blur_intensity", amount)


func _setup_environment_presets() -> void:
	_env_presets = {
		"Clear Day": {
			"sky_top": Color(0.45, 0.65, 0.95),
			"sky_horizon": Color(0.75, 0.85, 1.0),
			"ground": Color(0.2, 0.2, 0.25),
			"sun_rot": Vector3(-35, 45, 0),
			"sun_energy": 3.5,
			"sun_color": Color(1, 0.98, 0.92),
			"moon_energy": 0.0,
			"ambient": Color(0.6, 0.65, 0.7),
			"exposure": 0.0
		},
		"Golden Hour": {
			"sky_top": Color(0.85, 0.55, 0.35),
			"sky_horizon": Color(1.0, 0.72, 0.45),
			"ground": Color(0.25, 0.18, 0.12),
			"sun_rot": Vector3(-12, 25, 0),
			"sun_energy": 3.0,
			"sun_color": Color(1.0, 0.75, 0.45),
			"moon_energy": 0.0,
			"ambient": Color(0.5, 0.4, 0.35),
			"exposure": 0.15
		},
		"Overcast": {
			"sky_top": Color(0.6, 0.65, 0.7),
			"sky_horizon": Color(0.7, 0.72, 0.75),
			"ground": Color(0.2, 0.2, 0.22),
			"sun_rot": Vector3(-50, 40, 0),
			"sun_energy": 1.2,
			"sun_color": Color(0.9, 0.95, 1.0),
			"moon_energy": 0.0,
			"ambient": Color(0.65, 0.7, 0.75),
			"exposure": 0.2
		},
		"Night Moon": {
			"sky_top": Color(0.05, 0.06, 0.1),
			"sky_horizon": Color(0.12, 0.12, 0.18),
			"ground": Color(0.02, 0.02, 0.04),
			"sun_rot": Vector3(-80, 0, 0),
			"sun_energy": 0.2,
			"sun_color": Color(0.25, 0.35, 0.55),
			"moon_energy": 1.5,
			"ambient": Color(0.15, 0.18, 0.25),
			"exposure": 0.4
		},
		"Studio Neutral": {
			"sky_top": Color(0.35, 0.35, 0.35),
			"sky_horizon": Color(0.45, 0.45, 0.45),
			"ground": Color(0.1, 0.1, 0.1),
			"sun_rot": Vector3(-35, 45, 0),
			"sun_energy": 2.5,
			"sun_color": Color(1.0, 1.0, 1.0),
			"moon_energy": 0.0,
			"ambient": Color(0.4, 0.4, 0.4),
			"exposure": 0.0
		}
	}
	if _env_options:
		_env_options.clear()
		for name in _env_presets.keys():
			_env_options.add_item(name)
		var preferred := _load_env_preference()
		var default_index := 0
		for i in range(_env_options.item_count):
			var label := _env_options.get_item_text(i)
			if not preferred.is_empty() and label == preferred:
				default_index = i
				break
			if preferred.is_empty() and label == "Studio Neutral":
				default_index = i
		_env_options.select(default_index)
		_apply_environment_preset(_env_options.get_item_text(default_index))
	else:
		_apply_environment_preset("Clear Day")



func _on_environment_selected(index: int) -> void:
	if _env_options:
		var name := _env_options.get_item_text(index)
		_apply_environment_preset(name)
		_save_env_preference(name)



func _load_env_preference() -> String:
	var path := _get_env_preset_path()
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(content)
	if data is Dictionary and (data as Dictionary).has("name"):
		return String((data as Dictionary)["name"])
	return ""



func _save_env_preference(name: String) -> void:
	var path := _get_env_preset_path()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"name": name}))
	file.close()


func _apply_environment_preset(name: String) -> void:
	if not _env_presets.has(name):
		return
	var preset: Dictionary = _env_presets[name] as Dictionary
	if _world_env and _world_env.environment == null:
		_world_env.environment = Environment.new()
	var env := _world_env.environment
	if env:
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		_set_attr_if_exists(sky_mat, "sky_top_color", preset["sky_top"])
		_set_attr_if_exists(sky_mat, "sky_horizon_color", preset["sky_horizon"])
		_set_attr_if_exists(sky_mat, "ground_bottom_color", preset["ground"])
		_set_attr_if_exists(sky_mat, "ground_horizon_color", preset["ground"])
		_set_attr_if_exists(sky_mat, "ground_color", preset["ground"])
		sky.sky_material = sky_mat
		env.sky = sky
		env.ambient_light_color = preset["ambient"]
		env.ambient_light_energy = 1.0
		env.tonemap_exposure = preset["exposure"]

	if _key_light:
		_key_light.rotation_degrees = preset["sun_rot"]
		_key_light.light_energy = preset["sun_energy"]
		_key_light.light_color = preset["sun_color"]
		if _key_enabled:
			_key_enabled.button_pressed = preset["sun_energy"] > 0.01
		if _sun_angle_slider:
			_sun_angle_slider.value = (preset["sun_rot"] as Vector3).x

	if _rim_light:
		_rim_light.light_energy = preset["moon_energy"]
		_rim_light.light_color = Color(0.55, 0.65, 1.0)
		_rim_light.rotation_degrees = Vector3(-20, 220, 0)
		if _rim_enabled:
			_rim_enabled.button_pressed = preset["moon_energy"] > 0.01

	# Adjust exposure UI if present.
	if _exposure_slider:
		_exposure_slider.value = preset["exposure"]
	if _ambient_slider:
		_ambient_slider.value = 1.0
		_on_ambient_changed(_ambient_slider.value)


func _get_env_preset_path() -> String:
	# Returns a per-user path to store the environment preset preference
	return "user://photo_env_pref.json"


func _on_resolution_selected(_index: int) -> void:
	_update_viewfinder()


func _on_aspect_selected(_index: int) -> void:
	_update_viewfinder()


func _on_pass_preview_selected(_index: int) -> void:
	_apply_pass_preview()


func _get_preview_pass_name() -> String:
	if _pass_preview_options == null:
		return ""
	if _pass_preview_options.get_item_count() == 0 or _pass_preview_options.selected < 0:
		return ""
	var label := _pass_preview_options.get_item_text(_pass_preview_options.selected)
	match label:
		"Beauty":
			return PASS_BEAUTY
		"Albedo":
			return PASS_ALBEDO
		"Normals":
			return PASS_NORMALS
		"Depth":
			return PASS_DEPTH
		"Lighting":
			return PASS_LIGHTING
		_:
			return ""


func _apply_pass_preview() -> void:
	var pass_name := _get_preview_pass_name()
	if pass_name.is_empty():
		_restore_pass_state()
		return
	_apply_pass(pass_name)


func _clear_pass_preview() -> void:
	if _pass_preview_options:
		if _pass_preview_options.get_item_count() > 0:
			_pass_preview_options.select(0)
	_restore_pass_state()


func _on_sun_angle_changed(value: float) -> void:
	if _key_light:
		var rot := _key_light.rotation_degrees
		rot.x = value
		_key_light.rotation_degrees = rot
	if _sun_angle_value:
		_sun_angle_value.text = "%d°" % int(round(value))


func _on_ambient_changed(value: float) -> void:
	if _world_env and _world_env.environment:
		_set_attr_if_exists(_world_env.environment, "ambient_light_energy", value)
	if _ambient_value:
		_ambient_value.text = "%.2f" % value


func _on_temp_changed(value: float) -> void:
	if _temp_value:
		_temp_value.text = "%.2f" % value
	_apply_color_adjustments()


func _on_tint_changed(value: float) -> void:
	if _tint_value:
		_tint_value.text = "%.2f" % value
	_apply_color_adjustments()


func _on_saturation_changed(value: float) -> void:
	if _saturation_value:
		_saturation_value.text = "%.2f" % value
	_apply_color_adjustments()


func _on_contrast_changed(value: float) -> void:
	if _contrast_value:
		_contrast_value.text = "%.2f" % value
	_apply_color_adjustments()


func _apply_color_adjustments() -> void:
	if _world_env == null or _world_env.environment == null:
		return

	if enable_layout_debug_print:
		print("[PhotoMode DEBUG] _apply_color_adjustments: world_env=", _world_env, " env=", _world_env.environment)
		var props := []
		for p in _world_env.environment.get_property_list():
			props.append(p.name)
		print("[PhotoMode DEBUG] environment properties sample=", props.slice(0, 30))
	_set_attr_if_exists(_world_env.environment, "adjustment_enabled", true)
	if _saturation_slider:
		_set_attr_if_exists(_world_env.environment, "adjustment_saturation", _saturation_slider.value)
	if _contrast_slider:
		_set_attr_if_exists(_world_env.environment, "adjustment_contrast", _contrast_slider.value)

	var temp := _temp_slider.value if _temp_slider else 0.0
	var tint := _tint_slider.value if _tint_slider else 0.0
	var warm := temp * 0.15
	var green := tint * 0.1
	var color := Color(1.0 + warm, 1.0 + green, 1.0 - warm, 1.0)
	color.r = clampf(color.r, 0.6, 1.4)
	color.g = clampf(color.g, 0.6, 1.4)
	color.b = clampf(color.b, 0.6, 1.4)
	# Primary: set environment adjustment color
	_set_attr_if_exists(_world_env.environment, "adjustment_color", color)
	# Fallbacks: some engine versions expose different property names
	_set_attr_if_exists(_world_env.environment, "adjustment_color_correction", color)

	# Also nudge key light and ambient color so temperature/tint are visible even if env adjustment isn't effective
	if _key_light:
		# blend key_light color with computed adjustment
		_key_light.light_color = _key_light.light_color.lerp(color, 0.25)
	# Also try nudging ambient_light_color on the environment (if present)
	_set_attr_if_exists(_world_env.environment, "ambient_light_color", color)


func _on_vignette_changed(value: float) -> void:
	if _vignette_value:
		_vignette_value.text = "%.2f" % value
	if _world_env and _world_env.environment:
		if enable_layout_debug_print:
			print("[PhotoMode DEBUG] setting vignette to", value)
		_set_attr_if_exists(_world_env.environment, "vignette_enabled", value > 0.001)
		_set_attr_if_exists(_world_env.environment, "vignette_intensity", value)
		_set_attr_if_exists(_world_env.environment, "vignette_smoothness", 0.5)
		_set_attr_if_exists(_world_env.environment, "vignette_roundness", 0.5)
		# Fallback names for other engine variants
		_set_attr_if_exists(_world_env.environment, "vignette", value)
		_set_attr_if_exists(_world_env.environment, "vignette_strength", value)


func _on_grain_changed(value: float) -> void:
	if _grain_value:
		_grain_value.text = "%.2f" % value
	if _world_env and _world_env.environment:
		if enable_layout_debug_print:
			print("[PhotoMode DEBUG] setting grain to", value)
		_set_attr_if_exists(_world_env.environment, "film_grain", value)
		_set_attr_if_exists(_world_env.environment, "film_grain_enabled", value > 0.001)
		_set_attr_if_exists(_world_env.environment, "grain_strength", value)
		_set_attr_if_exists(_world_env.environment, "grain", value)
		# Older/newer variants
		_set_attr_if_exists(_world_env.environment, "film_grain_amount", value)


func _on_bloom_changed(value: float) -> void:
	if _bloom_value:
		_bloom_value.text = "%.2f" % value
	if _world_env and _world_env.environment:
		_set_attr_if_exists(_world_env.environment, "glow_enabled", value > 0.001)
		_set_attr_if_exists(_world_env.environment, "glow_intensity", value)
		_set_attr_if_exists(_world_env.environment, "glow_strength", value)
		_set_attr_if_exists(_world_env.environment, "glow_bloom", value)


func _on_guides_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_guides_enabled"):
		_guides.call("set_guides_enabled", pressed)


func _populate_guide_types() -> void:
	if _guide_type_options == null:
		return
	_guide_type_options.clear()
	var types := ["None", "Thirds", "Golden", "Diagonal", "Spiral", "Safe"]
	for t in types:
		_guide_type_options.add_item(t)
	_guide_type_options.select(1)
	_on_guide_type_selected(1)


func _on_guide_type_selected(index: int) -> void:
	if _guide_type_options == null:
		return
	var label := _guide_type_options.get_item_text(index)
	if _guides:
		_guides.call("set_thirds_enabled", false)
		_guides.call("set_golden_enabled", false)
		_guides.call("set_diagonals_enabled", false)
		_guides.call("set_spiral_enabled", false)
		_guides.call("set_safe_frame_enabled", false)
		match label:
			"Thirds":
				_guides.call("set_thirds_enabled", true)
			"Golden":
				_guides.call("set_golden_enabled", true)
			"Diagonal":
				_guides.call("set_diagonals_enabled", true)
			"Spiral":
				_guides.call("set_spiral_enabled", true)
			"Safe":
				_guides.call("set_safe_frame_enabled", true)
			_:
				pass


func _on_golden_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_golden_enabled"):
		_guides.call("set_golden_enabled", pressed)


func _on_safe_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_safe_frame_enabled"):
		_guides.call("set_safe_frame_enabled", pressed)


func _on_diagonal_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_diagonals_enabled"):
		_guides.call("set_diagonals_enabled", pressed)


func _on_diagonal_alt_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_diagonals_alt_enabled"):
		_guides.call("set_diagonals_alt_enabled", pressed)


func _on_spiral_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_spiral_enabled"):
		_guides.call("set_spiral_enabled", pressed)


func _on_guides_opacity_changed(value: float) -> void:
	if _guides and _guides.has_method("set_opacity"):
		_guides.call("set_opacity", value)
	if _guides_opacity_value:
		_guides_opacity_value.text = "%.2f" % value


func _load_presets() -> void:
	_presets_cache.clear()
	if _presets_options:
		_presets_options.clear()
	var path := "user://photo_presets.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(content)
	if data is Array:
		_presets_cache.clear()
		for item in data:
			if item is Dictionary:
				_presets_cache.append(item)
		if _presets_options:
			for p: Dictionary in _presets_cache:
				if p.has("name"):
					_presets_options.add_item(String(p.name))


func _save_presets() -> void:
	var path := "user://photo_presets.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_presets_cache))
	file.close()


func _on_preset_save() -> void:
	if _preset_name == null:
		return
	var name := _preset_name.text.strip_edges()
	if name.is_empty():
		if _status:
			_status.text = "Preset name required"
		return
	var preset := _collect_preset_state()
	preset["name"] = name
	var replaced := false
	for i in range(_presets_cache.size()):
		var p: Dictionary = _presets_cache[i]
		if p is Dictionary and p.get("name", "") == name:
			_presets_cache[i] = preset
			replaced = true
			break
	if not replaced:
		_presets_cache.append(preset)
	_save_presets()
	_load_presets()
	if _status:
		_status.text = "Saved preset: %s" % name


func _on_preset_load() -> void:
	if _presets_options == null:
		return
	var idx := _presets_options.selected
	if idx < 0 or idx >= _presets_cache.size():
		return
	var preset: Dictionary = _presets_cache[idx]
	if preset is Dictionary:
		_apply_preset_state(preset)
		if _status:
			_status.text = "Loaded preset: %s" % String(preset.get("name", ""))


func _on_preset_delete() -> void:
	if _presets_options == null:
		return
	var idx := _presets_options.selected
	if idx < 0 or idx >= _presets_cache.size():
		return
	_presets_cache.remove_at(idx)
	_save_presets()
	_load_presets()
	if _status:
		_status.text = "Preset deleted"


func _collect_preset_state() -> Dictionary:
	return {
		"fov": _camera.fov if _camera else 60.0,
		"iso": _iso_slider.value if _iso_slider else 200.0,
		"aperture": _aperture_slider.value if _aperture_slider else 4.0,
		"shutter": _shutter_slider.value if _shutter_slider else 0.008,
		"exposure": _exposure_slider.value if _exposure_slider else 0.0,
		"env_preset": _env_options.get_item_text(_env_options.selected) if _env_options else "",
		"sun_angle": _sun_angle_slider.value if _sun_angle_slider else -35.0,
		"ambient": _ambient_slider.value if _ambient_slider else 1.0,
		"temp": _temp_slider.value if _temp_slider else 0.0,
		"tint": _tint_slider.value if _tint_slider else 0.0,
		"saturation": _saturation_slider.value if _saturation_slider else 1.0,
		"contrast": _contrast_slider.value if _contrast_slider else 1.0,
		"vignette": _vignette_slider.value if _vignette_slider else 0.0,
		"grain": _grain_slider.value if _grain_slider else 0.0,
		"bloom": _bloom_slider.value if _bloom_slider else 0.0,
		"guides": _guides_check.button_pressed if _guides_check else true,
		"golden": _golden_check.button_pressed if _golden_check else false,
		"diagonal": _diagonal_check.button_pressed if _diagonal_check else false,
		"diagonal_alt": _diagonal_alt_check.button_pressed if _diagonal_alt_check else false,
		"spiral": _spiral_check.button_pressed if _spiral_check else false,
		"opacity": _guides_opacity_slider.value if _guides_opacity_slider else 0.5,
		"key_enabled": _key_enabled.button_pressed if _key_enabled else true,
		"key_color": _key_color.color if _key_color else Color.WHITE,
		"key_intensity": _key_intensity.value if _key_intensity else 3.5,
		"fill_enabled": _fill_enabled.button_pressed if _fill_enabled else true,
		"fill_color": _fill_color.color if _fill_color else Color(0.9, 0.95, 1.0),
		"fill_intensity": _fill_intensity.value if _fill_intensity else 1.5,
		"rim_enabled": _rim_enabled.button_pressed if _rim_enabled else true,
		"rim_color": _rim_color.color if _rim_color else Color(1, 0.9, 0.85),
		"rim_intensity": _rim_intensity.value if _rim_intensity else 2.0,
		"top_enabled": _top_enabled.button_pressed if _top_enabled else true,
		"top_color": _top_color.color if _top_color else Color.WHITE,
		"top_intensity": _top_intensity.value if _top_intensity else 1.0,
		"bounce_enabled": _bounce_enabled.button_pressed if _bounce_enabled else true,
		"bounce_color": _bounce_color.color if _bounce_color else Color(1, 0.95, 0.85),
		"bounce_intensity": _bounce_intensity.value if _bounce_intensity else 0.8,
	}


func _apply_preset_state(preset: Dictionary) -> void:
	if _camera:
		_camera.fov = float(preset.get("fov", _camera.fov))
	if _fov_slider:
		_fov_slider.value = _camera.fov
	if _iso_slider:
		_iso_slider.value = float(preset.get("iso", _iso_slider.value))
	if _aperture_slider:
		_aperture_slider.value = float(preset.get("aperture", _aperture_slider.value))
	if _shutter_slider:
		_shutter_slider.value = float(preset.get("shutter", _shutter_slider.value))
	if _exposure_slider:
		_exposure_slider.value = float(preset.get("exposure", _exposure_slider.value))
	if _env_options:
		var name := String(preset.get("env_preset", ""))
		for i in range(_env_options.item_count):
			if _env_options.get_item_text(i) == name:
				_env_options.select(i)
				_on_environment_selected(i)
				break
	if _sun_angle_slider:
		_sun_angle_slider.value = float(preset.get("sun_angle", _sun_angle_slider.value))
	if _ambient_slider:
		_ambient_slider.value = float(preset.get("ambient", _ambient_slider.value))
	if _temp_slider:
		_temp_slider.value = float(preset.get("temp", _temp_slider.value))
	if _tint_slider:
		_tint_slider.value = float(preset.get("tint", _tint_slider.value))
	if _saturation_slider:
		_saturation_slider.value = float(preset.get("saturation", _saturation_slider.value))
	if _contrast_slider:
		_contrast_slider.value = float(preset.get("contrast", _contrast_slider.value))
	if _vignette_slider:
		_vignette_slider.value = float(preset.get("vignette", _vignette_slider.value))
	if _grain_slider:
		_grain_slider.value = float(preset.get("grain", _grain_slider.value))
	if _bloom_slider:
		_bloom_slider.value = float(preset.get("bloom", _bloom_slider.value))
	if _guides_check:
		_guides_check.button_pressed = bool(preset.get("guides", true))
	if _golden_check:
		_golden_check.button_pressed = bool(preset.get("golden", false))
	if _diagonal_check:
		_diagonal_check.button_pressed = bool(preset.get("diagonal", false))
	if _diagonal_alt_check:
		_diagonal_alt_check.button_pressed = bool(preset.get("diagonal_alt", false))
	if _spiral_check:
		_spiral_check.button_pressed = bool(preset.get("spiral", false))
	if _guides_opacity_slider:
		_guides_opacity_slider.value = float(preset.get("opacity", _guides_opacity_slider.value))
	if _key_enabled:
		_key_enabled.button_pressed = bool(preset.get("key_enabled", true))
	if _key_color:
		_key_color.color = preset.get("key_color", _key_color.color)
	if _key_intensity:
		_key_intensity.value = float(preset.get("key_intensity", _key_intensity.value))
	if _fill_enabled:
		_fill_enabled.button_pressed = bool(preset.get("fill_enabled", true))
	if _fill_color:
		_fill_color.color = preset.get("fill_color", _fill_color.color)
	if _fill_intensity:
		_fill_intensity.value = float(preset.get("fill_intensity", _fill_intensity.value))
	if _rim_enabled:
		_rim_enabled.button_pressed = bool(preset.get("rim_enabled", true))
	if _rim_color:
		_rim_color.color = preset.get("rim_color", _rim_color.color)
	if _rim_intensity:
		_rim_intensity.value = float(preset.get("rim_intensity", _rim_intensity.value))
	if _top_enabled:
		_top_enabled.button_pressed = bool(preset.get("top_enabled", true))
	if _top_color:
		_top_color.color = preset.get("top_color", _top_color.color)
	if _top_intensity:
		_top_intensity.value = float(preset.get("top_intensity", _top_intensity.value))
	if _bounce_enabled:
		_bounce_enabled.button_pressed = bool(preset.get("bounce_enabled", true))
	if _bounce_color:
		_bounce_color.color = preset.get("bounce_color", _bounce_color.color)
	if _bounce_intensity:
		_bounce_intensity.value = float(preset.get("bounce_intensity", _bounce_intensity.value))


func _get_selected_aspect_ratio(base_size: Vector2) -> float:
	if _aspect_options:
		if _aspect_options.get_item_count() == 0 or _aspect_options.selected < 0:
			return base_size.x / maxf(base_size.y, 1.0)
		var meta: Variant = _aspect_options.get_item_metadata(_aspect_options.selected)
		if meta is Dictionary:
			var ratio := float((meta as Dictionary).get("ratio", 0.0))
			if ratio > 0.01:
				return ratio
	return base_size.x / maxf(base_size.y, 1.0)


func _calculate_crop_rect(base_size: Vector2) -> Rect2:
	if base_size.x <= 1.0 or base_size.y <= 1.0:
		return Rect2(Vector2.ZERO, base_size)
	var target_ratio := _get_selected_aspect_ratio(base_size)
	var base_ratio := base_size.x / base_size.y
	if absf(target_ratio - base_ratio) < 0.001:
		return Rect2(Vector2.ZERO, base_size)
	if target_ratio > base_ratio:
		var height := base_size.x / target_ratio
		var y := (base_size.y - height) * 0.5
		return Rect2(Vector2(0.0, y), Vector2(base_size.x, height))
	else:
		var width := base_size.y * target_ratio
		var x := (base_size.x - width) * 0.5
		return Rect2(Vector2(x, 0.0), Vector2(width, base_size.y))


func _get_capture_size() -> Vector2i:
	var base_size := get_viewport().get_visible_rect().size
	var crop_rect := _calculate_crop_rect(base_size)
	var ratio := crop_rect.size.x / maxf(crop_rect.size.y, 1.0)
	var multiplier := 1.0
	var mp := 0.0
	if _res_options:
		var meta: Variant = _res_options.get_item_metadata(_res_options.selected)
		if meta is Dictionary:
			var mode := String((meta as Dictionary).get("mode", ""))
			if mode == "megapixels":
				mp = float((meta as Dictionary).get("value", 0.0))
			elif mode == "multiplier":
				multiplier = float((meta as Dictionary).get("value", 1.0))
	if mp > 0.0:
		var total_pixels := mp * 1000000.0
		var width := sqrt(total_pixels * ratio)
		var height := width / maxf(ratio, 0.0001)
		return Vector2i(maxi(1, int(round(width))), maxi(1, int(round(height))))
	return Vector2i(
		maxi(1, int(round(crop_rect.size.x * multiplier))),
		maxi(1, int(round(crop_rect.size.y * multiplier)))
	)


func _update_viewfinder() -> void:
	if _viewfinder == null:
		return
	var base_size := get_viewport().get_visible_rect().size
	var crop_rect := _calculate_crop_rect(base_size)
	if _viewfinder.has_method("set_crop_rect"):
		_viewfinder.call("set_crop_rect", crop_rect)


func _set_viewfinder_visible(visible: bool) -> void:
	if _viewfinder == null:
		return
	if _viewfinder.has_method("set_enabled"):
		_viewfinder.call("set_enabled", visible)
	else:
		_viewfinder.visible = visible


func _on_capture_path_browse() -> void:
	if _capture_path_dialog == null:
		return
	var start := ""
	if _capture_path_edit:
		start = _capture_path_edit.text.strip_edges()
	if start.is_empty():
		start = PHOTO_CAPTURE_DIR
	if start.begins_with("user://") or start.begins_with("res://"):
		_capture_path_dialog.current_dir = ProjectSettings.globalize_path(start)
	else:
		_capture_path_dialog.current_dir = start
	_capture_path_dialog.popup_centered_ratio(0.7)


func _on_capture_path_dir_selected(dir: String) -> void:
	if _capture_path_edit:
		_capture_path_edit.text = dir


func _add_capture_thumbnail(capture: Dictionary) -> void:
	if capture == null or _contact_strip == null:
		return
	# Create thumbnail button
	var thumb_btn := Button.new()
	thumb_btn.name = "Thumb_%d" % _contact_strip.get_child_count()
	var tex: Texture = capture.get("thumb", null) as Texture
	if tex != null and tex is Texture:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.rect_min_size = Vector2(160, 88)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb_btn.add_child(tr)
	else:
		thumb_btn.text = "Img"
	# store metadata
	thumb_btn.set_meta("capture", capture)
	thumb_btn.pressed.connect(func():
		_open_capture_preview(capture)
	)
	_contact_strip.add_child(thumb_btn)


func _open_capture_preview(capture: Dictionary) -> void:
	if capture == null or _capture_preview_panel == null:
		return
	var img_node := _capture_preview_panel.get_node_or_null("PreviewImage") as TextureRect
	if img_node and capture.has("thumb") and capture.thumb != null:
		img_node.texture = capture.thumb
	_capture_preview_panel.popup_centered_ratio(0.8)
	# add restore-camera button if not present
	if _capture_preview_panel.get_node_or_null("RestoreBtn") == null:
		var btn := Button.new()
		btn.name = "RestoreBtn"
		btn.text = "Restore Camera"
		btn.rect_min_size = Vector2(140, 32)
		btn.pressed.connect(func():
			if capture.has("camera") and _camera:
				_camera.global_position = capture.camera.position
				_camera.rotation_degrees = capture.camera.rotation
				_yaw = _camera.rotation_degrees.y
				_pitch = _camera.rotation_degrees.x
				_capture_preview_panel.hide()
		)
		_capture_preview_panel.add_child(btn)


func _on_capture_pressed() -> void:
	var size := _get_capture_size()
	await _capture_image(size)


func _on_capture_layers_pressed() -> void:
	var size := _get_capture_size()
	await _capture_layers_exr(size)


func _on_back_pressed() -> void:
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("toggle_menu"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		dbg.call_deferred("toggle_menu")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _capture_png(size: Vector2i) -> void:
	if _status:
		_status.text = "Capturing…"

	var sub := SubViewport.new()
	sub.size = size
	sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	sub.world_3d = get_viewport().world_3d
	sub.disable_3d = false
	add_child(sub)

	var cap_cam := Camera3D.new()
	cap_cam.transform = _camera.global_transform
	cap_cam.fov = _camera.fov
	cap_cam.projection = _camera.projection
	cap_cam.near = _camera.near
	cap_cam.far = _camera.far
	cap_cam.attributes = _camera.attributes
	cap_cam.current = true
	sub.add_child(cap_cam)

	await get_tree().process_frame
	await get_tree().process_frame

	var img := sub.get_texture().get_image()
	_save_image(img)
	sub.queue_free()

	if _status:
		_status.text = "Saved capture"


func _save_image(image: Image) -> void:
	if image == null:
		return
	var dir_path := _get_capture_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var ts := Time.get_datetime_string_from_system().replace(":", "-")
	var format := _get_capture_format()
	var ext := "png"
	if format == "JPG":
		ext = "jpg"
	elif format == "EXR":
		ext = "exr"
	var filename := "photo_%s.%s" % [ts, ext]
	var full_path := dir_path.path_join(filename)
	match format:
		"JPG":
			image.save_jpg(full_path)
		"EXR":
			image.save_exr(full_path)
		_:
			image.save_png(full_path)
	if _status:
		_status.text = "Saved: %s" % full_path

	# Add to session captures and contact strip
	var cam_state := {
		"position": _camera.global_position if _camera else Vector3.ZERO,
		"rotation": _camera.rotation_degrees if _camera else Vector3.ZERO,
		"fov": _camera.fov if _camera else 60.0
	}
	var capture: Dictionary = {"path": full_path, "thumb": null, "camera": cam_state}
	# create thumbnail
	var thumb := image.duplicate()
	var tw := 160
	var th := int(round(tw * (float(image.get_height()) / maxf(image.get_width(), 1))))
	if th <= 0:
		th = 90
	thumb.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	# store thumbnail as ImageTexture
	# Create an ImageTexture from the thumb image (use static constructor)
	var tex := ImageTexture.create_from_image(thumb)
	capture.thumb = tex
	_session_captures.append(capture)
	_add_capture_thumbnail(capture)


func _capture_layers_exr(size: Vector2i) -> void:
	var passes := _selected_passes()
	if passes.is_empty():
		if _status:
			_status.text = "No passes selected"
		return

	var dir_path := _make_capture_folder()
	for pass_name in passes:
		if _status:
			_status.text = "Capturing %s…" % pass_name
		_apply_pass(pass_name)
		var img := await _render_to_image(size)
		if img:
			_save_exr(img, dir_path, pass_name)
	_restore_pass_state()
	_apply_pass_preview()
	_write_photoshop_script(dir_path, passes)
	if _status:
		_status.text = "Saved layers to %s" % dir_path


func _selected_passes() -> Array[String]:
	var passes: Array[String] = []
	if _pass_beauty and _pass_beauty.button_pressed:
		passes.append(PASS_BEAUTY)
	if _pass_albedo and _pass_albedo.button_pressed:
		passes.append(PASS_ALBEDO)
	if _pass_normals and _pass_normals.button_pressed:
		passes.append(PASS_NORMALS)
	if _pass_depth and _pass_depth.button_pressed:
		passes.append(PASS_DEPTH)
	if _pass_lighting and _pass_lighting.button_pressed:
		passes.append(PASS_LIGHTING)
	return passes


func _make_capture_folder() -> String:
	var dir_path := _get_capture_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var ts := Time.get_datetime_string_from_system().replace(":", "-")
	var folder := dir_path.path_join("photo_" + ts)
	DirAccess.make_dir_recursive_absolute(folder)
	return folder


func _capture_image(size: Vector2i) -> void:
	if _status:
		_status.text = "Capturing…"
	var img := await _render_to_image(size)
	if img:
		_save_image(img)
	if _status:
		_status.text = "Saved capture"


func _get_capture_format() -> String:
	if _capture_format_options == null:
		return "PNG"
	return _capture_format_options.get_item_text(_capture_format_options.selected)


func _get_capture_dir() -> String:
	var path := ""
	if _capture_path_edit:
		path = _capture_path_edit.text.strip_edges()
	if path.is_empty():
		path = PHOTO_CAPTURE_DIR
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path


func _populate_capture_formats() -> void:
	if _capture_format_options == null:
		return
	_capture_format_options.clear()
	var formats := ["PNG", "JPG", "EXR"]
	for f in formats:
		_capture_format_options.add_item(f)
	_capture_format_options.select(0)


func _render_to_image(size: Vector2i) -> Image:
	var sub := SubViewport.new()
	sub.size = size
	sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	sub.world_3d = get_viewport().world_3d
	sub.disable_3d = false
	add_child(sub)

	var cap_cam := Camera3D.new()
	cap_cam.transform = _camera.global_transform
	cap_cam.fov = _camera.fov
	cap_cam.projection = _camera.projection
	cap_cam.near = _camera.near
	cap_cam.far = _camera.far
	cap_cam.attributes = _camera.attributes
	cap_cam.current = true
	sub.add_child(cap_cam)

	await get_tree().process_frame
	await get_tree().process_frame
	var img := sub.get_texture().get_image()
	sub.queue_free()
	return img


func _save_exr(image: Image, folder: String, pass_name: String) -> void:
	if image == null:
		return
	var filename := "%s.exr" % pass_name
	var full_path := folder.path_join(filename)
	image.save_exr(full_path)


func _write_photoshop_script(folder: String, passes: Array[String]) -> void:
	var jsx := """
// Auto-generated by Sacred Fruit Photo Mode
var files = [
%s
];
var doc = app.documents.add();
for (var i = 0; i < files.length; i++) {
  var f = new File(files[i]);
  if (!f.exists) continue;
  var tmp = app.open(f);
  tmp.activeLayer.duplicate(doc, ElementPlacement.PLACEATBEGINNING);
  tmp.close(SaveOptions.DONOTSAVECHANGES);
}
doc.activeLayer = doc.layers[0];
""";
	var lines: Array[String] = []
	for pass_name in passes:
		lines.append("  \"" + folder.path_join(pass_name + ".exr").replace("\\", "/") + "\"")
	var content := jsx % ["\n".join(lines)]
	var script_path := folder.path_join("import_layers.jsx")
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()


func _apply_pass(pass_name: String) -> void:
	_restore_pass_state()
	if pass_name == PASS_BEAUTY:
		return
	var meshes := _collect_meshes()
	if pass_name == PASS_ALBEDO:
		_apply_albedo_pass(meshes)
	elif pass_name == PASS_NORMALS:
		_apply_material_override(meshes, _normal_pass_material)
	elif pass_name == PASS_DEPTH:
		_update_depth_far()
		_apply_material_override(meshes, _depth_pass_material)
	elif pass_name == PASS_LIGHTING:
		_apply_lighting_pass(meshes)


func _restore_pass_state() -> void:
	if _material_state.is_empty():
		return
	for mesh in _material_state.keys():
		if mesh and is_instance_valid(mesh):
			var state: Dictionary = _material_state[mesh] as Dictionary
			(mesh as MeshInstance3D).material_override = state["override"]
			var surface_overrides: Array = state["surface"]
			for i in range(surface_overrides.size()):
				(mesh as MeshInstance3D).set_surface_override_material(i, surface_overrides[i])
	_material_state.clear()


func _collect_meshes() -> Array:
	if _map == null:
		return []
	return _map.find_children("*", "MeshInstance3D", true, false)


func _cache_material_state(mesh: MeshInstance3D) -> void:
	if mesh in _material_state:
		return
	var surfaces: Array = []
	var count := mesh.get_surface_override_material_count()
	for i in range(count):
		surfaces.append(mesh.get_surface_override_material(i))
	_material_state[mesh] = {
		"override": mesh.material_override,
		"surface": surfaces
	}


func _apply_material_override(meshes: Array, material: Material) -> void:
	if material == null:
		return
	for m in meshes:
		if m is MeshInstance3D:
			_cache_material_state(m)
			(m as MeshInstance3D).material_override = material


func _apply_albedo_pass(meshes: Array) -> void:
	for m in meshes:
		if m is MeshInstance3D:
			_cache_material_state(m)
			var mi := m as MeshInstance3D
			var base := mi.get_active_material(0)
			if base is StandardMaterial3D:
				var mat := (base as StandardMaterial3D).duplicate()
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mat.disable_ambient_light = true
				mat.emission_enabled = false
				mi.material_override = mat
			else:
				var mat2 := StandardMaterial3D.new()
				mat2.albedo_color = Color(0.8, 0.8, 0.8)
				mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mi.material_override = mat2


func _apply_lighting_pass(meshes: Array) -> void:
	for m in meshes:
		if m is MeshInstance3D:
			_cache_material_state(m)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1, 1, 1)
			mat.roughness = 0.6
			mat.metallic = 0.0
			(mat as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			(m as MeshInstance3D).material_override = mat


func _update_depth_far() -> void:
	if _depth_pass_material == null or _camera == null:
		return
	_depth_pass_material.set_shader_parameter("u_far", _camera.far)


func _set_attr_if_exists(obj: Object, prop_name: String, value: Variant) -> void:
	if obj == null:
		return
	for prop in obj.get_property_list():
		if prop.name == prop_name:
			obj.set(prop_name, value)
			return

	# Fallback: attempt to set the property directly (some resources expose properties differently)
	# This may print an engine warning if the property doesn't exist, but it's harmless.
	obj.set(prop_name, value)
