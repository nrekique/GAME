extends Node3D
const Util := preload("res://scripts/util.gd")

# Export/import photo mode state (scene, camera, settings)
const PHOTO_CAPTURE_DIR := "user://photos"
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const HOME_SETUP_SCRIPT := preload("res://scripts/home_setup.gd")
const POSTFX_SHADER_PATH := "res://shaders/photo_mode_postfx.gdshader"




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
@export var enable_layout_debug_print: bool = false

var _map: FuncGodotMap
var _yaw: float = 0.0
var _pitch: float = 0.0
var _bookmarks: Dictionary = {} as Dictionary
var _ui_visible: bool = true
var _material_state: Dictionary = {}
var _env_presets: Dictionary = {}
var _layout_retry_frames: int = 0
var _debug_accum: float = 0.0
const DEBUG_PRINT_INTERVAL: float = 2.0

const PASS_BEAUTY := "beauty"
const PASS_ALBEDO := "albedo"
const PASS_NORMALS := "normals"
const PASS_DEPTH := "depth"
const PASS_LIGHTING := "lighting"
const THUMB_MENU_PREVIEW := 0
const THUMB_MENU_SHOW_IN_FINDER := 1
const THUMB_MENU_EXPORT := 2
const THUMB_MENU_REAPPLY := 3
const THUMB_MENU_DELETE := 4

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
var _tab_contents: Dictionary = {} as Dictionary
var _active_tab: String = ""
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
var _ps1_shader_toggle: CheckBox
var _postfx_toggle: CheckBox
var _postfx_fog_toggle: CheckBox
var _postfx_fog_distance_slider: HSlider
var _postfx_fog_distance_value: Label
var _postfx_fog_fade_slider: HSlider
var _postfx_fog_fade_value: Label
var _postfx_noise_toggle: CheckBox
var _postfx_noise_time_slider: HSlider
var _postfx_noise_time_value: Label
var _postfx_color_limit_toggle: CheckBox
var _postfx_color_levels_slider: HSlider
var _postfx_color_levels_value: Label
var _postfx_dither_toggle: CheckBox
var _postfx_dither_strength_slider: HSlider
var _postfx_dither_strength_value: Label
var _postfx_opacity_slider: HSlider
var _postfx_opacity_value: Label
var _postfx_overlay: MeshInstance3D
var _postfx_material: ShaderMaterial
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
var _filmstrip_hbox: HBoxContainer
var _viewfinder_toggle: Button
var _guides_toggle: Button
var _toolbar_capture: Button
var _toolbar_layers: Button
var _toolbar_back: Button
var _session_captures: Array = []
var _capture_preview_panel: Window
var _always_show_viewport_enabled: bool = false
var _thumb_menu: PopupMenu
var _thumb_export_dialog: FileDialog
var _selected_capture_idx: int = -1
var _menu_target_capture_index: int = -1
var _thumb_export_target_index: int = -1
var _preview_capture: Dictionary = {}
var _preview_capture_index: int = -1
var _preview_zoom: float = 1.0
var _preview_show_compare: bool = false
var _preview_compare_capture: Dictionary = {}
var _preview_primary_texture: Texture2D
var _preview_compare_texture: Texture2D
var _preview_image_size: Vector2 = Vector2.ZERO
var _preview_scroll: ScrollContainer
var _preview_image_node: TextureRect
var _capture_sequence_counter: int = 0

var _capture_timer_slider: HSlider
var _capture_timer_value: Label
var _capture_burst_options: OptionButton
var _capture_bracket_options: OptionButton
var _capture_bracket_step_slider: HSlider
var _capture_bracket_step_value: Label
var _capture_watermark_toggle: CheckBox
var _capture_watermark_text: LineEdit

var _fog_toggle: CheckBox
var _fog_density_slider: HSlider
var _fog_density_value: Label
var _fog_begin_slider: HSlider
var _fog_begin_value: Label
var _fog_end_slider: HSlider
var _fog_end_value: Label
var _sun_shadow_toggle: CheckBox
var _sun_shadow_opacity_slider: HSlider
var _sun_shadow_opacity_value: Label
var _sun_softness_slider: HSlider
var _sun_softness_value: Label
var _sun_color_picker: ColorPickerButton
var _ambient_color_picker: ColorPickerButton
var _fog_color_picker: ColorPickerButton
var _fog_height_toggle: CheckBox
var _fog_height_density_slider: HSlider
var _fog_height_density_value: Label
var _fog_height_falloff_slider: HSlider
var _fog_height_falloff_value: Label
var _volumetric_fog_toggle: CheckBox
var _volumetric_fog_density_slider: HSlider
var _volumetric_fog_density_value: Label
var _volumetric_fog_aniso_slider: HSlider
var _volumetric_fog_aniso_value: Label

var _composition_crop_options: OptionButton
var _composition_offset_x_slider: HSlider
var _composition_offset_x_value: Label
var _composition_offset_y_slider: HSlider
var _composition_offset_y_value: Label
var _composition_roll_slider: HSlider
var _composition_roll_value: Label
var _composition_snap_toggle: CheckBox

var _composition_crop_ratio: float = 0.0
var _composition_crop_offset: Vector2 = Vector2.ZERO
var _composition_horizon_roll: float = 0.0
var _composition_thirds_snap_enabled: bool = false
var _postfx_enabled: bool = false


# --- Export / Import helpers (moved below variable declarations) ---
func export_photo_mode_state(path: String) -> void:
	var state: Dictionary = {}
	state["map_file"] = _map.local_map_file if _map and "local_map_file" in _map else ""
	state["camera"] = {
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
	}
	state["exposure"] = { "base": _base_exposure, "auto": _auto_exposure_enabled }
	state["environment"] = {
		"preset": _env_options.get_item_text(_env_options.selected) if _env_options else "",
		"sun_angle": _sun_angle_slider.value if _sun_angle_slider else -35.0,
		"ambient_energy": _ambient_slider.value if _ambient_slider else 1.0,
		"sun_shadows": _sun_shadow_toggle.button_pressed if _sun_shadow_toggle else true,
		"sun_shadow_opacity": _sun_shadow_opacity_slider.value if _sun_shadow_opacity_slider else 1.0,
		"sun_softness": _sun_softness_slider.value if _sun_softness_slider else 0.0,
		"sun_color": _sun_color_picker.color if _sun_color_picker else (_key_light.light_color if _key_light else Color(1.0, 0.98, 0.92)),
		"ambient_color": _ambient_color_picker.color if _ambient_color_picker else (_world_env.environment.ambient_light_color if _world_env and _world_env.environment else Color(0.6, 0.65, 0.7))
	}
	state["resolution"] = { "preset": _res_options.get_item_text(_res_options.selected) if _res_options else "" }
	state["aspect"] = { "preset": _aspect_options.get_item_text(_aspect_options.selected) if _aspect_options else "" }
	state["guides"] = { "enabled": _guides.visible if _guides else false, "type": _guide_type_options.get_item_text(_guide_type_options.selected) if _guide_type_options else "" }
	state["lights"] = {
		"key": _serialize_light(_key_light, _key_enabled, _key_color, _key_intensity),
		"fill": _serialize_light(_fill_light, _fill_enabled, _fill_color, _fill_intensity),
		"rim": _serialize_light(_rim_light, _rim_enabled, _rim_color, _rim_intensity),
		"top": _serialize_light(_top_light, _top_enabled, _top_color, _top_intensity),
		"bounce": _serialize_light(_bounce_light, _bounce_enabled, _bounce_color, _bounce_intensity)
	}
	# Color/effects
	state["color"] = {
		"temp": _temp_slider.value if _temp_slider else 0.0,
		"tint": _tint_slider.value if _tint_slider else 0.0,
		"saturation": _saturation_slider.value if _saturation_slider else 1.0,
		"contrast": _contrast_slider.value if _contrast_slider else 1.0
	}
	state["effects"] = {
		"vignette": _vignette_slider.value if _vignette_slider else 0.0,
		"grain": _grain_slider.value if _grain_slider else 0.0,
		"bloom": _bloom_slider.value if _bloom_slider else 0.0,
		"ps1_enabled": _ps1_shader_toggle.button_pressed if _ps1_shader_toggle else _is_ps1_shader_enabled(),
		"postfx_enabled": _postfx_toggle.button_pressed if _postfx_toggle else _postfx_enabled,
		"postfx_fog": _postfx_fog_toggle.button_pressed if _postfx_fog_toggle else false,
		"postfx_fog_distance": _postfx_fog_distance_slider.value if _postfx_fog_distance_slider else 120.0,
		"postfx_fog_fade": _postfx_fog_fade_slider.value if _postfx_fog_fade_slider else 60.0,
		"postfx_noise": _postfx_noise_toggle.button_pressed if _postfx_noise_toggle else false,
		"postfx_noise_time": _postfx_noise_time_slider.value if _postfx_noise_time_slider else 4.0,
		"postfx_color_limit": _postfx_color_limit_toggle.button_pressed if _postfx_color_limit_toggle else true,
		"postfx_color_levels": _postfx_color_levels_slider.value if _postfx_color_levels_slider else 32.0,
		"postfx_dither": _postfx_dither_toggle.button_pressed if _postfx_dither_toggle else true,
		"postfx_dither_strength": _postfx_dither_strength_slider.value if _postfx_dither_strength_slider else 0.35,
		"postfx_opacity": _postfx_opacity_slider.value if _postfx_opacity_slider else 1.0
	}
	# Capture
	state["capture"] = {
		"format": _capture_format_options.get_item_text(_capture_format_options.selected) if _capture_format_options else "PNG",
		"path": _capture_path_edit.text if _capture_path_edit else "",
		"timer_seconds": _capture_timer_slider.value if _capture_timer_slider else 0.0,
		"burst_count": _get_capture_burst_count(),
		"bracket_count": _get_capture_bracket_count(),
		"bracket_step_ev": _capture_bracket_step_slider.value if _capture_bracket_step_slider else 1.0,
		"watermark_enabled": _capture_watermark_toggle.button_pressed if _capture_watermark_toggle else false,
		"watermark_text": _capture_watermark_text.text if _capture_watermark_text else ""
	}
	state["fog"] = {
		"enabled": _fog_toggle.button_pressed if _fog_toggle else false,
		"color": _fog_color_picker.color if _fog_color_picker else Color(0.72, 0.77, 0.83),
		"density": _fog_density_slider.value if _fog_density_slider else 0.0,
		"begin": _fog_begin_slider.value if _fog_begin_slider else 5.0,
		"end": _fog_end_slider.value if _fog_end_slider else 200.0,
		"height_enabled": _fog_height_toggle.button_pressed if _fog_height_toggle else false,
		"height_density": _fog_height_density_slider.value if _fog_height_density_slider else 0.05,
		"height_falloff": _fog_height_falloff_slider.value if _fog_height_falloff_slider else 0.5,
		"volumetric_enabled": _volumetric_fog_toggle.button_pressed if _volumetric_fog_toggle else false,
		"volumetric_density": _volumetric_fog_density_slider.value if _volumetric_fog_density_slider else 0.03,
		"volumetric_aniso": _volumetric_fog_aniso_slider.value if _volumetric_fog_aniso_slider else 0.0
	}
	state["composition"] = {
		"crop_ratio": _composition_crop_ratio,
		"offset_x": _composition_offset_x_slider.value if _composition_offset_x_slider else 0.0,
		"offset_y": _composition_offset_y_slider.value if _composition_offset_y_slider else 0.0,
		"roll": _composition_roll_slider.value if _composition_roll_slider else _composition_horizon_roll,
		"thirds_snap": _composition_snap_toggle.button_pressed if _composition_snap_toggle else false
	}
	# Passes
	state["passes"] = {
		"beauty": _pass_beauty.button_pressed if _pass_beauty else false,
		"albedo": _pass_albedo.button_pressed if _pass_albedo else false,
		"normals": _pass_normals.button_pressed if _pass_normals else false,
		"depth": _pass_depth.button_pressed if _pass_depth else false,
		"lighting": _pass_lighting.button_pressed if _pass_lighting else false
	}

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state))
		file.close()

func _serialize_light(light, enabled, color, intensity) -> Dictionary:
	var out: Dictionary = {}
	out["enabled"] = enabled.button_pressed if enabled else false
	out["color"] = color.color if color else Color(1,1,1)
	out["intensity"] = intensity.value if intensity else 1.0
	out["rotation"] = light.rotation_degrees if light else Vector3.ZERO
	return out


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


func _to_color(value, fallback: Color) -> Color:
	# Normalize various color representations into a Color instance.
	if value == null:
		return fallback
	if value is Color:
		return value
	if value is Dictionary or value is Array:
		return _parse_color(value)
	# Fallback: attempt to parse or return fallback
	return fallback

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
	if state.has("environment") and state["environment"] is Dictionary:
		var env_state: Dictionary = state["environment"] as Dictionary
		if _env_options and env_state.has("preset"):
			var env_name := String(env_state.get("preset", ""))
			for i in range(_env_options.get_item_count()):
				if _env_options.get_item_text(i) == env_name:
					_env_options.selected = i
					_on_environment_selected(i)
					break
		if env_state.has("sun_angle") and _sun_angle_slider:
			_sun_angle_slider.value = float(env_state["sun_angle"])
		if env_state.has("ambient_energy") and _ambient_slider:
			_ambient_slider.value = float(env_state["ambient_energy"])
		if env_state.has("sun_shadows") and _sun_shadow_toggle:
			_set_check_value(_sun_shadow_toggle, bool(env_state["sun_shadows"]))
		if env_state.has("sun_shadow_opacity") and _sun_shadow_opacity_slider:
			_sun_shadow_opacity_slider.value = float(env_state["sun_shadow_opacity"])
		if env_state.has("sun_softness") and _sun_softness_slider:
			_sun_softness_slider.value = float(env_state["sun_softness"])
		if env_state.has("sun_color") and _sun_color_picker:
			_sun_color_picker.color = _to_color(env_state["sun_color"], _sun_color_picker.color)
		if env_state.has("ambient_color") and _ambient_color_picker:
			_ambient_color_picker.color = _to_color(env_state["ambient_color"], _ambient_color_picker.color)

	# Resolution / aspect
	if state.has("resolution") and _res_options:
		var res = state["resolution"].get("preset", "")
		for i in range(_res_options.get_item_count()):
			if _res_options.get_item_text(i) == res:
				_res_options.selected = i
				break
	if state.has("aspect") and _aspect_options:
		var asp = state["aspect"].get("preset", "")
		for i in range(_aspect_options.get_item_count()):
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
			for i in range(_guide_type_options.get_item_count()):
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
		if e.has("ps1_enabled"):
			var ps1_enabled := bool(e["ps1_enabled"])
			if _ps1_shader_toggle:
				_set_check_value(_ps1_shader_toggle, ps1_enabled)
			_set_ps1_shader_enabled(ps1_enabled)
		if e.has("postfx_enabled") and _postfx_toggle:
			_set_check_value(_postfx_toggle, bool(e["postfx_enabled"]))
		if e.has("postfx_fog") and _postfx_fog_toggle:
			_set_check_value(_postfx_fog_toggle, bool(e["postfx_fog"]))
		if e.has("postfx_fog_distance") and _postfx_fog_distance_slider:
			_postfx_fog_distance_slider.value = float(e["postfx_fog_distance"])
		if e.has("postfx_fog_fade") and _postfx_fog_fade_slider:
			_postfx_fog_fade_slider.value = float(e["postfx_fog_fade"])
		if e.has("postfx_noise") and _postfx_noise_toggle:
			_set_check_value(_postfx_noise_toggle, bool(e["postfx_noise"]))
		if e.has("postfx_noise_time") and _postfx_noise_time_slider:
			_postfx_noise_time_slider.value = float(e["postfx_noise_time"])
		if e.has("postfx_color_limit") and _postfx_color_limit_toggle:
			_set_check_value(_postfx_color_limit_toggle, bool(e["postfx_color_limit"]))
		if e.has("postfx_color_levels") and _postfx_color_levels_slider:
			_postfx_color_levels_slider.value = float(e["postfx_color_levels"])
		if e.has("postfx_dither") and _postfx_dither_toggle:
			_set_check_value(_postfx_dither_toggle, bool(e["postfx_dither"]))
		if e.has("postfx_dither_strength") and _postfx_dither_strength_slider:
			_postfx_dither_strength_slider.value = float(e["postfx_dither_strength"])
		if e.has("postfx_opacity") and _postfx_opacity_slider:
			_postfx_opacity_slider.value = float(e["postfx_opacity"])
		_apply_postfx_settings()

	# Capture
	if state.has("capture"):
		var cap = state["capture"]
		if cap.has("format") and _capture_format_options:
			var fmt = cap["format"]
			for i in range(_capture_format_options.get_item_count()):
				if _capture_format_options.get_item_text(i) == fmt:
					_capture_format_options.selected = i
					break
		if cap.has("path") and _capture_path_edit:
			_capture_path_edit.text = str(cap["path"])
		if cap.has("timer_seconds") and _capture_timer_slider:
			_capture_timer_slider.value = float(cap["timer_seconds"])
		if cap.has("bracket_step_ev") and _capture_bracket_step_slider:
			_capture_bracket_step_slider.value = float(cap["bracket_step_ev"])
		if cap.has("watermark_enabled") and _capture_watermark_toggle:
			_capture_watermark_toggle.button_pressed = bool(cap["watermark_enabled"])
		if cap.has("watermark_text") and _capture_watermark_text:
			_capture_watermark_text.text = String(cap["watermark_text"])
		if cap.has("burst_count") and _capture_burst_options:
			var burst_count := int(cap["burst_count"])
			for i in range(_capture_burst_options.get_item_count()):
				var burst_meta: Variant = _capture_burst_options.get_item_metadata(i)
				if int(burst_meta) == burst_count:
					_capture_burst_options.select(i)
					break
		if cap.has("bracket_count") and _capture_bracket_options:
			var bracket_count := int(cap["bracket_count"])
			for i in range(_capture_bracket_options.get_item_count()):
				var bracket_meta: Variant = _capture_bracket_options.get_item_metadata(i)
				if int(bracket_meta) == bracket_count:
					_capture_bracket_options.select(i)
					break

	if state.has("fog") and state["fog"] is Dictionary:
		var fog: Dictionary = state["fog"] as Dictionary
		if fog.has("enabled") and _fog_toggle:
			_set_check_value(_fog_toggle, bool(fog["enabled"]))
		if fog.has("color") and _fog_color_picker:
			_fog_color_picker.color = _to_color(fog["color"], _fog_color_picker.color)
		if fog.has("density") and _fog_density_slider:
			_fog_density_slider.value = float(fog["density"])
		if fog.has("begin") and _fog_begin_slider:
			_fog_begin_slider.value = float(fog["begin"])
		if fog.has("end") and _fog_end_slider:
			_fog_end_slider.value = float(fog["end"])
		if fog.has("height_enabled") and _fog_height_toggle:
			_set_check_value(_fog_height_toggle, bool(fog["height_enabled"]))
		if fog.has("height_density") and _fog_height_density_slider:
			_fog_height_density_slider.value = float(fog["height_density"])
		if fog.has("height_falloff") and _fog_height_falloff_slider:
			_fog_height_falloff_slider.value = float(fog["height_falloff"])
		if fog.has("volumetric_enabled") and _volumetric_fog_toggle:
			_set_check_value(_volumetric_fog_toggle, bool(fog["volumetric_enabled"]))
		if fog.has("volumetric_density") and _volumetric_fog_density_slider:
			_volumetric_fog_density_slider.value = float(fog["volumetric_density"])
		if fog.has("volumetric_aniso") and _volumetric_fog_aniso_slider:
			_volumetric_fog_aniso_slider.value = float(fog["volumetric_aniso"])

	if state.has("composition") and state["composition"] is Dictionary:
		var comp: Dictionary = state["composition"] as Dictionary
		if comp.has("crop_ratio"):
			_composition_crop_ratio = float(comp["crop_ratio"])
		if comp.has("offset_x") and _composition_offset_x_slider:
			_composition_offset_x_slider.value = float(comp["offset_x"])
		if comp.has("offset_y") and _composition_offset_y_slider:
			_composition_offset_y_slider.value = float(comp["offset_y"])
		if comp.has("roll") and _composition_roll_slider:
			_composition_roll_slider.value = float(comp["roll"])
		if comp.has("thirds_snap") and _composition_snap_toggle:
			_composition_snap_toggle.button_pressed = bool(comp["thirds_snap"])
		_update_viewfinder()

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
	_apply_sun_environment_settings()
	_sync_environment_controls_from_scene()
	_apply_fog_settings()


func _ready() -> void:
	if Util.editor_hint():
		return
	add_to_group("NO_HUD")

	_resolve_nodes()
	_setup_camera_attributes()
	_setup_pass_materials()
	_setup_ui()
	_setup_postfx_overlay()
	# Ensure authored toolbar/filmstrip chrome is applied even when runtime layout repair is disabled
	_setup_ui_chrome()
	_setup_environment_presets()
	if _ui_root:
		_ui_root.visible = _ui_visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if _ui_visible else Input.MOUSE_MODE_CAPTURED)
	if _is_layout_debug_enabled():
		call_deferred("_debug_layout")
	await _build_map_from_debug()
	_setup_postfx_overlay()
	_position_camera_at_start()
	_apply_pending_debug_camera_override()
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
	if _ui_root:
		_ui_root.visible = true
	_tabs_panel = get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel") as Control
	_status = get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox/Status") as Label
	_guides = get_node_or_null("CanvasLayer/PhotoGuides") as Control
	_viewfinder = get_node_or_null("CanvasLayer/PhotoViewfinder") as Control
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

	# toolbar / filmstrip nodes
	_viewfinder_toggle = get_node_or_null("CanvasLayer/PhotoUI/Toolbar/ToolbarHBox/ViewfinderToggle") as Button
	_guides_toggle = get_node_or_null("CanvasLayer/PhotoUI/Toolbar/ToolbarHBox/GuidesToggle") as Button
	_toolbar_capture = get_node_or_null("CanvasLayer/PhotoUI/Toolbar/ToolbarHBox/ToolbarCaptureButton") as Button
	_toolbar_layers = get_node_or_null("CanvasLayer/PhotoUI/Toolbar/ToolbarHBox/ToolbarEXRLayers") as Button
	_toolbar_back = get_node_or_null("CanvasLayer/PhotoUI/Toolbar/ToolbarHBox/ToolbarBack") as Button
	_filmstrip_hbox = get_node_or_null("CanvasLayer/PhotoUI/Filmstrip/FilmstripScroll/FilmstripHBox") as HBoxContainer

	# initialize toolbar toggle states
	if _viewfinder_toggle:
		_viewfinder_toggle.button_pressed = (_viewfinder != null and _viewfinder.visible)
	if _guides_toggle:
		_guides_toggle.button_pressed = (_guides != null and _guides.visible)
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
	_postfx_toggle = _find_node("PostFXToggle", "CheckBox") as CheckBox
	_postfx_fog_toggle = _find_node("PostFXFogToggle", "CheckBox") as CheckBox
	_postfx_fog_distance_slider = _find_node("PostFXFogDistanceSlider", "HSlider") as HSlider
	_postfx_fog_distance_value = _find_node("PostFXFogDistanceValue", "Label") as Label
	_postfx_fog_fade_slider = _find_node("PostFXFogFadeSlider", "HSlider") as HSlider
	_postfx_fog_fade_value = _find_node("PostFXFogFadeValue", "Label") as Label
	_postfx_noise_toggle = _find_node("PostFXNoiseToggle", "CheckBox") as CheckBox
	_postfx_noise_time_slider = _find_node("PostFXNoiseTimeSlider", "HSlider") as HSlider
	_postfx_noise_time_value = _find_node("PostFXNoiseTimeValue", "Label") as Label
	_postfx_color_limit_toggle = _find_node("PostFXColorLimitToggle", "CheckBox") as CheckBox
	_postfx_color_levels_slider = _find_node("PostFXColorLevelsSlider", "HSlider") as HSlider
	_postfx_color_levels_value = _find_node("PostFXColorLevelsValue", "Label") as Label
	_postfx_dither_toggle = _find_node("PostFXDitherToggle", "CheckBox") as CheckBox
	_postfx_dither_strength_slider = _find_node("PostFXDitherStrengthSlider", "HSlider") as HSlider
	_postfx_dither_strength_value = _find_node("PostFXDitherStrengthValue", "Label") as Label
	_postfx_opacity_slider = _find_node("PostFXOpacitySlider", "HSlider") as HSlider
	_postfx_opacity_value = _find_node("PostFXOpacityValue", "Label") as Label
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
	var by_unique: Node = get_node_or_null("%" + name_hint)
	if by_unique != null and (type_hint.is_empty() or by_unique.is_class(type_hint)):
		return by_unique
	var candidate_paths: PackedStringArray = [
		"CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox/" + name_hint,
		"CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/" + name_hint,
		"CanvasLayer/PhotoUI/Toolbar/ToolbarHBox/" + name_hint,
		"CanvasLayer/PhotoUI/Filmstrip/FilmstripScroll/FilmstripHBox/" + name_hint,
		"CanvasLayer/PhotoUI/" + name_hint,
		"CanvasLayer/" + name_hint,
		name_hint,
	]
	for p in candidate_paths:
		var n: Node = get_node_or_null(p)
		if n != null and (type_hint.is_empty() or n.is_class(type_hint)):
			return n
	var search_roots: PackedStringArray = [
		"CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox",
		"CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox",
		"CanvasLayer/PhotoUI/Toolbar/ToolbarHBox",
		"CanvasLayer/PhotoUI/Filmstrip/FilmstripScroll/FilmstripHBox",
	]
	for root_path in search_roots:
		var root_node: Node = get_node_or_null(root_path)
		var found: Node = _find_exact_descendant(root_node, name_hint, type_hint)
		if found != null:
			return found
	return null


func _get_settings_vbox() -> VBoxContainer:
	return get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox") as VBoxContainer


func _ensure_row_at(vbox: VBoxContainer, row_name: String, before_name: String = "") -> HBoxContainer:
	if vbox == null:
		return null
	var row := vbox.get_node_or_null(row_name) as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = row_name
		row.custom_minimum_size = Vector2(0.0, 44.0)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.add_child(row)
		if before_name != "" and vbox.has_node(before_name):
			var before_node := vbox.get_node(before_name)
			vbox.move_child(row, before_node.get_index())
	return row


func _ensure_label(row: HBoxContainer, label_name: String, text: String) -> Label:
	if row == null:
		return null
	var label := row.get_node_or_null(label_name) as Label
	if label == null:
		label = Label.new()
		label.name = label_name
		row.add_child(label)
		row.move_child(label, 0)
	label.text = text
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.custom_minimum_size = Vector2(112.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _ensure_value_label(row: HBoxContainer, label_name: String, text: String) -> Label:
	if row == null:
		return null
	var label := row.get_node_or_null(label_name) as Label
	if label == null:
		label = Label.new()
		label.name = label_name
		row.add_child(label)
	label.text = text
	label.size_flags_horizontal = Control.SIZE_SHRINK_END
	label.custom_minimum_size = Vector2(92.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _ensure_slider(row: HBoxContainer, slider_name: String, min_v: float, max_v: float, step_v: float, value: float) -> HSlider:
	if row == null:
		return null
	var slider := row.get_node_or_null(slider_name) as HSlider
	if slider == null:
		slider = HSlider.new()
		slider.name = slider_name
		row.add_child(slider)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = clampf(value, min_v, max_v)
	return slider


func _ensure_option(row: HBoxContainer, option_name: String) -> OptionButton:
	if row == null:
		return null
	var option := row.get_node_or_null(option_name) as OptionButton
	if option == null:
		option = OptionButton.new()
		option.name = option_name
		row.add_child(option)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.fit_to_longest_item = true
	return option


func _ensure_checkbox(row: HBoxContainer, check_name: String, text: String) -> CheckBox:
	if row == null:
		return null
	var check := row.get_node_or_null(check_name) as CheckBox
	if check == null:
		check = CheckBox.new()
		check.name = check_name
		row.add_child(check)
	check.text = text
	return check


func _ensure_line_edit(row: HBoxContainer, edit_name: String, placeholder: String) -> LineEdit:
	if row == null:
		return null
	var edit := row.get_node_or_null(edit_name) as LineEdit
	if edit == null:
		edit = LineEdit.new()
		edit.name = edit_name
		row.add_child(edit)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = placeholder
	return edit


func _ensure_color_picker(row: HBoxContainer, picker_name: String, color: Color) -> ColorPickerButton:
	if row == null:
		return null
	var picker := row.get_node_or_null(picker_name) as ColorPickerButton
	if picker == null:
		picker = ColorPickerButton.new()
		picker.name = picker_name
		row.add_child(picker)
	picker.color = color
	return picker


func _ensure_advanced_feature_rows() -> void:
	var vbox := _get_settings_vbox()
	if vbox == null:
		return

	# Capture workflow rows (timer/burst/bracket/watermark) are inserted above Export section.
	var capture_before := "ExportHeaderRow"
	var row_timer := _ensure_row_at(vbox, "CaptureTimerRow", capture_before)
	_ensure_label(row_timer, "CaptureTimerLabel", "Timer")
	_capture_timer_slider = _ensure_slider(row_timer, "CaptureTimerSlider", 0.0, 10.0, 1.0, 0.0)
	_capture_timer_value = _ensure_value_label(row_timer, "CaptureTimerValue", "0s")

	var row_burst := _ensure_row_at(vbox, "CaptureBurstRow", capture_before)
	_ensure_label(row_burst, "CaptureBurstLabel", "Burst")
	_capture_burst_options = _ensure_option(row_burst, "CaptureBurstOptions")

	var row_bracket := _ensure_row_at(vbox, "CaptureBracketRow", capture_before)
	_ensure_label(row_bracket, "CaptureBracketLabel", "Bracket")
	_capture_bracket_options = _ensure_option(row_bracket, "CaptureBracketOptions")

	var row_bracket_step := _ensure_row_at(vbox, "CaptureBracketStepRow", capture_before)
	_ensure_label(row_bracket_step, "CaptureBracketStepLabel", "Bracket EV")
	_capture_bracket_step_slider = _ensure_slider(row_bracket_step, "CaptureBracketStepSlider", 0.3, 2.0, 0.1, 1.0)
	_capture_bracket_step_value = _ensure_value_label(row_bracket_step, "CaptureBracketStepValue", "1.0")

	var row_watermark := _ensure_row_at(vbox, "CaptureWatermarkRow", capture_before)
	_ensure_label(row_watermark, "CaptureWatermarkLabel", "Watermark")
	_capture_watermark_toggle = _ensure_checkbox(row_watermark, "CaptureWatermarkToggle", "On")

	var row_watermark_text := _ensure_row_at(vbox, "CaptureWatermarkTextRow", capture_before)
	_ensure_label(row_watermark_text, "CaptureWatermarkTextLabel", "Watermark Text")
	_capture_watermark_text = _ensure_line_edit(row_watermark_text, "CaptureWatermarkText", "Sacred Fruit")
	if _capture_watermark_text and _capture_watermark_text.text.strip_edges().is_empty():
		_capture_watermark_text.text = "Sacred Fruit"

	# Fog controls replace the old "(future)" placeholder.
	var fog_row := _ensure_row_at(vbox, "FogRow", "FogNote")
	_ensure_label(fog_row, "FogLabel", "Fog")
	_fog_toggle = _ensure_checkbox(fog_row, "FogToggle", "On")

	var row_sun_shadow := _ensure_row_at(vbox, "SunShadowRow", "FogRow")
	_ensure_label(row_sun_shadow, "SunShadowLabel", "Sun Shadows")
	_sun_shadow_toggle = _ensure_checkbox(row_sun_shadow, "SunShadowToggle", "On")

	var row_sun_shadow_opacity := _ensure_row_at(vbox, "SunShadowOpacityRow", "FogRow")
	_ensure_label(row_sun_shadow_opacity, "SunShadowOpacityLabel", "Shadow Opacity")
	_sun_shadow_opacity_slider = _ensure_slider(row_sun_shadow_opacity, "SunShadowOpacitySlider", 0.0, 1.0, 0.01, 1.0)
	_sun_shadow_opacity_value = _ensure_value_label(row_sun_shadow_opacity, "SunShadowOpacityValue", "1.00")

	var row_sun_softness := _ensure_row_at(vbox, "SunSoftnessRow", "FogRow")
	_ensure_label(row_sun_softness, "SunSoftnessLabel", "Sun Softness")
	_sun_softness_slider = _ensure_slider(row_sun_softness, "SunSoftnessSlider", 0.0, 6.0, 0.05, 0.0)
	_sun_softness_value = _ensure_value_label(row_sun_softness, "SunSoftnessValue", "0.00")

	var row_sun_color := _ensure_row_at(vbox, "SunColorRow", "FogRow")
	_ensure_label(row_sun_color, "SunColorLabel", "Sun Color")
	_sun_color_picker = _ensure_color_picker(row_sun_color, "SunColorPicker", Color(1.0, 0.98, 0.92, 1.0))

	var row_ambient_color := _ensure_row_at(vbox, "AmbientColorRow", "FogRow")
	_ensure_label(row_ambient_color, "AmbientColorLabel", "Ambient Color")
	_ambient_color_picker = _ensure_color_picker(row_ambient_color, "AmbientColorPicker", Color(0.6, 0.65, 0.7, 1.0))

	var row_fog_color := _ensure_row_at(vbox, "FogColorRow", "FogNote")
	_ensure_label(row_fog_color, "FogColorLabel", "Fog Color")
	_fog_color_picker = _ensure_color_picker(row_fog_color, "FogColorPicker", Color(0.72, 0.77, 0.83, 1.0))

	var row_fog_density := _ensure_row_at(vbox, "FogDensityRow", "FogNote")
	_ensure_label(row_fog_density, "FogDensityLabel", "Fog Density")
	_fog_density_slider = _ensure_slider(row_fog_density, "FogDensitySlider", 0.0, 0.2, 0.002, 0.0)
	_fog_density_value = _ensure_value_label(row_fog_density, "FogDensityValue", "0.000")

	var row_fog_begin := _ensure_row_at(vbox, "FogBeginRow", "FogNote")
	_ensure_label(row_fog_begin, "FogBeginLabel", "Fog Near")
	_fog_begin_slider = _ensure_slider(row_fog_begin, "FogBeginSlider", 0.0, 200.0, 1.0, 5.0)
	_fog_begin_value = _ensure_value_label(row_fog_begin, "FogBeginValue", "5m")

	var row_fog_end := _ensure_row_at(vbox, "FogEndRow", "FogNote")
	_ensure_label(row_fog_end, "FogEndLabel", "Fog Far")
	_fog_end_slider = _ensure_slider(row_fog_end, "FogEndSlider", 20.0, 800.0, 1.0, 200.0)
	_fog_end_value = _ensure_value_label(row_fog_end, "FogEndValue", "200m")

	var row_fog_height := _ensure_row_at(vbox, "FogHeightRow", "FogNote")
	_ensure_label(row_fog_height, "FogHeightLabel", "Height Fog")
	_fog_height_toggle = _ensure_checkbox(row_fog_height, "FogHeightToggle", "On")

	var row_fog_height_density := _ensure_row_at(vbox, "FogHeightDensityRow", "FogNote")
	_ensure_label(row_fog_height_density, "FogHeightDensityLabel", "Height Density")
	_fog_height_density_slider = _ensure_slider(row_fog_height_density, "FogHeightDensitySlider", 0.0, 0.4, 0.002, 0.05)
	_fog_height_density_value = _ensure_value_label(row_fog_height_density, "FogHeightDensityValue", "0.050")

	var row_fog_height_falloff := _ensure_row_at(vbox, "FogHeightFalloffRow", "FogNote")
	_ensure_label(row_fog_height_falloff, "FogHeightFalloffLabel", "Height Falloff")
	_fog_height_falloff_slider = _ensure_slider(row_fog_height_falloff, "FogHeightFalloffSlider", 0.05, 2.0, 0.01, 0.5)
	_fog_height_falloff_value = _ensure_value_label(row_fog_height_falloff, "FogHeightFalloffValue", "0.50")

	var row_volumetric := _ensure_row_at(vbox, "VolumetricFogRow", "FogNote")
	_ensure_label(row_volumetric, "VolumetricFogLabel", "Volumetric Fog")
	_volumetric_fog_toggle = _ensure_checkbox(row_volumetric, "VolumetricFogToggle", "On")

	var row_vol_density := _ensure_row_at(vbox, "VolumetricDensityRow", "FogNote")
	_ensure_label(row_vol_density, "VolumetricDensityLabel", "Vol Density")
	_volumetric_fog_density_slider = _ensure_slider(row_vol_density, "VolumetricDensitySlider", 0.0, 0.2, 0.002, 0.03)
	_volumetric_fog_density_value = _ensure_value_label(row_vol_density, "VolumetricDensityValue", "0.030")

	var row_vol_aniso := _ensure_row_at(vbox, "VolumetricAnisoRow", "FogNote")
	_ensure_label(row_vol_aniso, "VolumetricAnisoLabel", "Vol Anisotropy")
	_volumetric_fog_aniso_slider = _ensure_slider(row_vol_aniso, "VolumetricAnisoSlider", -0.9, 0.9, 0.01, 0.0)
	_volumetric_fog_aniso_value = _ensure_value_label(row_vol_aniso, "VolumetricAnisoValue", "0.00")

	var fog_note := vbox.get_node_or_null("FogNote") as CanvasItem
	if fog_note:
		fog_note.visible = false

	var row_ps1 := _ensure_row_at(vbox, "PS1ShaderRow", "CompositionHeaderRow")
	_ensure_label(row_ps1, "PS1ShaderLabel", "PS1 Shader")
	_ps1_shader_toggle = _ensure_checkbox(row_ps1, "PS1ShaderToggle", "On")

	var row_postfx := _ensure_row_at(vbox, "PostFXRow", "CompositionHeaderRow")
	_ensure_label(row_postfx, "PostFXLabel", "Post FX")
	_postfx_toggle = _ensure_checkbox(row_postfx, "PostFXToggle", "On")

	var row_postfx_fog := _ensure_row_at(vbox, "PostFXFogRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_fog, "PostFXFogLabel", "Post Fog")
	_postfx_fog_toggle = _ensure_checkbox(row_postfx_fog, "PostFXFogToggle", "On")

	var row_postfx_fog_dist := _ensure_row_at(vbox, "PostFXFogDistanceRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_fog_dist, "PostFXFogDistanceLabel", "Post Fog Dist")
	_postfx_fog_distance_slider = _ensure_slider(row_postfx_fog_dist, "PostFXFogDistanceSlider", 1.0, 6000.0, 1.0, 120.0)
	_postfx_fog_distance_value = _ensure_value_label(row_postfx_fog_dist, "PostFXFogDistanceValue", "120m")

	var row_postfx_fog_fade := _ensure_row_at(vbox, "PostFXFogFadeRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_fog_fade, "PostFXFogFadeLabel", "Post Fog Fade")
	_postfx_fog_fade_slider = _ensure_slider(row_postfx_fog_fade, "PostFXFogFadeSlider", 1.0, 6000.0, 1.0, 60.0)
	_postfx_fog_fade_value = _ensure_value_label(row_postfx_fog_fade, "PostFXFogFadeValue", "60m")

	var row_postfx_noise := _ensure_row_at(vbox, "PostFXNoiseRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_noise, "PostFXNoiseLabel", "Post Noise")
	_postfx_noise_toggle = _ensure_checkbox(row_postfx_noise, "PostFXNoiseToggle", "On")

	var row_postfx_noise_time := _ensure_row_at(vbox, "PostFXNoiseTimeRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_noise_time, "PostFXNoiseTimeLabel", "Noise Speed")
	_postfx_noise_time_slider = _ensure_slider(row_postfx_noise_time, "PostFXNoiseTimeSlider", 0.1, 10.0, 0.1, 4.0)
	_postfx_noise_time_value = _ensure_value_label(row_postfx_noise_time, "PostFXNoiseTimeValue", "4.0")

	var row_postfx_color_limit := _ensure_row_at(vbox, "PostFXColorLimitRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_color_limit, "PostFXColorLimitLabel", "Color Limit")
	_postfx_color_limit_toggle = _ensure_checkbox(row_postfx_color_limit, "PostFXColorLimitToggle", "On")
	if _postfx_color_limit_toggle and not _postfx_color_limit_toggle.button_pressed:
		_set_check_value(_postfx_color_limit_toggle, true)

	var row_postfx_levels := _ensure_row_at(vbox, "PostFXColorLevelsRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_levels, "PostFXColorLevelsLabel", "Color Levels")
	_postfx_color_levels_slider = _ensure_slider(row_postfx_levels, "PostFXColorLevelsSlider", 2.0, 256.0, 1.0, 32.0)
	_postfx_color_levels_value = _ensure_value_label(row_postfx_levels, "PostFXColorLevelsValue", "32")

	var row_postfx_dither := _ensure_row_at(vbox, "PostFXDitherRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_dither, "PostFXDitherLabel", "Post Dither")
	_postfx_dither_toggle = _ensure_checkbox(row_postfx_dither, "PostFXDitherToggle", "On")
	if _postfx_dither_toggle and not _postfx_dither_toggle.button_pressed:
		_set_check_value(_postfx_dither_toggle, true)

	var row_postfx_dither_strength := _ensure_row_at(vbox, "PostFXDitherStrengthRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_dither_strength, "PostFXDitherStrengthLabel", "Dither Amt")
	_postfx_dither_strength_slider = _ensure_slider(row_postfx_dither_strength, "PostFXDitherStrengthSlider", 0.0, 1.0, 0.01, 0.35)
	_postfx_dither_strength_value = _ensure_value_label(row_postfx_dither_strength, "PostFXDitherStrengthValue", "0.35")

	var row_postfx_opacity := _ensure_row_at(vbox, "PostFXOpacityRow", "CompositionHeaderRow")
	_ensure_label(row_postfx_opacity, "PostFXOpacityLabel", "Post Mix")
	_postfx_opacity_slider = _ensure_slider(row_postfx_opacity, "PostFXOpacitySlider", 0.0, 1.0, 0.01, 1.0)
	_postfx_opacity_value = _ensure_value_label(row_postfx_opacity, "PostFXOpacityValue", "1.00")

	# Composition tools replace the old note-only section.
	var row_crop := _ensure_row_at(vbox, "CompositionCropRow", "CompositionNote")
	_ensure_label(row_crop, "CompositionCropLabel", "Crop Box")
	_composition_crop_options = _ensure_option(row_crop, "CompositionCropOptions")

	var row_offset_x := _ensure_row_at(vbox, "CompositionOffsetXRow", "CompositionNote")
	_ensure_label(row_offset_x, "CompositionOffsetXLabel", "Crop X")
	_composition_offset_x_slider = _ensure_slider(row_offset_x, "CompositionOffsetXSlider", -1.0, 1.0, 0.01, 0.0)
	_composition_offset_x_value = _ensure_value_label(row_offset_x, "CompositionOffsetXValue", "0.00")

	var row_offset_y := _ensure_row_at(vbox, "CompositionOffsetYRow", "CompositionNote")
	_ensure_label(row_offset_y, "CompositionOffsetYLabel", "Crop Y")
	_composition_offset_y_slider = _ensure_slider(row_offset_y, "CompositionOffsetYSlider", -1.0, 1.0, 0.01, 0.0)
	_composition_offset_y_value = _ensure_value_label(row_offset_y, "CompositionOffsetYValue", "0.00")

	var row_roll := _ensure_row_at(vbox, "CompositionRollRow", "CompositionNote")
	_ensure_label(row_roll, "CompositionRollLabel", "Horizon")
	_composition_roll_slider = _ensure_slider(row_roll, "CompositionRollSlider", -45.0, 45.0, 0.1, 0.0)
	_composition_roll_value = _ensure_value_label(row_roll, "CompositionRollValue", "0.0°")

	var row_snap := _ensure_row_at(vbox, "CompositionSnapRow", "CompositionNote")
	_ensure_label(row_snap, "CompositionSnapLabel", "Thirds Snap")
	_composition_snap_toggle = _ensure_checkbox(row_snap, "CompositionSnapToggle", "On")

	var composition_note := vbox.get_node_or_null("CompositionNote") as CanvasItem
	if composition_note:
		composition_note.visible = false


func _populate_capture_workflow_options() -> void:
	if _capture_burst_options:
		_capture_burst_options.clear()
		var burst_counts := [1, 3, 5]
		for i in range(burst_counts.size()):
			var count: int = burst_counts[i]
			_capture_burst_options.add_item("%dx" % count)
			_capture_burst_options.set_item_metadata(i, count)
		_capture_burst_options.select(0)
	if _capture_bracket_options:
		_capture_bracket_options.clear()
		var bracket_modes := [1, 3, 5]
		for i in range(bracket_modes.size()):
			var count: int = bracket_modes[i]
			_capture_bracket_options.add_item("%d exposures" % count)
			_capture_bracket_options.set_item_metadata(i, count)
		_capture_bracket_options.select(0)
	_on_capture_timer_changed(_capture_timer_slider.value if _capture_timer_slider else 0.0)
	_on_capture_bracket_step_changed(_capture_bracket_step_slider.value if _capture_bracket_step_slider else 1.0)


func _populate_composition_options() -> void:
	if _composition_crop_options == null:
		return
	_composition_crop_options.clear()
	var items := [
		{"label": "Follow Capture Aspect", "ratio": 0.0},
		{"label": "16:9", "ratio": 16.0 / 9.0},
		{"label": "3:2", "ratio": 3.0 / 2.0},
		{"label": "4:3", "ratio": 4.0 / 3.0},
		{"label": "1:1", "ratio": 1.0},
		{"label": "4:5", "ratio": 4.0 / 5.0},
		{"label": "9:16", "ratio": 9.0 / 16.0}
	]
	for i in range(items.size()):
		var item: Dictionary = items[i]
		_composition_crop_options.add_item(String(item["label"]))
		_composition_crop_options.set_item_metadata(i, item)
	_composition_crop_options.select(0)
	_on_composition_crop_selected(0)


func _setup_ui() -> void:
	_ensure_advanced_feature_rows()
	if _guides:
		_guides.visible = true
		_guides.z_index = -1
		_guides.z_as_relative = false
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
	if _sun_shadow_toggle:
		_sun_shadow_toggle.toggled.connect(_on_sun_shadow_toggled)
	if _sun_shadow_opacity_slider:
		_sun_shadow_opacity_slider.value_changed.connect(_on_sun_shadow_opacity_changed)
	if _sun_softness_slider:
		_sun_softness_slider.value_changed.connect(_on_sun_softness_changed)
	if _sun_color_picker:
		_sun_color_picker.color_changed.connect(_on_sun_color_changed)
	if _ambient_color_picker:
		_ambient_color_picker.color_changed.connect(_on_ambient_color_changed)
	if _fog_color_picker:
		_fog_color_picker.color_changed.connect(_on_fog_color_changed)
	if _fog_toggle:
		_fog_toggle.toggled.connect(_on_fog_toggled)
	if _fog_density_slider:
		_fog_density_slider.value_changed.connect(_on_fog_density_changed)
	if _fog_begin_slider:
		_fog_begin_slider.value_changed.connect(_on_fog_begin_changed)
	if _fog_end_slider:
		_fog_end_slider.value_changed.connect(_on_fog_end_changed)
	if _fog_height_toggle:
		_fog_height_toggle.toggled.connect(_on_fog_height_toggled)
	if _fog_height_density_slider:
		_fog_height_density_slider.value_changed.connect(_on_fog_height_density_changed)
	if _fog_height_falloff_slider:
		_fog_height_falloff_slider.value_changed.connect(_on_fog_height_falloff_changed)
	if _volumetric_fog_toggle:
		_volumetric_fog_toggle.toggled.connect(_on_volumetric_fog_toggled)
	if _volumetric_fog_density_slider:
		_volumetric_fog_density_slider.value_changed.connect(_on_volumetric_density_changed)
	if _volumetric_fog_aniso_slider:
		_volumetric_fog_aniso_slider.value_changed.connect(_on_volumetric_aniso_changed)
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
	if _ps1_shader_toggle:
		_ps1_shader_toggle.toggled.connect(_on_ps1_shader_toggled)
		_set_check_value(_ps1_shader_toggle, _is_ps1_shader_enabled())
		# Force a refresh so newly built photo-mode meshes get the current PS1 state.
		_set_ps1_shader_enabled(_is_ps1_shader_enabled())
	if _postfx_toggle:
		_postfx_toggle.toggled.connect(_on_postfx_toggled)
		_set_check_value(_postfx_toggle, _postfx_enabled)
	if _postfx_fog_toggle:
		_postfx_fog_toggle.toggled.connect(_on_postfx_fog_toggled)
	if _postfx_fog_distance_slider:
		_postfx_fog_distance_slider.value_changed.connect(_on_postfx_fog_distance_changed)
		_on_postfx_fog_distance_changed(_postfx_fog_distance_slider.value)
	if _postfx_fog_fade_slider:
		_postfx_fog_fade_slider.value_changed.connect(_on_postfx_fog_fade_changed)
		_on_postfx_fog_fade_changed(_postfx_fog_fade_slider.value)
	if _postfx_noise_toggle:
		_postfx_noise_toggle.toggled.connect(_on_postfx_noise_toggled)
	if _postfx_noise_time_slider:
		_postfx_noise_time_slider.value_changed.connect(_on_postfx_noise_time_changed)
		_on_postfx_noise_time_changed(_postfx_noise_time_slider.value)
	if _postfx_color_limit_toggle:
		_postfx_color_limit_toggle.toggled.connect(_on_postfx_color_limit_toggled)
	if _postfx_color_levels_slider:
		_postfx_color_levels_slider.value_changed.connect(_on_postfx_color_levels_changed)
		_on_postfx_color_levels_changed(_postfx_color_levels_slider.value)
	if _postfx_dither_toggle:
		_postfx_dither_toggle.toggled.connect(_on_postfx_dither_toggled)
	if _postfx_dither_strength_slider:
		_postfx_dither_strength_slider.value_changed.connect(_on_postfx_dither_strength_changed)
		_on_postfx_dither_strength_changed(_postfx_dither_strength_slider.value)
	if _postfx_opacity_slider:
		_postfx_opacity_slider.value_changed.connect(_on_postfx_opacity_changed)
		_on_postfx_opacity_changed(_postfx_opacity_slider.value)
	_apply_postfx_settings()
	if _preset_save:
		_preset_save.pressed.connect(_on_preset_save)
	if _preset_load:
		_preset_load.pressed.connect(_on_preset_load)
	if _preset_delete:
		_preset_delete.pressed.connect(_on_preset_delete)
	if _capture_timer_slider:
		_capture_timer_slider.value_changed.connect(_on_capture_timer_changed)
	if _capture_bracket_step_slider:
		_capture_bracket_step_slider.value_changed.connect(_on_capture_bracket_step_changed)
	if _capture_watermark_toggle:
		_capture_watermark_toggle.toggled.connect(_on_capture_watermark_toggled)
	if _capture_watermark_text:
		_capture_watermark_text.text_submitted.connect(_on_capture_watermark_text_submitted)
	if _composition_crop_options:
		_populate_composition_options()
		_composition_crop_options.item_selected.connect(_on_composition_crop_selected)
	if _composition_offset_x_slider:
		_composition_offset_x_slider.value_changed.connect(_on_composition_offset_x_changed)
	if _composition_offset_y_slider:
		_composition_offset_y_slider.value_changed.connect(_on_composition_offset_y_changed)
	if _composition_roll_slider:
		_composition_roll_slider.value_changed.connect(_on_composition_roll_changed)
		_on_composition_roll_changed(_composition_roll_slider.value)
	if _composition_snap_toggle:
		_composition_snap_toggle.toggled.connect(_on_composition_snap_toggled)

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
		if not export_btn.is_connected("pressed", Callable(self, "_on_export_state_pressed")):
			export_btn.pressed.connect(_on_export_state_pressed)
	if import_btn:
		if not import_btn.is_connected("pressed", Callable(self, "_on_import_state_pressed")):
			import_btn.pressed.connect(_on_import_state_pressed)
	_load_presets()
	_setup_collapsibles()
	_setup_tabs()
	_ensure_settings_labels()
	_ensure_contact_strip()
	if _capture_button:
		if not _capture_button.is_connected("pressed", Callable(self, "_on_capture_pressed")):
			_capture_button.pressed.connect(_on_capture_pressed)

	# Connect toolbar buttons if present
	if _viewfinder_toggle:
		if not _viewfinder_toggle.is_connected("toggled", Callable(self, "_on_toolbar_viewfinder_pressed")):
			_viewfinder_toggle.toggled.connect(_on_toolbar_viewfinder_pressed)
	if _guides_toggle:
		if not _guides_toggle.is_connected("toggled", Callable(self, "_on_toolbar_guides_pressed")):
			_guides_toggle.toggled.connect(_on_toolbar_guides_pressed)
	if _toolbar_capture:
		if not _toolbar_capture.is_connected("pressed", Callable(self, "_on_capture_pressed")):
			_toolbar_capture.pressed.connect(_on_capture_pressed)
	if _toolbar_layers:
		if not _toolbar_layers.is_connected("pressed", Callable(self, "_on_capture_layers_pressed")):
			_toolbar_layers.pressed.connect(_on_capture_layers_pressed)
	if _toolbar_back:
		if not _toolbar_back.is_connected("pressed", Callable(self, "_on_back_pressed")):
			_toolbar_back.pressed.connect(_on_back_pressed)
	if _capture_format_options:
		_populate_capture_formats()
	_populate_capture_workflow_options()
	if _capture_watermark_toggle:
		_on_capture_watermark_toggled(_capture_watermark_toggle.button_pressed)
	if _capture_path_button:
		if not _capture_path_button.is_connected("pressed", Callable(self, "_on_capture_path_browse")):
			_capture_path_button.pressed.connect(_on_capture_path_browse)
	if _capture_path_dialog:
		if not _capture_path_dialog.is_connected("dir_selected", Callable(self, "_on_capture_path_dir_selected")):
			_capture_path_dialog.dir_selected.connect(_on_capture_path_dir_selected)
	if _capture_layers_button:
		if not _capture_layers_button.is_connected("pressed", Callable(self, "_on_capture_layers_pressed")):
			_capture_layers_button.pressed.connect(_on_capture_layers_pressed)
	if _back_button:
		if not _back_button.is_connected("pressed", Callable(self, "_on_back_pressed")):
			_back_button.pressed.connect(_on_back_pressed)
	_setup_light_rig_ui()
	if _pass_preview_options:
		_populate_pass_preview()
		_pass_preview_options.item_selected.connect(_on_pass_preview_selected)
	if _capture_path_edit and _capture_path_edit.text.strip_edges().is_empty():
		_capture_path_edit.text = PHOTO_CAPTURE_DIR
	_sync_environment_controls_from_scene()
	_apply_fog_settings()
	_update_viewfinder()
	_apply_ui_density_tuning()
	# Setup thumbnail menu and export dialog
	if _ui_root:
		_thumb_menu = _ui_root.get_node_or_null("ThumbnailMenu") as PopupMenu
		if _thumb_menu == null:
			_thumb_menu = PopupMenu.new()
			_thumb_menu.name = "ThumbnailMenu"
			_ui_root.add_child(_thumb_menu)
		_thumb_menu.clear()
		_thumb_menu.add_item("Preview", THUMB_MENU_PREVIEW)
		_thumb_menu.add_item("Reapply Settings", THUMB_MENU_REAPPLY)
		_thumb_menu.add_item("Show in Finder", THUMB_MENU_SHOW_IN_FINDER)
		_thumb_menu.add_separator()
		_thumb_menu.add_item("Export...", THUMB_MENU_EXPORT)
		_thumb_menu.add_item("Delete", THUMB_MENU_DELETE)
		if not _thumb_menu.is_connected("id_pressed", Callable(self, "_on_thumb_menu_id_pressed")):
			_thumb_menu.id_pressed.connect(_on_thumb_menu_id_pressed)

		_thumb_export_dialog = _ui_root.get_node_or_null("ThumbExportDialog") as FileDialog
		if _thumb_export_dialog == null:
			_thumb_export_dialog = FileDialog.new()
			_thumb_export_dialog.name = "ThumbExportDialog"
			_thumb_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
			# MODE_SAVE_FILE constant may not be available in all environments; use numeric value for save mode
			_thumb_export_dialog.mode = 2
			_thumb_export_dialog.add_filter("*.png ; PNG image")
			_thumb_export_dialog.add_filter("*.jpg ; JPEG image")
			_ui_root.add_child(_thumb_export_dialog)
		if not _thumb_export_dialog.is_connected("file_selected", Callable(self, "_on_thumb_export_selected")):
			_thumb_export_dialog.file_selected.connect(_on_thumb_export_selected)


func _setup_ui_chrome() -> void:
	if _ui_root == null:
		return

	var root_margin := _ui_root.get_node_or_null("RootMargin") as Control
	if root_margin:
		# Reserve space for Toolbar (top) and Filmstrip (bottom)
		root_margin.offset_top = 76.0
		root_margin.offset_bottom = -156.0

	var toolbar := _ui_root.get_node_or_null("Toolbar") as Control
	if toolbar:
		toolbar.visible = true
		toolbar.z_index = 200
		toolbar.mouse_filter = Control.MOUSE_FILTER_STOP

	var filmstrip := _ui_root.get_node_or_null("Filmstrip") as Control
	if filmstrip:
		filmstrip.visible = true
		filmstrip.z_index = 200
		filmstrip.mouse_filter = Control.MOUSE_FILTER_STOP


func _apply_ui_density_tuning() -> void:
	var panel := get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel") as Control
	if panel:
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var viewport_width := get_viewport().get_visible_rect().size.x
		var target_width := clampf(viewport_width * 0.38, 520.0, 700.0)
		panel.custom_minimum_size = Vector2(target_width, 0.0)

	var margin := get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin") as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_bottom", 14)

	var scroll := get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll") as ScrollContainer
	if scroll:
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox") as VBoxContainer
	if vbox:
		vbox.add_theme_constant_override("separation", 8)
		for child in vbox.get_children():
			if child is HBoxContainer:
				var row := child as HBoxContainer
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.custom_minimum_size = Vector2(0.0, 40.0)
				row.add_theme_constant_override("separation", 10)
				for row_child in row.get_children():
					if not (row_child is Control):
						continue
					var ctrl := row_child as Control
					ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					if ctrl is HSlider:
						ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						ctrl.custom_minimum_size = Vector2(220.0, 30.0)
					elif ctrl is OptionButton or ctrl is LineEdit or ctrl is ColorPickerButton:
						ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						ctrl.custom_minimum_size = Vector2(220.0, 34.0)
						ctrl.add_theme_font_size_override("font_size", 15)
					elif ctrl is CheckBox:
						ctrl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
						ctrl.custom_minimum_size = Vector2(0.0, 34.0)
						ctrl.add_theme_font_size_override("font_size", 15)
					elif ctrl is Label:
						var label := ctrl as Label
						if String(label.name).ends_with("Value"):
							label.size_flags_horizontal = Control.SIZE_SHRINK_END
							label.custom_minimum_size = Vector2(92.0, 0.0)
							label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						elif String(label.name).ends_with("Label") or String(label.name).ends_with("Header"):
							label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
							label.custom_minimum_size = Vector2(112.0, 0.0)
						label.add_theme_font_size_override("font_size", 15)
			elif child is GridContainer:
				var grid := child as GridContainer
				grid.add_theme_constant_override("h_separation", 8)
				grid.add_theme_constant_override("v_separation", 6)


func _ensure_settings_labels() -> void:
	var base_path := "CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox"
	var label_rows: Array[Dictionary] = [
		{"row": "FOVRow", "name": "FOVLabel", "text": "FOV"},
		{"row": "FocalRow", "name": "FocalLabel", "text": "Focal"},
		{"row": "ISORow", "name": "ISOLabel", "text": "ISO"},
		{"row": "ApertureRow", "name": "ApertureLabel", "text": "Aperture"},
		{"row": "ShutterRow", "name": "ShutterLabel", "text": "Shutter"},
		{"row": "FocusRow", "name": "FocusLabel", "text": "Focus"},
		{"row": "ShootingModeRow", "name": "ShootingModeLabel", "text": "Mode"},
		{"row": "AutoFocusRow", "name": "AutoFocusLabel", "text": "Auto Focus"},
		{"row": "ExposureRow", "name": "ExposureLabel", "text": "Exposure"},
		{"row": "AutoExposureRow", "name": "AutoExposureLabel", "text": "Auto Exposure"},
		{"row": "AutoExposureSpeedRow", "name": "AutoExposureSpeedLabel", "text": "AE Speed"},
		{"row": "AutoExposureRangeRow", "name": "AutoExposureRangeLabel", "text": "AE Range"},
		{"row": "GuidesRow", "name": "GuidesLabel", "text": "Guides"},
		{"row": "GuidesOpacityRow", "name": "GuidesOpacityLabel", "text": "Opacity"},
		{"row": "ResRow", "name": "ResLabel", "text": "Resolution"},
		{"row": "AspectRow", "name": "AspectLabel", "text": "Aspect"},
		{"row": "CaptureFormatRow", "name": "CaptureFormatLabel", "text": "Format"},
		{"row": "CapturePathRow", "name": "CapturePathLabel", "text": "Save Path"},
		{"row": "CaptureTimerRow", "name": "CaptureTimerLabel", "text": "Timer"},
		{"row": "CaptureBurstRow", "name": "CaptureBurstLabel", "text": "Burst"},
		{"row": "CaptureBracketRow", "name": "CaptureBracketLabel", "text": "Bracket"},
		{"row": "CaptureBracketStepRow", "name": "CaptureBracketStepLabel", "text": "Bracket EV"},
		{"row": "CaptureWatermarkRow", "name": "CaptureWatermarkLabel", "text": "Watermark"},
		{"row": "CaptureWatermarkTextRow", "name": "CaptureWatermarkTextLabel", "text": "Watermark Text"},
		{"row": "PassPreviewRow", "name": "PassPreviewLabel", "text": "Preview"},
		{"row": "EnvRow", "name": "EnvLabel", "text": "Environment"},
		{"row": "SunAngleRow", "name": "SunAngleLabel", "text": "Sun Angle"},
		{"row": "AmbientRow", "name": "AmbientLabel", "text": "Ambient"},
		{"row": "SunShadowRow", "name": "SunShadowLabel", "text": "Sun Shadows"},
		{"row": "SunShadowOpacityRow", "name": "SunShadowOpacityLabel", "text": "Shadow Opacity"},
		{"row": "SunSoftnessRow", "name": "SunSoftnessLabel", "text": "Sun Softness"},
		{"row": "SunColorRow", "name": "SunColorLabel", "text": "Sun Color"},
		{"row": "AmbientColorRow", "name": "AmbientColorLabel", "text": "Ambient Color"},
		{"row": "FogRow", "name": "FogLabel", "text": "Fog"},
		{"row": "FogColorRow", "name": "FogColorLabel", "text": "Fog Color"},
		{"row": "FogDensityRow", "name": "FogDensityLabel", "text": "Fog Density"},
		{"row": "FogBeginRow", "name": "FogBeginLabel", "text": "Fog Near"},
		{"row": "FogEndRow", "name": "FogEndLabel", "text": "Fog Far"},
		{"row": "FogHeightRow", "name": "FogHeightLabel", "text": "Height Fog"},
		{"row": "FogHeightDensityRow", "name": "FogHeightDensityLabel", "text": "Height Density"},
		{"row": "FogHeightFalloffRow", "name": "FogHeightFalloffLabel", "text": "Height Falloff"},
		{"row": "VolumetricFogRow", "name": "VolumetricFogLabel", "text": "Volumetric Fog"},
		{"row": "VolumetricDensityRow", "name": "VolumetricDensityLabel", "text": "Vol Density"},
		{"row": "VolumetricAnisoRow", "name": "VolumetricAnisoLabel", "text": "Vol Anisotropy"},
		{"row": "TempRow", "name": "TempLabel", "text": "Temperature"},
		{"row": "TintRow", "name": "TintLabel", "text": "Tint"},
		{"row": "SaturationRow", "name": "SaturationLabel", "text": "Saturation"},
		{"row": "ContrastRow", "name": "ContrastLabel", "text": "Contrast"},
		{"row": "VignetteRow", "name": "VignetteLabel", "text": "Vignette"},
		{"row": "GrainRow", "name": "GrainLabel", "text": "Grain"},
		{"row": "BloomRow", "name": "BloomLabel", "text": "Bloom"},
		{"row": "PS1ShaderRow", "name": "PS1ShaderLabel", "text": "PS1 Shader"},
		{"row": "PostFXRow", "name": "PostFXLabel", "text": "Post FX"},
		{"row": "PostFXFogRow", "name": "PostFXFogLabel", "text": "Post Fog"},
		{"row": "PostFXFogDistanceRow", "name": "PostFXFogDistanceLabel", "text": "Post Fog Dist"},
		{"row": "PostFXFogFadeRow", "name": "PostFXFogFadeLabel", "text": "Post Fog Fade"},
		{"row": "PostFXNoiseRow", "name": "PostFXNoiseLabel", "text": "Post Noise"},
		{"row": "PostFXNoiseTimeRow", "name": "PostFXNoiseTimeLabel", "text": "Noise Speed"},
		{"row": "PostFXColorLimitRow", "name": "PostFXColorLimitLabel", "text": "Color Limit"},
		{"row": "PostFXColorLevelsRow", "name": "PostFXColorLevelsLabel", "text": "Color Levels"},
		{"row": "PostFXDitherRow", "name": "PostFXDitherLabel", "text": "Post Dither"},
		{"row": "PostFXDitherStrengthRow", "name": "PostFXDitherStrengthLabel", "text": "Dither Amt"},
		{"row": "PostFXOpacityRow", "name": "PostFXOpacityLabel", "text": "Post Mix"},
		{"row": "CompositionCropRow", "name": "CompositionCropLabel", "text": "Crop Box"},
		{"row": "CompositionOffsetXRow", "name": "CompositionOffsetXLabel", "text": "Crop X"},
		{"row": "CompositionOffsetYRow", "name": "CompositionOffsetYLabel", "text": "Crop Y"},
		{"row": "CompositionRollRow", "name": "CompositionRollLabel", "text": "Horizon"},
		{"row": "CompositionSnapRow", "name": "CompositionSnapLabel", "text": "Thirds Snap"},
		{"row": "PresetsRow", "name": "PresetsLabel", "text": "Preset"},
		{"row": "PresetNameRow", "name": "PresetNameLabel", "text": "Name"}
	]
	for row_info in label_rows:
		var row_path := "%s/%s" % [base_path, String(row_info.get("row", ""))]
		var row := get_node_or_null(row_path) as HBoxContainer
		if row == null:
			continue
		var label_name := String(row_info.get("name", ""))
		if label_name.is_empty():
			continue
		var label_text := String(row_info.get("text", ""))
		var label := row.get_node_or_null(label_name) as Label
		if label == null:
			label = Label.new()
			label.name = label_name
			row.add_child(label)
			row.move_child(label, 0)
		label.text = label_text
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.custom_minimum_size = Vector2(112.0, 0.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _on_always_show_viewport_toggled(pressed: bool) -> void:
	_always_show_viewport_enabled = pressed
	if pressed:
		_set_viewfinder_visible(true)
	else:
		# restore visibility based on current tab
		_set_viewfinder_visible(_active_tab == "capture")

func _ensure_contact_strip() -> void:
	if _bottom_bar == null:
		return
	_contact_strip = _bottom_bar.get_node_or_null("ContactStrip") as HBoxContainer
	if _contact_strip == null:
		_contact_strip = HBoxContainer.new()
		_contact_strip.name = "ContactStrip"
		_contact_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_contact_strip.custom_minimum_size = Vector2(0, 88)
		_bottom_bar.add_child(_contact_strip)


func _ensure_capture_preview_panel() -> void:
	if _capture_preview_panel != null:
		return
	_capture_preview_panel = Window.new()
	_capture_preview_panel.name = "CapturePreview"
	_capture_preview_panel.title = "Capture Preview"
	_capture_preview_panel.min_size = Vector2i(680, 460)
	add_child(_capture_preview_panel)
	_capture_preview_panel.visible = false
	if not _capture_preview_panel.is_connected("close_requested", Callable(self, "_on_capture_preview_close_requested")):
		_capture_preview_panel.close_requested.connect(_on_capture_preview_close_requested)

	var root := VBoxContainer.new()
	root.name = "PreviewRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10.0
	root.offset_top = 10.0
	root.offset_right = -10.0
	root.offset_bottom = -10.0
	root.add_theme_constant_override("separation", 8)
	_capture_preview_panel.add_child(root)

	var toolbar := HBoxContainer.new()
	toolbar.name = "PreviewToolbar"
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_theme_constant_override("separation", 6)
	root.add_child(toolbar)

	var zoom_out := Button.new()
	zoom_out.name = "PreviewZoomOut"
	zoom_out.text = "Zoom -"
	zoom_out.pressed.connect(_on_preview_zoom_out_pressed)
	toolbar.add_child(zoom_out)

	var zoom_in := Button.new()
	zoom_in.name = "PreviewZoomIn"
	zoom_in.text = "Zoom +"
	zoom_in.pressed.connect(_on_preview_zoom_in_pressed)
	toolbar.add_child(zoom_in)

	var zoom_fit := Button.new()
	zoom_fit.name = "PreviewZoomFit"
	zoom_fit.text = "Fit"
	zoom_fit.pressed.connect(_on_preview_zoom_fit_pressed)
	toolbar.add_child(zoom_fit)

	var compare := CheckBox.new()
	compare.name = "PreviewCompare"
	compare.text = "Compare"
	compare.toggled.connect(_on_preview_compare_toggled)
	toolbar.add_child(compare)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var reapply_btn := Button.new()
	reapply_btn.name = "PreviewReapply"
	reapply_btn.text = "Reapply"
	reapply_btn.pressed.connect(_on_preview_reapply_pressed)
	toolbar.add_child(reapply_btn)

	var restore_btn := Button.new()
	restore_btn.name = "PreviewRestore"
	restore_btn.text = "Restore Camera"
	restore_btn.pressed.connect(_on_preview_restore_pressed)
	toolbar.add_child(restore_btn)

	var finder_btn := Button.new()
	finder_btn.name = "PreviewFinder"
	finder_btn.text = "Show in Finder"
	finder_btn.pressed.connect(_on_preview_show_in_finder_pressed)
	toolbar.add_child(finder_btn)

	var delete_btn := Button.new()
	delete_btn.name = "PreviewDelete"
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(_on_preview_delete_pressed)
	toolbar.add_child(delete_btn)

	_preview_scroll = ScrollContainer.new()
	_preview_scroll.name = "PreviewScroll"
	_preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_preview_scroll)

	_preview_image_node = TextureRect.new()
	_preview_image_node.name = "PreviewImage"
	_preview_image_node.stretch_mode = TextureRect.STRETCH_SCALE
	_preview_image_node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview_image_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview_image_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_scroll.add_child(_preview_image_node)


func _on_capture_preview_close_requested() -> void:
	if _capture_preview_panel:
		_capture_preview_panel.hide()
	_preview_show_compare = false
	_preview_primary_texture = null
	_preview_compare_texture = null

func _debug_layout() -> void:
	if not _is_layout_debug_enabled():
		return
	await get_tree().process_frame
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


	# Additional layout info (kept in debug layout)
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

	# New: report any Control nodes that are NOT children of the canonical Settings VBox
	if _ui_root != null:
		var canonical_vbox := _ui_root.get_node_or_null("RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox")
		var stray := []
		for ctrl in _ui_root.find_children("*", "Control", true, false):
			if ctrl == canonical_vbox:
				continue
			if ctrl == tabs or ctrl == _ui_root.get_node_or_null("RootMargin"):
				continue
			# If control is not a descendant of the SettingsVBox and not one of the top chrome nodes, list it
			if canonical_vbox != null and canonical_vbox.is_ancestor_of(ctrl) == false:
				stray.append({"path": String(ctrl.get_path()), "parent": String(ctrl.get_parent().get_path()), "anchors": Vector4(ctrl.anchor_left, ctrl.anchor_top, ctrl.anchor_right, ctrl.anchor_bottom), "offsets": Vector4(ctrl.offset_left, ctrl.offset_top, ctrl.offset_right, ctrl.offset_bottom)})
		if stray.size() > 0:
			print("[PhotoMode DEBUG] stray_controls=", stray)


func _ensure_row(row_name: String, type_class: Variant, parent: Node, child_names: Array) -> void:
	if parent == null:
		return
	var row := _get_or_create_container(row_name, type_class, parent)
	if row is Control:
		(row as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Normalize anchors so rows occupy available width
		(row as Control).anchor_left = 0.0
		(row as Control).anchor_top = 0.0
		(row as Control).anchor_right = 1.0
		(row as Control).anchor_bottom = 0.0
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
			# defensive: ensure child controls have reasonable anchors when moved
			(node as Control).anchor_left = 0.0
			(node as Control).anchor_top = 0.0
			(node as Control).anchor_right = 1.0
			(node as Control).anchor_bottom = 0.0
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
		"CaptureTimerLabel": "Timer",
		"CaptureBurstLabel": "Burst",
		"CaptureBracketLabel": "Bracket",
		"CaptureBracketStepLabel": "Bracket EV",
		"CaptureWatermarkLabel": "Watermark",
		"CaptureWatermarkTextLabel": "Watermark Text",
		"GuidesOpacityLabel": "Opacity",
		"SunAngleLabel": "Sun",
		"AmbientLabel": "Ambient",
		"SunShadowLabel": "Sun Shadows",
		"SunShadowOpacityLabel": "Shadow Opacity",
		"SunSoftnessLabel": "Sun Softness",
		"SunColorLabel": "Sun Color",
		"AmbientColorLabel": "Ambient Color",
		"FogLabel": "Fog",
		"FogColorLabel": "Fog Color",
		"FogDensityLabel": "Fog Density",
		"FogBeginLabel": "Fog Near",
		"FogEndLabel": "Fog Far",
		"FogHeightLabel": "Height Fog",
		"FogHeightDensityLabel": "Height Density",
		"FogHeightFalloffLabel": "Height Falloff",
		"VolumetricFogLabel": "Volumetric Fog",
		"VolumetricDensityLabel": "Vol Density",
		"VolumetricAnisoLabel": "Vol Anisotropy",
		"TempLabel": "Temperature",
		"TintLabel": "Tint",
		"SaturationLabel": "Saturation",
		"ContrastLabel": "Contrast",
		"VignetteLabel": "Vignette",
		"GrainLabel": "Grain",
		"BloomLabel": "Bloom",
		"CompositionCropLabel": "Crop Box",
		"CompositionOffsetXLabel": "Crop X",
		"CompositionOffsetYLabel": "Crop Y",
		"CompositionRollLabel": "Horizon",
		"CompositionSnapLabel": "Thirds Snap",
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
	_setup_postfx_overlay()
	_apply_postfx_settings()


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
	var roots: PackedStringArray = [
		"CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox",
		"CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox",
		"CanvasLayer/PhotoUI/Toolbar/ToolbarHBox",
		"CanvasLayer/PhotoUI/Filmstrip/FilmstripScroll/FilmstripHBox",
		"CanvasLayer/PhotoUI",
	]
	for root_path in roots:
		var root_node: Node = get_node_or_null(root_path)
		var n: Node = _find_exact_descendant(root_node, name, "")
		if n != null and n.get_parent() != new_parent:
			_reparent(n, new_parent)


func _find_exact_descendant(root: Node, node_name: String, type_hint: String) -> Node:
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if String(node.name) == node_name and (type_hint.is_empty() or node.is_class(type_hint)):
			return node
		for child in node.get_children():
			if child is Node:
				stack.push_back(child as Node)
	return null


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


func _setup_postfx_overlay() -> void:
	if _camera == null:
		return

	if _postfx_overlay == null or not is_instance_valid(_postfx_overlay):
		_postfx_overlay = MeshInstance3D.new()
		_postfx_overlay.name = "PostFXOverlay"
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		_postfx_overlay.mesh = quad
		_postfx_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_postfx_overlay.extra_cull_margin = 16384.0
		_camera.add_child(_postfx_overlay)
	elif _postfx_overlay.get_parent() != _camera:
		_reparent(_postfx_overlay, _camera)

	if _postfx_material == null or not is_instance_valid(_postfx_material):
		var shader := load(POSTFX_SHADER_PATH) as Shader
		if shader == null:
			push_warning("PostFX shader missing at %s" % POSTFX_SHADER_PATH)
			return
		_postfx_material = ShaderMaterial.new()
		_postfx_material.shader = shader
		_postfx_material.resource_local_to_scene = true

	_postfx_overlay.material_override = _postfx_material
	_apply_postfx_settings()


func _apply_postfx_settings() -> void:
	if _postfx_toggle:
		_postfx_enabled = _postfx_toggle.button_pressed
	if _postfx_overlay:
		_postfx_overlay.visible = _postfx_enabled
	if _postfx_material == null:
		return

	var fog_enabled := _postfx_fog_toggle.button_pressed if _postfx_fog_toggle else false
	var fog_distance := _postfx_fog_distance_slider.value if _postfx_fog_distance_slider else 120.0
	var fog_fade := _postfx_fog_fade_slider.value if _postfx_fog_fade_slider else 60.0
	fog_distance = maxf(fog_distance, 1.0)
	fog_fade = clampf(fog_fade, 1.0, fog_distance)
	var noise_enabled := _postfx_noise_toggle.button_pressed if _postfx_noise_toggle else false
	var noise_time := _postfx_noise_time_slider.value if _postfx_noise_time_slider else 4.0
	var color_limit_enabled := _postfx_color_limit_toggle.button_pressed if _postfx_color_limit_toggle else true
	var color_levels := int(round(_postfx_color_levels_slider.value if _postfx_color_levels_slider else 32.0))
	var dither_enabled := _postfx_dither_toggle.button_pressed if _postfx_dither_toggle else true
	var dither_strength := _postfx_dither_strength_slider.value if _postfx_dither_strength_slider else 0.35
	var opacity := _postfx_opacity_slider.value if _postfx_opacity_slider else 1.0
	var fog_color := _fog_color_picker.color if _fog_color_picker else Color(0.72, 0.77, 0.83, 1.0)
	var noise_color := Color(
		clampf(fog_color.r * 0.9, 0.0, 1.0),
		clampf(fog_color.g * 0.92, 0.0, 1.0),
		clampf(fog_color.b * 0.95, 0.0, 1.0),
		1.0
	)

	_postfx_material.set_shader_parameter("enable_fog", fog_enabled)
	_postfx_material.set_shader_parameter("fog_color", fog_color)
	_postfx_material.set_shader_parameter("noise_color", noise_color)
	_postfx_material.set_shader_parameter("fog_distance", fog_distance)
	_postfx_material.set_shader_parameter("fog_fade_range", fog_fade)
	_postfx_material.set_shader_parameter("enable_noise", noise_enabled)
	_postfx_material.set_shader_parameter("noise_time_fac", maxf(noise_time, 0.1))
	_postfx_material.set_shader_parameter("enable_color_limitation", color_limit_enabled)
	_postfx_material.set_shader_parameter("color_levels", maxi(color_levels, 2))
	_postfx_material.set_shader_parameter("enable_dithering", dither_enabled)
	_postfx_material.set_shader_parameter("dither_strength", clampf(dither_strength, 0.0, 1.0))
	_postfx_material.set_shader_parameter("effect_opacity", clampf(opacity, 0.0, 1.0))


func _on_postfx_toggled(pressed: bool) -> void:
	_postfx_enabled = pressed
	_apply_postfx_settings()


func _on_postfx_fog_toggled(_pressed: bool) -> void:
	_apply_postfx_settings()


func _on_postfx_fog_distance_changed(value: float) -> void:
	if _postfx_fog_fade_slider:
		_postfx_fog_fade_slider.max_value = maxf(value, 1.0)
		if _postfx_fog_fade_slider.value > _postfx_fog_fade_slider.max_value:
			if _postfx_fog_fade_slider.has_method("set_value_no_signal"):
				_postfx_fog_fade_slider.set_value_no_signal(_postfx_fog_fade_slider.max_value)
			else:
				_postfx_fog_fade_slider.value = _postfx_fog_fade_slider.max_value
	if _postfx_fog_distance_value:
		_postfx_fog_distance_value.text = "%dm" % int(round(value))
	if _postfx_fog_fade_value and _postfx_fog_fade_slider:
		_postfx_fog_fade_value.text = "%dm" % int(round(_postfx_fog_fade_slider.value))
	_apply_postfx_settings()


func _on_postfx_fog_fade_changed(value: float) -> void:
	if _postfx_fog_fade_value:
		_postfx_fog_fade_value.text = "%dm" % int(round(value))
	_apply_postfx_settings()


func _on_postfx_noise_toggled(_pressed: bool) -> void:
	_apply_postfx_settings()


func _on_postfx_noise_time_changed(value: float) -> void:
	if _postfx_noise_time_value:
		_postfx_noise_time_value.text = "%.1f" % value
	_apply_postfx_settings()


func _on_postfx_color_limit_toggled(_pressed: bool) -> void:
	_apply_postfx_settings()


func _on_postfx_color_levels_changed(value: float) -> void:
	if _postfx_color_levels_value:
		_postfx_color_levels_value.text = "%d" % int(round(value))
	_apply_postfx_settings()


func _on_postfx_dither_toggled(_pressed: bool) -> void:
	_apply_postfx_settings()


func _on_postfx_dither_strength_changed(value: float) -> void:
	if _postfx_dither_strength_value:
		_postfx_dither_strength_value.text = "%.2f" % value
	_apply_postfx_settings()


func _on_postfx_opacity_changed(value: float) -> void:
	if _postfx_opacity_value:
		_postfx_opacity_value.text = "%.2f" % value
	_apply_postfx_settings()


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
			if light == _key_light and _sun_color_picker and _sun_color_picker.color != c:
				_sun_color_picker.color = c
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

	# Re-assert PS1 state after map build/setup so the effect shows in Photo Mode.
	_set_ps1_shader_enabled(_is_ps1_shader_enabled())
	_setup_postfx_overlay()
	_apply_postfx_settings()

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
			_sync_camera_angles_from_rotation()
			return
	# Fallback: place near first mesh.
	if _map:
		var meshes := _map.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() > 0:
			var mesh := meshes[0] as MeshInstance3D
			if mesh:
				_camera.global_position = mesh.global_position + Vector3(0, 2.0, 0)
	_sync_camera_angles_from_rotation()


func _apply_pending_debug_camera_override() -> void:
	if _camera == null:
		return
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg == null:
		return
	if not ("pending_photo_camera_valid" in dbg):
		return
	if not bool(dbg.pending_photo_camera_valid):
		return

	if "pending_photo_camera_position" in dbg:
		_camera.global_position = dbg.pending_photo_camera_position as Vector3
	if "pending_photo_camera_rotation" in dbg:
		_camera.rotation_degrees = dbg.pending_photo_camera_rotation as Vector3
	if "pending_photo_camera_fov" in dbg:
		_camera.fov = float(dbg.pending_photo_camera_fov)
		if _fov_slider:
			_fov_slider.value = _camera.fov
	_sync_camera_angles_from_rotation()
	dbg.pending_photo_camera_valid = false



func _sync_camera_angles_from_rotation() -> void:
	if _camera == null:
		return
	_yaw = _camera.rotation_degrees.y
	_pitch = _camera.rotation_degrees.x
	_composition_horizon_roll = _camera.rotation_degrees.z
	if _composition_roll_slider:
		_set_slider_value(_composition_roll_slider, _composition_horizon_roll)
	if _composition_roll_value:
		_composition_roll_value.text = "%.1f°" % _composition_horizon_roll


func _apply_camera_rotation_from_angles() -> void:
	if _camera == null:
		return
	_camera.rotation_degrees = Vector3(_pitch, _yaw, _composition_horizon_roll)


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
				_sync_camera_angles_from_rotation()
				if _status:
					_status.text = "Loaded bookmark %d" % idx
				return

	if _ui_visible:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sens
		_pitch = clamp(_pitch - event.relative.y * mouse_sens, -89.0, 89.0)
		_apply_camera_rotation_from_angles()


func _process(delta: float) -> void:
	# accumulate time for debug throttling
	_debug_accum += delta
	if _auto_focus_enabled:
		_auto_focus_timer -= delta
		if _auto_focus_timer <= 0.0:
			_auto_focus_timer = 0.2
			_update_auto_focus()
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_update_viewfinder()
		_apply_ui_density_tuning()
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
		if _guides_toggle:
			_guides_toggle.button_pressed = _guides.visible


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
	var tab_button_paths := {
		"camera": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabCamera",
		"exposure": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabExposure",
		"guides": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabGuides",
		"capture": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabCapture",
		"passes": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabPasses",
		"light": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabLight",
		"environment": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabEnvironment",
		"color": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabColor",
		"effects": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabEffects",
		"composition": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabComposition",
		"presets": "CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabPresets"
	}
	var export_tab_btn := get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/TabsPanel/TabsMargin/TabsVBox/TabExport") as Button
	if export_tab_btn:
		export_tab_btn.visible = false
		export_tab_btn.disabled = true
	var capture_tab_btn := get_node_or_null(String(tab_button_paths["capture"])) as Button
	if capture_tab_btn:
		capture_tab_btn.text = "Capture + Export"

	_tab_buttons.clear()
	for tab_key in tab_button_paths.keys():
		var btn := get_node_or_null(String(tab_button_paths[tab_key])) as Button
		if btn == null:
			continue
		btn.toggle_mode = true
		var button := btn as BaseButton
		var key := String(tab_key)
		button.toggled.connect(func(on: bool, bk=key, b=button):
			if on:
				_set_active_tab(bk)
			elif _active_tab == bk:
				b.button_pressed = true
		)
		_tab_buttons[key] = btn

	var vbox := get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox") as Node
	_tab_contents.clear()
	if vbox == null:
		push_warning("PhotoMode: missing SettingsScroll/VBox for tab content")
		return

	_tab_contents["camera"] = _nodes(vbox, ["FOVRow", "FocalRow", "ISORow", "ApertureRow", "ShutterRow", "FocusRow", "ShootingModeRow", "AutoFocusRow"])
	_tab_contents["exposure"] = _nodes(vbox, ["ExposureHeaderRow", "ExposureRow", "AutoExposureRow", "AutoExposureSpeedRow", "AutoExposureRangeRow"])
	_tab_contents["guides"] = _nodes(vbox, ["GuidesHeaderRow", "GuidesRow", "GuidesOpacityRow"])
	_tab_contents["capture"] = _nodes(vbox, [
		"CaptureHeaderRow",
		"CaptureFormatRow",
		"CapturePathRow",
		"ResRow",
		"AspectRow",
		"CaptureTimerRow",
		"CaptureBurstRow",
		"CaptureBracketRow",
		"CaptureBracketStepRow",
		"CaptureWatermarkRow",
		"CaptureWatermarkTextRow",
		"ExportHeaderRow",
		"ExportNote",
		"ButtonsRow"
	])
	_tab_contents["passes"] = _nodes(vbox, ["PassesHeaderRow", "PassPreviewRow", "PassesGrid"])
	_tab_contents["light"] = _nodes(vbox, ["LightRigHeaderRow", "LightRigGrid"])
	_tab_contents["environment"] = _nodes(vbox, [
		"EnvironmentHeaderRow",
		"EnvRow",
		"SunAngleRow",
		"AmbientRow",
		"SunShadowRow",
		"SunShadowOpacityRow",
		"SunSoftnessRow",
		"SunColorRow",
		"AmbientColorRow",
		"FogRow",
		"FogColorRow",
		"FogDensityRow",
		"FogBeginRow",
		"FogEndRow",
		"FogHeightRow",
		"FogHeightDensityRow",
		"FogHeightFalloffRow",
		"VolumetricFogRow",
		"VolumetricDensityRow",
		"VolumetricAnisoRow"
	])
	_tab_contents["color"] = _nodes(vbox, ["ColorHeaderRow", "TempRow", "TintRow", "SaturationRow", "ContrastRow"])
	_tab_contents["effects"] = _nodes(vbox, ["EffectsHeaderRow", "VignetteRow", "GrainRow", "BloomRow", "PS1ShaderRow", "PostFXRow", "PostFXFogRow", "PostFXFogDistanceRow", "PostFXFogFadeRow", "PostFXNoiseRow", "PostFXNoiseTimeRow", "PostFXColorLimitRow", "PostFXColorLevelsRow", "PostFXDitherRow", "PostFXDitherStrengthRow", "PostFXOpacityRow"])
	_tab_contents["composition"] = _nodes(vbox, [
		"CompositionHeaderRow",
		"CompositionCropRow",
		"CompositionOffsetXRow",
		"CompositionOffsetYRow",
		"CompositionRollRow",
		"CompositionSnapRow"
	])
	_tab_contents["presets"] = _nodes(vbox, ["PresetsHeaderRow", "PresetsRow", "PresetNameRow", "PresetButtonsRow"])

	call_deferred("_set_active_tab", "camera")


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


func _nodes(root: Node, names: Array[String]) -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	if root == null:
		return out
	for n in names:
		var node := root.get_node_or_null(n)
		if node == null:
			node = root.find_child(n, true, false)
		if node != null and node is CanvasItem:
			out.append(node as CanvasItem)
	return out


func _set_active_tab(tab: String) -> void:
	if tab == null:
		return
	var key := String(tab).to_lower()
	if key == "export":
		key = "capture"
	_active_tab = key
	_current_tab = String(key).capitalize()
	# update buttons
	for tkey in _tab_buttons.keys():
		var b := _tab_buttons[tkey] as Button
		if b:
			b.button_pressed = (tkey == key)

	var vbox := get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox") as Control
	if vbox:
		# Canonical behavior: everything starts hidden, then active-tab + always-visible rows are shown.
		for child in vbox.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false

	var always_nodes: Array = []
	if vbox:
		always_nodes = _nodes(vbox, ["HistogramCard", "Title", "Status"])
	for node in always_nodes:
		if node and node is CanvasItem:
			(node as CanvasItem).visible = true

	# show only active
	var show_arr := _tab_contents.get(key, []) as Array
	for node in show_arr:
		if node and node is CanvasItem:
			(node as CanvasItem).visible = true

	# update title
	var title := get_node_or_null("CanvasLayer/PhotoUI/RootMargin/RootHBox/Panel/Margin/SettingsScroll/VBox/Title") as Label
	if title:
		title.text = String(key).capitalize()

	# ensure viewfinder visibility per active tab
	_set_viewfinder_visible(_always_show_viewport_enabled or key == "capture")
	if _viewfinder_toggle:
		_viewfinder_toggle.button_pressed = (_viewfinder != null and _viewfinder.visible)



func _apply_tab(tab_name: String) -> void:
	# Delegate to new tab system and prevent legacy code from re-showing everything
	_set_active_tab(String(tab_name).to_lower())
	return
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
	var effects := ["EffectsHeaderRow", "VignetteRow", "GrainRow", "BloomRow", "PS1ShaderRow", "PostFXRow", "PostFXFogRow", "PostFXFogDistanceRow", "PostFXFogFadeRow", "PostFXNoiseRow", "PostFXNoiseTimeRow", "PostFXColorLimitRow", "PostFXColorLevelsRow", "PostFXDitherRow", "PostFXDitherStrengthRow", "PostFXOpacityRow"]
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
		"Guides": ["GuidesRow", "GuidesOpacityRow"],
		"Capture": [
			"CaptureHeaderRow",
			"ExportHeaderRow",
			"ExportNote",
			"ResRow",
			"AspectRow",
			"CaptureFormatRow",
			"CapturePathRow",
			"CaptureTimerRow",
			"CaptureBurstRow",
			"CaptureBracketRow",
			"CaptureBracketStepRow",
			"CaptureWatermarkRow",
			"CaptureWatermarkTextRow",
			"ButtonsRow"
		],
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


func _set_check_value(check: CheckBox, pressed: bool) -> void:
	if check == null:
		return
	if check.has_method("set_pressed_no_signal"):
		check.set_pressed_no_signal(pressed)
	else:
		check.button_pressed = pressed


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
		for i in range(_env_options.get_item_count()):
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
	_sync_environment_controls_from_scene()
	_apply_fog_settings()


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


func _sync_environment_controls_from_scene() -> void:
	if _key_light:
		var shadow_enabled := bool(_get_attr_if_exists(_key_light, "shadow_enabled", true))
		if _sun_shadow_toggle:
			_set_check_value(_sun_shadow_toggle, shadow_enabled)

		var shadow_opacity := float(_get_attr_if_exists(_key_light, "shadow_opacity", 1.0))
		if _sun_shadow_opacity_slider:
			_set_slider_value(_sun_shadow_opacity_slider, clampf(shadow_opacity, _sun_shadow_opacity_slider.min_value, _sun_shadow_opacity_slider.max_value))
		if _sun_shadow_opacity_value:
			_sun_shadow_opacity_value.text = "%.2f" % (_sun_shadow_opacity_slider.value if _sun_shadow_opacity_slider else shadow_opacity)

		var softness := float(_get_attr_if_exists(_key_light, "light_angular_distance", 0.0))
		if _sun_softness_slider:
			_set_slider_value(_sun_softness_slider, clampf(softness, _sun_softness_slider.min_value, _sun_softness_slider.max_value))
		if _sun_softness_value:
			_sun_softness_value.text = "%.2f" % (_sun_softness_slider.value if _sun_softness_slider else softness)

		if _sun_color_picker:
			_sun_color_picker.color = _key_light.light_color

	if _world_env and _world_env.environment:
		var env := _world_env.environment
		if _ambient_color_picker:
			_ambient_color_picker.color = _to_color(_get_attr_if_exists(env, "ambient_light_color", _ambient_color_picker.color), _ambient_color_picker.color)
		if _fog_toggle:
			_set_check_value(_fog_toggle, bool(_get_attr_if_exists(env, "fog_enabled", _fog_toggle.button_pressed)))
		if _fog_color_picker:
			_fog_color_picker.color = _to_color(_get_attr_if_exists(env, "fog_light_color", _fog_color_picker.color), _fog_color_picker.color)
		if _fog_density_slider:
			_set_slider_value(_fog_density_slider, clampf(float(_get_attr_if_exists(env, "fog_density", _fog_density_slider.value)), _fog_density_slider.min_value, _fog_density_slider.max_value))
		if _fog_begin_slider:
			_set_slider_value(_fog_begin_slider, clampf(float(_get_attr_if_exists(env, "fog_depth_begin", _fog_begin_slider.value)), _fog_begin_slider.min_value, _fog_begin_slider.max_value))
		if _fog_end_slider:
			_set_slider_value(_fog_end_slider, clampf(float(_get_attr_if_exists(env, "fog_depth_end", _fog_end_slider.value)), _fog_end_slider.min_value, _fog_end_slider.max_value))
		if _fog_height_toggle:
			_set_check_value(_fog_height_toggle, bool(_get_attr_if_exists(env, "fog_height_enabled", _fog_height_toggle.button_pressed)))
		if _fog_height_density_slider:
			_set_slider_value(_fog_height_density_slider, clampf(float(_get_attr_if_exists(env, "fog_height_density", _fog_height_density_slider.value)), _fog_height_density_slider.min_value, _fog_height_density_slider.max_value))
		if _fog_height_falloff_slider:
			_set_slider_value(_fog_height_falloff_slider, clampf(float(_get_attr_if_exists(env, "fog_height_falloff", _fog_height_falloff_slider.value)), _fog_height_falloff_slider.min_value, _fog_height_falloff_slider.max_value))
		if _volumetric_fog_toggle:
			_set_check_value(_volumetric_fog_toggle, bool(_get_attr_if_exists(env, "volumetric_fog_enabled", _volumetric_fog_toggle.button_pressed)))
		if _volumetric_fog_density_slider:
			_set_slider_value(_volumetric_fog_density_slider, clampf(float(_get_attr_if_exists(env, "volumetric_fog_density", _volumetric_fog_density_slider.value)), _volumetric_fog_density_slider.min_value, _volumetric_fog_density_slider.max_value))
		if _volumetric_fog_aniso_slider:
			var aniso: float = float(_get_attr_if_exists(env, "volumetric_fog_anisotropy", _get_attr_if_exists(env, "volumetric_fog_aniso", _volumetric_fog_aniso_slider.value)))
			_set_slider_value(_volumetric_fog_aniso_slider, clampf(float(aniso), _volumetric_fog_aniso_slider.min_value, _volumetric_fog_aniso_slider.max_value))

	if _fog_density_value:
		_fog_density_value.text = "%.3f" % (_fog_density_slider.value if _fog_density_slider else 0.0)
	if _fog_begin_value:
		_fog_begin_value.text = "%dm" % int(round(_fog_begin_slider.value if _fog_begin_slider else 0.0))
	if _fog_end_value:
		_fog_end_value.text = "%dm" % int(round(_fog_end_slider.value if _fog_end_slider else 0.0))
	if _fog_height_density_value:
		_fog_height_density_value.text = "%.3f" % (_fog_height_density_slider.value if _fog_height_density_slider else 0.0)
	if _fog_height_falloff_value:
		_fog_height_falloff_value.text = "%.2f" % (_fog_height_falloff_slider.value if _fog_height_falloff_slider else 0.0)
	if _volumetric_fog_density_value:
		_volumetric_fog_density_value.text = "%.3f" % (_volumetric_fog_density_slider.value if _volumetric_fog_density_slider else 0.0)
	if _volumetric_fog_aniso_value:
		_volumetric_fog_aniso_value.text = "%.2f" % (_volumetric_fog_aniso_slider.value if _volumetric_fog_aniso_slider else 0.0)

	_apply_sun_environment_settings()


func _apply_sun_environment_settings() -> void:
	if _key_light:
		var sun_shadow_enabled := _sun_shadow_toggle.button_pressed if _sun_shadow_toggle else bool(_get_attr_if_exists(_key_light, "shadow_enabled", true))
		_set_attr_if_exists(_key_light, "shadow_enabled", sun_shadow_enabled)
		if _sun_shadow_opacity_slider:
			_set_attr_if_exists(_key_light, "shadow_opacity", _sun_shadow_opacity_slider.value)
		if _sun_softness_slider:
			var softness := _sun_softness_slider.value
			_set_attr_if_exists(_key_light, "light_angular_distance", softness)
			_set_attr_if_exists(_key_light, "directional_shadow_blend_splits", clampf(softness / 6.0, 0.0, 1.0))
		if _sun_color_picker:
			_key_light.light_color = _sun_color_picker.color
			if _key_color and _key_color.color != _sun_color_picker.color:
				_key_color.color = _sun_color_picker.color

	if _world_env and _world_env.environment and _ambient_color_picker:
		_set_attr_if_exists(_world_env.environment, "ambient_light_color", _ambient_color_picker.color)


func _on_sun_shadow_toggled(pressed: bool) -> void:
	if _sun_shadow_toggle:
		_set_check_value(_sun_shadow_toggle, pressed)
	_apply_sun_environment_settings()


func _on_sun_shadow_opacity_changed(value: float) -> void:
	if _sun_shadow_opacity_value:
		_sun_shadow_opacity_value.text = "%.2f" % value
	_apply_sun_environment_settings()


func _on_sun_softness_changed(value: float) -> void:
	if _sun_softness_value:
		_sun_softness_value.text = "%.2f" % value
	_apply_sun_environment_settings()


func _on_sun_color_changed(_color: Color) -> void:
	_apply_sun_environment_settings()


func _on_ambient_color_changed(_color: Color) -> void:
	_apply_sun_environment_settings()


func _on_fog_color_changed(_color: Color) -> void:
	_apply_fog_settings()


func _on_fog_height_toggled(pressed: bool) -> void:
	if _fog_height_toggle:
		_set_check_value(_fog_height_toggle, pressed)
	_apply_fog_settings()


func _on_fog_height_density_changed(value: float) -> void:
	if _fog_height_density_value:
		_fog_height_density_value.text = "%.3f" % value
	_apply_fog_settings()


func _on_fog_height_falloff_changed(value: float) -> void:
	if _fog_height_falloff_value:
		_fog_height_falloff_value.text = "%.2f" % value
	_apply_fog_settings()


func _on_volumetric_fog_toggled(pressed: bool) -> void:
	if _volumetric_fog_toggle:
		_set_check_value(_volumetric_fog_toggle, pressed)
	_apply_fog_settings()


func _on_volumetric_density_changed(value: float) -> void:
	if _volumetric_fog_density_value:
		_volumetric_fog_density_value.text = "%.3f" % value
	_apply_fog_settings()


func _on_volumetric_aniso_changed(value: float) -> void:
	if _volumetric_fog_aniso_value:
		_volumetric_fog_aniso_value.text = "%.2f" % value
	_apply_fog_settings()


func _on_capture_timer_changed(value: float) -> void:
	if _capture_timer_value:
		_capture_timer_value.text = "%ds" % int(round(value))


func _on_capture_bracket_step_changed(value: float) -> void:
	if _capture_bracket_step_value:
		_capture_bracket_step_value.text = "%.1f EV" % value


func _on_capture_watermark_toggled(pressed: bool) -> void:
	if _capture_watermark_text:
		_capture_watermark_text.editable = pressed


func _on_capture_watermark_text_submitted(text: String) -> void:
	if _capture_watermark_text:
		_capture_watermark_text.text = text.strip_edges()


func _on_composition_crop_selected(index: int) -> void:
	if _composition_crop_options == null:
		return
	var meta: Variant = _composition_crop_options.get_item_metadata(index)
	if meta is Dictionary:
		_composition_crop_ratio = float((meta as Dictionary).get("ratio", 0.0))
	else:
		_composition_crop_ratio = 0.0
	_update_viewfinder()


func _on_composition_offset_x_changed(value: float) -> void:
	_composition_crop_offset.x = _snap_composition_offset(value) if _composition_thirds_snap_enabled else value
	if _composition_offset_x_slider and _composition_thirds_snap_enabled:
		_set_slider_value(_composition_offset_x_slider, _composition_crop_offset.x)
	if _composition_offset_x_value:
		_composition_offset_x_value.text = "%.2f" % _composition_crop_offset.x
	_update_viewfinder()


func _on_composition_offset_y_changed(value: float) -> void:
	_composition_crop_offset.y = _snap_composition_offset(value) if _composition_thirds_snap_enabled else value
	if _composition_offset_y_slider and _composition_thirds_snap_enabled:
		_set_slider_value(_composition_offset_y_slider, _composition_crop_offset.y)
	if _composition_offset_y_value:
		_composition_offset_y_value.text = "%.2f" % _composition_crop_offset.y
	_update_viewfinder()


func _on_composition_roll_changed(value: float) -> void:
	_composition_horizon_roll = value
	if _composition_roll_value:
		_composition_roll_value.text = "%.1f°" % value
	_apply_camera_rotation_from_angles()


func _on_composition_snap_toggled(pressed: bool) -> void:
	_composition_thirds_snap_enabled = pressed
	if pressed:
		if _composition_offset_x_slider:
			_on_composition_offset_x_changed(_composition_offset_x_slider.value)
		if _composition_offset_y_slider:
			_on_composition_offset_y_changed(_composition_offset_y_slider.value)


func _snap_composition_offset(value: float) -> float:
	var snapped: float = round(value * 3.0) / 3.0
	return clampf(snapped, -1.0, 1.0)


func _on_fog_toggled(pressed: bool) -> void:
	if _fog_toggle:
		_set_check_value(_fog_toggle, pressed)
	_apply_fog_settings()


func _on_fog_density_changed(value: float) -> void:
	if _fog_density_value:
		_fog_density_value.text = "%.3f" % value
	_apply_fog_settings()


func _on_fog_begin_changed(value: float) -> void:
	if _fog_end_slider and value >= _fog_end_slider.value - 1.0:
		value = _fog_end_slider.value - 1.0
		_set_slider_value(_fog_begin_slider, value)
	if _fog_begin_value:
		_fog_begin_value.text = "%dm" % int(round(value))
	_apply_fog_settings()


func _on_fog_end_changed(value: float) -> void:
	if _fog_begin_slider and value <= _fog_begin_slider.value + 1.0:
		value = _fog_begin_slider.value + 1.0
		_set_slider_value(_fog_end_slider, value)
	if _fog_end_value:
		_fog_end_value.text = "%dm" % int(round(value))
	_apply_fog_settings()


func _apply_fog_settings() -> void:
	if _world_env == null:
		return
	if _world_env.environment == null:
		_world_env.environment = Environment.new()
	var env := _world_env.environment
	if env == null:
		return
	var enabled := _fog_toggle.button_pressed if _fog_toggle else false
	var fog_color := _fog_color_picker.color if _fog_color_picker else Color(0.72, 0.77, 0.83, 1.0)
	var density := _fog_density_slider.value if _fog_density_slider else 0.0
	var begin := _fog_begin_slider.value if _fog_begin_slider else 5.0
	var ending := _fog_end_slider.value if _fog_end_slider else 200.0
	var height_enabled := (_fog_height_toggle.button_pressed if _fog_height_toggle else false) and enabled
	var height_density := _fog_height_density_slider.value if _fog_height_density_slider else 0.05
	var height_falloff := _fog_height_falloff_slider.value if _fog_height_falloff_slider else 0.5
	var volumetric_enabled := (_volumetric_fog_toggle.button_pressed if _volumetric_fog_toggle else enabled) and enabled
	var volumetric_density := _volumetric_fog_density_slider.value if _volumetric_fog_density_slider else density
	var volumetric_aniso := _volumetric_fog_aniso_slider.value if _volumetric_fog_aniso_slider else 0.0
	if ending <= begin:
		ending = begin + 1.0
		if _fog_end_slider:
			_set_slider_value(_fog_end_slider, ending)
		if _fog_end_value:
			_fog_end_value.text = "%dm" % int(round(ending))

	_set_attr_if_exists(env, "fog_enabled", enabled)
	_set_attr_if_exists(env, "fog_light_color", fog_color)
	_set_attr_if_exists(env, "fog_light_energy", 1.0)
	_set_attr_if_exists(env, "fog_density", density)
	_set_attr_if_exists(env, "fog_depth_enabled", enabled)
	_set_attr_if_exists(env, "fog_depth_begin", begin)
	_set_attr_if_exists(env, "fog_depth_end", ending)
	_set_attr_if_exists(env, "fog_depth_curve", clampf(1.0 + density * 4.0, 1.0, 4.0))

	_set_attr_if_exists(env, "fog_height_enabled", height_enabled)
	_set_attr_if_exists(env, "fog_height_density", height_density)
	_set_attr_if_exists(env, "fog_height_falloff", height_falloff)
	_set_attr_if_exists(env, "fog_height_curve", clampf(height_falloff, 0.05, 8.0))
	_set_attr_if_exists(env, "fog_height", height_density * 100.0)
	_set_attr_if_exists(env, "fog_height_min", -64.0 / maxf(height_falloff, 0.05))
	_set_attr_if_exists(env, "fog_height_max", 64.0 / maxf(height_falloff, 0.05))

	_set_attr_if_exists(env, "volumetric_fog_enabled", volumetric_enabled)
	_set_attr_if_exists(env, "volumetric_fog_density", volumetric_density)
	_set_attr_if_exists(env, "volumetric_fog_albedo", fog_color)
	_set_attr_if_exists(env, "volumetric_fog_anisotropy", volumetric_aniso)
	_set_attr_if_exists(env, "volumetric_fog_aniso", volumetric_aniso)
	_set_attr_if_exists(env, "volumetric_fog_length", ending)
	_set_attr_if_exists(env, "volumetric_fog_sky_affect", 1.0)


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

	var env = _world_env.environment
	# Ensure the environment is really an Environment resource (defensive for engine versions)
	if not (env is Environment):
		if _is_layout_debug_enabled():
			if _debug_accum >= DEBUG_PRINT_INTERVAL:
				print("[PhotoMode DEBUG] _apply_color_adjustments: world_env=", _world_env, " env_type=", typeof(env), " env=", env)
				_debug_accum = 0.0
		return

	if _is_layout_debug_enabled():
		if _debug_accum >= DEBUG_PRINT_INTERVAL:
			print("[PhotoMode DEBUG] _apply_color_adjustments: world_env=", _world_env, " env=", env)
			var props := []
			for p in env.get_property_list():
				props.append(p.name)
			print("[PhotoMode DEBUG] environment properties sample=", props.slice(0, 30))
			_debug_accum = 0.0
	_set_attr_if_exists(env, "adjustment_enabled", true)
	if _saturation_slider:
		_set_attr_if_exists(env, "adjustment_saturation", _saturation_slider.value)
	if _contrast_slider:
		_set_attr_if_exists(env, "adjustment_contrast", _contrast_slider.value)

	var temp := _temp_slider.value if _temp_slider else 0.0
	var tint := _tint_slider.value if _tint_slider else 0.0
	var warm := temp * 0.15
	var green := tint * 0.1
	var color := Color(1.0 + warm, 1.0 + green, 1.0 - warm, 1.0)
	color.r = clampf(color.r, 0.6, 1.4)
	color.g = clampf(color.g, 0.6, 1.4)
	color.b = clampf(color.b, 0.6, 1.4)
	# Primary: set environment adjustment color
	_set_attr_if_exists(env, "adjustment_color", color)
	# Fallbacks: some engine versions expose different property names
	_set_attr_if_exists(env, "adjustment_color_correction", color)


func _on_vignette_changed(value: float) -> void:
	if _vignette_value:
		_vignette_value.text = "%.2f" % value
	if _world_env and _world_env.environment:
		if _is_layout_debug_enabled():
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
		if _is_layout_debug_enabled():
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


func _get_game_singleton() -> Node:
	return get_node_or_null("/root/GAME")


func _is_ps1_shader_enabled() -> bool:
	var game := _get_game_singleton()
	if game == null:
		return false
	if game.has_method("is_ps1_shader_enabled"):
		return bool(game.call("is_ps1_shader_enabled"))
	if "enable_ps1_geometry_shader" in game:
		return bool(game.enable_ps1_geometry_shader)
	return false


func _set_ps1_shader_enabled(enabled: bool) -> void:
	var game := _get_game_singleton()
	if game == null:
		return
	if game.has_method("set_ps1_shader_enabled"):
		game.call("set_ps1_shader_enabled", enabled)
	elif "enable_ps1_geometry_shader" in game:
		game.enable_ps1_geometry_shader = enabled


func _on_ps1_shader_toggled(pressed: bool) -> void:
	_set_ps1_shader_enabled(pressed)
	if _status:
		_status.text = "PS1 Shader %s" % ("On" if pressed else "Off")


func _on_guides_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_guides_enabled"):
		_guides.call("set_guides_enabled", pressed)
	if _guides_toggle:
		_guides_toggle.button_pressed = pressed


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
		"sun_shadows": _sun_shadow_toggle.button_pressed if _sun_shadow_toggle else true,
		"sun_shadow_opacity": _sun_shadow_opacity_slider.value if _sun_shadow_opacity_slider else 1.0,
		"sun_softness": _sun_softness_slider.value if _sun_softness_slider else 0.0,
		"sun_color": _sun_color_picker.color if _sun_color_picker else (_key_light.light_color if _key_light else Color(1.0, 0.98, 0.92)),
		"ambient_color": _ambient_color_picker.color if _ambient_color_picker else (_world_env.environment.ambient_light_color if _world_env and _world_env.environment else Color(0.6, 0.65, 0.7)),
		"fog_enabled": _fog_toggle.button_pressed if _fog_toggle else false,
		"fog_color": _fog_color_picker.color if _fog_color_picker else Color(0.72, 0.77, 0.83),
		"fog_density": _fog_density_slider.value if _fog_density_slider else 0.0,
		"fog_begin": _fog_begin_slider.value if _fog_begin_slider else 5.0,
		"fog_end": _fog_end_slider.value if _fog_end_slider else 200.0,
		"fog_height_enabled": _fog_height_toggle.button_pressed if _fog_height_toggle else false,
		"fog_height_density": _fog_height_density_slider.value if _fog_height_density_slider else 0.05,
		"fog_height_falloff": _fog_height_falloff_slider.value if _fog_height_falloff_slider else 0.5,
		"volumetric_enabled": _volumetric_fog_toggle.button_pressed if _volumetric_fog_toggle else false,
		"volumetric_density": _volumetric_fog_density_slider.value if _volumetric_fog_density_slider else 0.03,
		"volumetric_aniso": _volumetric_fog_aniso_slider.value if _volumetric_fog_aniso_slider else 0.0,
		"temp": _temp_slider.value if _temp_slider else 0.0,
		"tint": _tint_slider.value if _tint_slider else 0.0,
		"saturation": _saturation_slider.value if _saturation_slider else 1.0,
		"contrast": _contrast_slider.value if _contrast_slider else 1.0,
		"vignette": _vignette_slider.value if _vignette_slider else 0.0,
		"grain": _grain_slider.value if _grain_slider else 0.0,
		"bloom": _bloom_slider.value if _bloom_slider else 0.0,
		"ps1_shader": _ps1_shader_toggle.button_pressed if _ps1_shader_toggle else _is_ps1_shader_enabled(),
		"postfx_enabled": _postfx_toggle.button_pressed if _postfx_toggle else _postfx_enabled,
		"postfx_fog": _postfx_fog_toggle.button_pressed if _postfx_fog_toggle else false,
		"postfx_fog_distance": _postfx_fog_distance_slider.value if _postfx_fog_distance_slider else 120.0,
		"postfx_fog_fade": _postfx_fog_fade_slider.value if _postfx_fog_fade_slider else 60.0,
		"postfx_noise": _postfx_noise_toggle.button_pressed if _postfx_noise_toggle else false,
		"postfx_noise_time": _postfx_noise_time_slider.value if _postfx_noise_time_slider else 4.0,
		"postfx_color_limit": _postfx_color_limit_toggle.button_pressed if _postfx_color_limit_toggle else true,
		"postfx_color_levels": _postfx_color_levels_slider.value if _postfx_color_levels_slider else 32.0,
		"postfx_dither": _postfx_dither_toggle.button_pressed if _postfx_dither_toggle else true,
		"postfx_dither_strength": _postfx_dither_strength_slider.value if _postfx_dither_strength_slider else 0.35,
		"postfx_opacity": _postfx_opacity_slider.value if _postfx_opacity_slider else 1.0,
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
		for i in range(_env_options.get_item_count()):
			if _env_options.get_item_text(i) == name:
				_env_options.select(i)
				_on_environment_selected(i)
				break
	if _sun_angle_slider:
		_sun_angle_slider.value = float(preset.get("sun_angle", _sun_angle_slider.value))
	if _ambient_slider:
		_ambient_slider.value = float(preset.get("ambient", _ambient_slider.value))
	if _sun_shadow_toggle:
		_set_check_value(_sun_shadow_toggle, bool(preset.get("sun_shadows", _sun_shadow_toggle.button_pressed)))
	if _sun_shadow_opacity_slider:
		_sun_shadow_opacity_slider.value = float(preset.get("sun_shadow_opacity", _sun_shadow_opacity_slider.value))
	if _sun_softness_slider:
		_sun_softness_slider.value = float(preset.get("sun_softness", _sun_softness_slider.value))
	if _sun_color_picker:
		_sun_color_picker.color = _to_color(preset.get("sun_color", _sun_color_picker.color), _sun_color_picker.color)
	if _ambient_color_picker:
		_ambient_color_picker.color = _to_color(preset.get("ambient_color", _ambient_color_picker.color), _ambient_color_picker.color)
	if _fog_toggle:
		_set_check_value(_fog_toggle, bool(preset.get("fog_enabled", _fog_toggle.button_pressed)))
	if _fog_color_picker:
		_fog_color_picker.color = _to_color(preset.get("fog_color", _fog_color_picker.color), _fog_color_picker.color)
	if _fog_density_slider:
		_fog_density_slider.value = float(preset.get("fog_density", _fog_density_slider.value))
	if _fog_begin_slider:
		_fog_begin_slider.value = float(preset.get("fog_begin", _fog_begin_slider.value))
	if _fog_end_slider:
		_fog_end_slider.value = float(preset.get("fog_end", _fog_end_slider.value))
	if _fog_height_toggle:
		_set_check_value(_fog_height_toggle, bool(preset.get("fog_height_enabled", _fog_height_toggle.button_pressed)))
	if _fog_height_density_slider:
		_fog_height_density_slider.value = float(preset.get("fog_height_density", _fog_height_density_slider.value))
	if _fog_height_falloff_slider:
		_fog_height_falloff_slider.value = float(preset.get("fog_height_falloff", _fog_height_falloff_slider.value))
	if _volumetric_fog_toggle:
		_set_check_value(_volumetric_fog_toggle, bool(preset.get("volumetric_enabled", _volumetric_fog_toggle.button_pressed)))
	if _volumetric_fog_density_slider:
		_volumetric_fog_density_slider.value = float(preset.get("volumetric_density", _volumetric_fog_density_slider.value))
	if _volumetric_fog_aniso_slider:
		_volumetric_fog_aniso_slider.value = float(preset.get("volumetric_aniso", _volumetric_fog_aniso_slider.value))
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
	if preset.has("ps1_shader"):
		var ps1_enabled := bool(preset.get("ps1_shader", _is_ps1_shader_enabled()))
		if _ps1_shader_toggle:
			_set_check_value(_ps1_shader_toggle, ps1_enabled)
		_set_ps1_shader_enabled(ps1_enabled)
	if _postfx_toggle:
		_set_check_value(_postfx_toggle, bool(preset.get("postfx_enabled", _postfx_toggle.button_pressed)))
	if _postfx_fog_toggle:
		_set_check_value(_postfx_fog_toggle, bool(preset.get("postfx_fog", _postfx_fog_toggle.button_pressed)))
	if _postfx_fog_distance_slider:
		_postfx_fog_distance_slider.value = float(preset.get("postfx_fog_distance", _postfx_fog_distance_slider.value))
	if _postfx_fog_fade_slider:
		_postfx_fog_fade_slider.value = float(preset.get("postfx_fog_fade", _postfx_fog_fade_slider.value))
	if _postfx_noise_toggle:
		_set_check_value(_postfx_noise_toggle, bool(preset.get("postfx_noise", _postfx_noise_toggle.button_pressed)))
	if _postfx_noise_time_slider:
		_postfx_noise_time_slider.value = float(preset.get("postfx_noise_time", _postfx_noise_time_slider.value))
	if _postfx_color_limit_toggle:
		_set_check_value(_postfx_color_limit_toggle, bool(preset.get("postfx_color_limit", _postfx_color_limit_toggle.button_pressed)))
	if _postfx_color_levels_slider:
		_postfx_color_levels_slider.value = float(preset.get("postfx_color_levels", _postfx_color_levels_slider.value))
	if _postfx_dither_toggle:
		_set_check_value(_postfx_dither_toggle, bool(preset.get("postfx_dither", _postfx_dither_toggle.button_pressed)))
	if _postfx_dither_strength_slider:
		_postfx_dither_strength_slider.value = float(preset.get("postfx_dither_strength", _postfx_dither_strength_slider.value))
	if _postfx_opacity_slider:
		_postfx_opacity_slider.value = float(preset.get("postfx_opacity", _postfx_opacity_slider.value))
	_apply_postfx_settings()
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
		var kc: Color = _to_color(preset.get("key_color", _key_color.color), _key_color.color)
		_key_color.color = kc
	if _key_intensity:
		_key_intensity.value = float(preset.get("key_intensity", _key_intensity.value))
	if _fill_enabled:
		_fill_enabled.button_pressed = bool(preset.get("fill_enabled", true))
	if _fill_color:
		var fc: Color = _to_color(preset.get("fill_color", _fill_color.color), _fill_color.color)
		_fill_color.color = fc
	if _fill_intensity:
		_fill_intensity.value = float(preset.get("fill_intensity", _fill_intensity.value))
	if _rim_enabled:
		_rim_enabled.button_pressed = bool(preset.get("rim_enabled", true))
	if _rim_color:
		var rc: Color = _to_color(preset.get("rim_color", _rim_color.color), _rim_color.color)
		_rim_color.color = rc
	if _rim_intensity:
		_rim_intensity.value = float(preset.get("rim_intensity", _rim_intensity.value))
	if _top_enabled:
		_top_enabled.button_pressed = bool(preset.get("top_enabled", true))
	if _top_color:
		var tc: Color = _to_color(preset.get("top_color", _top_color.color), _top_color.color)
		_top_color.color = tc
	if _top_intensity:
		_top_intensity.value = float(preset.get("top_intensity", _top_intensity.value))
	if _bounce_enabled:
		_bounce_enabled.button_pressed = bool(preset.get("bounce_enabled", true))
	if _bounce_color:
		var bc: Color = _to_color(preset.get("bounce_color", _bounce_color.color), _bounce_color.color)
		_bounce_color.color = bc
	if _bounce_intensity:
		_bounce_intensity.value = float(preset.get("bounce_intensity", _bounce_intensity.value))
	_apply_sun_environment_settings()
	_apply_fog_settings()


func _get_selected_aspect_ratio(base_size: Vector2) -> float:
	if _composition_crop_ratio > 0.01:
		return _composition_crop_ratio
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
		var max_y := maxf(base_size.y - height, 0.0)
		var center_y := max_y * 0.5
		var y := clampf(center_y + (_composition_crop_offset.y * center_y), 0.0, max_y)
		return Rect2(Vector2(0.0, y), Vector2(base_size.x, height))
	else:
		var width := base_size.y * target_ratio
		var max_x := maxf(base_size.x - width, 0.0)
		var center_x := max_x * 0.5
		var x := clampf(center_x + (_composition_crop_offset.x * center_x), 0.0, max_x)
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
	# Re-assert anchors/size for the viewfinder Control (defensive - fixes cases
	# where parent/anchor changes prevent it from resizing with the viewport).
	if _viewfinder is Control:
		_viewfinder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_viewfinder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# if the control's size doesn't match the viewport, nudge its minimum size
		# so Godot's layout will allocate the correct rect and allow _draw to run.
		if _viewfinder.size.distance_to(base_size) > 1.0:
			_viewfinder.custom_minimum_size = base_size

	var crop_rect := _calculate_crop_rect(base_size)
	if _is_layout_debug_enabled():
		print("[PhotoMode DEBUG] _update_viewfinder: viewport=", base_size, " viewfinder_size=", (_viewfinder.size if _viewfinder is Control else Vector2.ZERO))
	if _viewfinder.has_method("set_crop_rect"):
		_viewfinder.call("set_crop_rect", crop_rect)


func _set_viewfinder_visible(visible: bool) -> void:
	if _viewfinder == null:
		return
	if _viewfinder.has_method("set_enabled"):
		_viewfinder.call("set_enabled", visible)
	else:
		_viewfinder.visible = visible
	if _viewfinder_toggle:
		_viewfinder_toggle.button_pressed = visible


func _is_layout_debug_enabled() -> bool:
	if not enable_layout_debug_print:
		return false
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("is_runtime_debug_enabled"):
		return bool(dbg.call("is_runtime_debug_enabled"))
	return false


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard shortcuts: Space = capture, V = toggle viewfinder, G = toggle guides
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = int(event.keycode)
		if kc == KEY_SPACE:
			# Trigger capture
			if has_method("_on_capture_pressed"):
				_on_capture_pressed()
				get_viewport().set_input_as_handled()
		elif kc == KEY_V:
			# Toggle viewfinder visibility
			if _viewfinder != null:
				_set_viewfinder_visible(not (_viewfinder.visible))
				get_viewport().set_input_as_handled()
		elif kc == KEY_G:
			# Toggle composition guides
			_toggle_guides()
			get_viewport().set_input_as_handled()


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
	var target: HBoxContainer = _filmstrip_hbox if _filmstrip_hbox != null else _contact_strip
	if capture == null or target == null:
		return
	target.add_theme_constant_override("separation", 8)
	# Create thumbnail button
	var thumb_btn := Button.new()
	thumb_btn.name = "Thumb_%d" % target.get_child_count()
	thumb_btn.custom_minimum_size = Vector2(160, 88)
	thumb_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	thumb_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	thumb_btn.focus_mode = Control.FOCUS_NONE
	thumb_btn.clip_contents = true
	var tex: Texture = capture.get("thumb", null) as Texture
	if tex != null and tex is Texture:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 0.0
		tr.offset_top = 0.0
		tr.offset_right = 0.0
		tr.offset_bottom = 0.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb_btn.add_child(tr)
	else:
		thumb_btn.text = "Img"
	# store metadata and make toggleable
	thumb_btn.set_meta("capture", capture)
	thumb_btn.toggle_mode = true
	thumb_btn.tooltip_text = "Left click: Preview\nRight click: Options"
	var idx := _session_captures.size() - 1
	thumb_btn.set_meta("capture_index", idx)
	# left-click opens preview
	thumb_btn.pressed.connect(func():
		var i := int(thumb_btn.get_meta("capture_index", -1))
		if i < 0 or i >= _session_captures.size():
			return
		_select_capture(i)
		_open_capture_preview(_session_captures[i] as Dictionary)
	)
	# right-click opens popup menu
	thumb_btn.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_menu_target_capture_index = int(thumb_btn.get_meta("capture_index", -1))
			if _thumb_menu:
				var mouse_pos := Vector2i(get_viewport().get_mouse_position())
				_thumb_menu.position = mouse_pos
				_thumb_menu.reset_size()
				_thumb_menu.popup()
		)
	target.add_child(thumb_btn)


func _load_capture_texture(capture: Dictionary) -> Texture2D:
	if capture == null:
		return null
	var capture_path := String(capture.get("path", ""))
	if capture_path != "" and FileAccess.file_exists(capture_path):
		var full_img := Image.new()
		var err := full_img.load(capture_path)
		if err == OK:
			return ImageTexture.create_from_image(full_img)
	var thumb_tex: Variant = capture.get("thumb", null)
	if thumb_tex is Texture2D:
		return thumb_tex as Texture2D
	return null


func _update_preview_display() -> void:
	if _preview_image_node == null:
		return
	var tex := _preview_compare_texture if _preview_show_compare else _preview_primary_texture
	_preview_image_node.texture = tex
	if tex:
		_preview_image_size = tex.get_size()
	else:
		_preview_image_size = Vector2.ZERO
	_preview_zoom = clampf(_preview_zoom, 0.1, 8.0)
	var target_size := _preview_image_size * _preview_zoom
	if target_size.x > 1.0 and target_size.y > 1.0:
		_preview_image_node.custom_minimum_size = target_size
	else:
		_preview_image_node.custom_minimum_size = Vector2.ZERO


func _set_preview_zoom(value: float) -> void:
	_preview_zoom = clampf(value, 0.1, 8.0)
	_update_preview_display()


func _fit_preview_zoom() -> void:
	if _preview_scroll == null:
		return
	var tex := _preview_compare_texture if _preview_show_compare else _preview_primary_texture
	if tex == null:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 1.0 or tex_size.y <= 1.0:
		return
	var view_size := _preview_scroll.size - Vector2(12.0, 12.0)
	if view_size.x <= 1.0 or view_size.y <= 1.0:
		return
	var fit := minf(view_size.x / tex_size.x, view_size.y / tex_size.y)
	_set_preview_zoom(maxf(0.1, fit))


func _on_preview_zoom_in_pressed() -> void:
	_set_preview_zoom(_preview_zoom * 1.25)


func _on_preview_zoom_out_pressed() -> void:
	_set_preview_zoom(_preview_zoom / 1.25)


func _on_preview_zoom_fit_pressed() -> void:
	_fit_preview_zoom()


func _on_preview_compare_toggled(pressed: bool) -> void:
	if _preview_compare_texture == null:
		_preview_show_compare = false
	else:
		_preview_show_compare = pressed
	_update_preview_display()


func _on_preview_reapply_pressed() -> void:
	if _preview_capture_index >= 0:
		_reapply_capture(_preview_capture_index)


func _on_preview_show_in_finder_pressed() -> void:
	_reveal_in_finder(_preview_capture)


func _on_preview_delete_pressed() -> void:
	if _preview_capture_index < 0:
		return
	_delete_capture(_preview_capture_index, true)
	if _capture_preview_panel:
		_capture_preview_panel.hide()


func _open_capture_preview(capture: Dictionary) -> void:
	if capture == null:
		return
	_ensure_capture_preview_panel()
	if _capture_preview_panel == null:
		return
	_preview_capture = capture
	_preview_capture_index = _selected_capture_idx
	if _preview_capture_index < 0:
		_preview_capture_index = _session_captures.find(capture)
	_preview_primary_texture = _load_capture_texture(capture)
	_preview_compare_capture = {}
	_preview_compare_texture = null
	if _preview_capture_index > 0 and _preview_capture_index - 1 < _session_captures.size():
		_preview_compare_capture = _session_captures[_preview_capture_index - 1] as Dictionary
		_preview_compare_texture = _load_capture_texture(_preview_compare_capture)
	elif _preview_capture_index == 0 and _session_captures.size() > 1:
		_preview_compare_capture = _session_captures[1] as Dictionary
		_preview_compare_texture = _load_capture_texture(_preview_compare_capture)
	_preview_show_compare = false
	var compare_toggle := _capture_preview_panel.get_node_or_null("PreviewRoot/PreviewToolbar/PreviewCompare") as CheckBox
	if compare_toggle:
		if compare_toggle.has_method("set_pressed_no_signal"):
			compare_toggle.set_pressed_no_signal(false)
		else:
			compare_toggle.button_pressed = false
		compare_toggle.disabled = (_preview_compare_texture == null)
	_update_preview_display()
	var viewport_size := get_viewport().get_visible_rect().size
	var desired_size := Vector2i(
		maxi(760, int(viewport_size.x * 0.86)),
		maxi(520, int(viewport_size.y * 0.84))
	)
	_capture_preview_panel.size = desired_size
	var panel_size := _capture_preview_panel.size
	if panel_size.x <= 0 or panel_size.y <= 0:
		panel_size = _capture_preview_panel.min_size
	_capture_preview_panel.position = Vector2i(
		maxi(0, int((viewport_size.x - float(panel_size.x)) * 0.5)),
		maxi(0, int((viewport_size.y - float(panel_size.y)) * 0.5))
	)
	_capture_preview_panel.popup()
	call_deferred("_fit_preview_zoom")


func _on_preview_restore_pressed() -> void:
	if _preview_capture.has("camera") and _camera:
		var cam := _preview_capture["camera"] as Dictionary
		if cam.has("position"):
			_camera.global_position = cam["position"] as Vector3
		if cam.has("rotation"):
			_camera.rotation_degrees = cam["rotation"] as Vector3
		_sync_camera_angles_from_rotation()
	if _capture_preview_panel:
		_capture_preview_panel.hide()


func _on_thumb_menu_id_pressed(id: int) -> void:
	var idx := _menu_target_capture_index
	if idx < 0 or idx >= _session_captures.size():
		return
	var capture: Dictionary = _session_captures[idx] as Dictionary
	match id:
		THUMB_MENU_PREVIEW:
			_select_capture(idx)
			_open_capture_preview(capture)
		THUMB_MENU_REAPPLY:
			_reapply_capture(idx)
		THUMB_MENU_SHOW_IN_FINDER:
			_reveal_in_finder(capture)
		THUMB_MENU_EXPORT:
			# Export
			_thumb_export_target_index = idx
			if _thumb_export_dialog:
				_thumb_export_dialog.popup_centered_ratio(0.5)
		THUMB_MENU_DELETE:
			_delete_capture(idx, true)
		_:
			pass


func _select_capture(idx: int) -> void:
	if idx < 0 or idx >= _session_captures.size():
		return
	_selected_capture_idx = idx
	var target: HBoxContainer = _filmstrip_hbox if _filmstrip_hbox != null else _contact_strip
	if target:
		for i in range(target.get_child_count()):
			var b = target.get_child(i)
			if b is Button:
				var capture_idx := int((b as Button).get_meta("capture_index", -1))
				(b as Button).button_pressed = (capture_idx == idx)
	# Restore camera if available
	var cap: Dictionary = _session_captures[idx] as Dictionary
	if cap and cap.has("camera") and _camera:
		var cam: Dictionary = cap["camera"] as Dictionary
		if cam.has("position"):
			_camera.global_position = cam["position"] as Vector3
		if cam.has("rotation"):
			_camera.rotation_degrees = cam["rotation"] as Vector3
		_sync_camera_angles_from_rotation()


func _delete_file_if_exists(path: String) -> void:
	if path == "":
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _delete_capture(idx: int, delete_files: bool) -> void:
	if idx < 0 or idx >= _session_captures.size():
		return
	var deleting_preview := (_preview_capture_index == idx)
	var cap := _session_captures[idx] as Dictionary
	if delete_files:
		_delete_file_if_exists(String(cap.get("path", "")))
		_delete_file_if_exists(String(cap.get("metadata_path", "")))
	_session_captures.remove_at(idx)
	var target: HBoxContainer = _filmstrip_hbox if _filmstrip_hbox != null else _contact_strip
	if target:
		for child in target.get_children():
			if child is Button:
				var btn := child as Button
				var child_idx := int(btn.get_meta("capture_index", -1))
				if child_idx == idx:
					btn.queue_free()
				elif child_idx > idx:
					btn.set_meta("capture_index", child_idx - 1)
	if _selected_capture_idx == idx:
		_selected_capture_idx = -1
	elif _selected_capture_idx > idx:
		_selected_capture_idx -= 1
	if _preview_capture_index == idx:
		_preview_capture_index = -1
	elif _preview_capture_index > idx:
		_preview_capture_index -= 1
	if deleting_preview and _capture_preview_panel and _capture_preview_panel.visible:
		_capture_preview_panel.hide()
	if _status:
		_status.text = "Deleted capture"


func _load_capture_metadata(capture: Dictionary) -> Dictionary:
	if capture == null:
		return {}
	if capture.has("metadata") and capture["metadata"] is Dictionary:
		return capture["metadata"] as Dictionary
	var metadata_path := String(capture.get("metadata_path", ""))
	if metadata_path == "" or not FileAccess.file_exists(metadata_path):
		return {}
	var file := FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _set_option_by_text(option: OptionButton, text: String) -> bool:
	if option == null:
		return false
	for i in range(option.get_item_count()):
		if option.get_item_text(i) == text:
			option.select(i)
			return true
	return false


func _apply_capture_metadata(meta: Dictionary) -> void:
	if meta == null or meta.is_empty():
		return
	if meta.has("camera") and meta["camera"] is Dictionary:
		var cam := meta["camera"] as Dictionary
		if cam.has("position") and _camera:
			_camera.global_position = _parse_vector3(cam["position"])
		if cam.has("rotation") and _camera:
			_camera.rotation_degrees = _parse_vector3(cam["rotation"])
			_sync_camera_angles_from_rotation()
		if cam.has("fov") and _fov_slider:
			_fov_slider.value = float(cam["fov"])
		if cam.has("iso") and _iso_slider:
			_iso_slider.value = float(cam["iso"])
		if cam.has("aperture") and _aperture_slider:
			_aperture_slider.value = float(cam["aperture"])
		if cam.has("shutter") and _shutter_slider:
			_shutter_slider.value = float(cam["shutter"])
		if cam.has("focus_distance") and _focus_slider:
			_focus_slider.value = float(cam["focus_distance"])
	if meta.has("exposure") and meta["exposure"] is Dictionary:
		var exposure := meta["exposure"] as Dictionary
		if exposure.has("base") and _exposure_slider:
			_exposure_slider.value = float(exposure["base"])
	if meta.has("environment") and meta["environment"] is Dictionary:
		var env := meta["environment"] as Dictionary
		if env.has("preset") and _env_options:
			var label := String(env["preset"])
			if _set_option_by_text(_env_options, label):
				_on_environment_selected(_env_options.selected)
		if env.has("sun_shadows") and _sun_shadow_toggle:
			_set_check_value(_sun_shadow_toggle, bool(env["sun_shadows"]))
		if env.has("sun_shadow_opacity") and _sun_shadow_opacity_slider:
			_sun_shadow_opacity_slider.value = float(env["sun_shadow_opacity"])
		if env.has("sun_softness") and _sun_softness_slider:
			_sun_softness_slider.value = float(env["sun_softness"])
		if env.has("sun_color") and _sun_color_picker:
			_sun_color_picker.color = _to_color(env["sun_color"], _sun_color_picker.color)
		if env.has("ambient_color") and _ambient_color_picker:
			_ambient_color_picker.color = _to_color(env["ambient_color"], _ambient_color_picker.color)
		if env.has("fog_enabled") and _fog_toggle:
			_set_check_value(_fog_toggle, bool(env["fog_enabled"]))
		if env.has("fog_color") and _fog_color_picker:
			_fog_color_picker.color = _to_color(env["fog_color"], _fog_color_picker.color)
		if env.has("fog_density") and _fog_density_slider:
			_fog_density_slider.value = float(env["fog_density"])
		if env.has("fog_begin") and _fog_begin_slider:
			_fog_begin_slider.value = float(env["fog_begin"])
		if env.has("fog_end") and _fog_end_slider:
			_fog_end_slider.value = float(env["fog_end"])
		if env.has("fog_height_enabled") and _fog_height_toggle:
			_set_check_value(_fog_height_toggle, bool(env["fog_height_enabled"]))
		if env.has("fog_height_density") and _fog_height_density_slider:
			_fog_height_density_slider.value = float(env["fog_height_density"])
		if env.has("fog_height_falloff") and _fog_height_falloff_slider:
			_fog_height_falloff_slider.value = float(env["fog_height_falloff"])
		if env.has("volumetric_enabled") and _volumetric_fog_toggle:
			_set_check_value(_volumetric_fog_toggle, bool(env["volumetric_enabled"]))
		if env.has("volumetric_density") and _volumetric_fog_density_slider:
			_volumetric_fog_density_slider.value = float(env["volumetric_density"])
		if env.has("volumetric_aniso") and _volumetric_fog_aniso_slider:
			_volumetric_fog_aniso_slider.value = float(env["volumetric_aniso"])
		_apply_sun_environment_settings()
		_apply_fog_settings()
	if meta.has("color") and meta["color"] is Dictionary:
		var color := meta["color"] as Dictionary
		if color.has("temp") and _temp_slider:
			_temp_slider.value = float(color["temp"])
		if color.has("tint") and _tint_slider:
			_tint_slider.value = float(color["tint"])
		if color.has("saturation") and _saturation_slider:
			_saturation_slider.value = float(color["saturation"])
		if color.has("contrast") and _contrast_slider:
			_contrast_slider.value = float(color["contrast"])
	if meta.has("effects") and meta["effects"] is Dictionary:
		var fx := meta["effects"] as Dictionary
		if fx.has("vignette") and _vignette_slider:
			_vignette_slider.value = float(fx["vignette"])
		if fx.has("grain") and _grain_slider:
			_grain_slider.value = float(fx["grain"])
		if fx.has("bloom") and _bloom_slider:
			_bloom_slider.value = float(fx["bloom"])
		if fx.has("ps1_enabled"):
			var ps1_enabled := bool(fx["ps1_enabled"])
			if _ps1_shader_toggle:
				_set_check_value(_ps1_shader_toggle, ps1_enabled)
			_set_ps1_shader_enabled(ps1_enabled)
		if fx.has("postfx_enabled") and _postfx_toggle:
			_set_check_value(_postfx_toggle, bool(fx["postfx_enabled"]))
		if fx.has("postfx_fog") and _postfx_fog_toggle:
			_set_check_value(_postfx_fog_toggle, bool(fx["postfx_fog"]))
		if fx.has("postfx_fog_distance") and _postfx_fog_distance_slider:
			_postfx_fog_distance_slider.value = float(fx["postfx_fog_distance"])
		if fx.has("postfx_fog_fade") and _postfx_fog_fade_slider:
			_postfx_fog_fade_slider.value = float(fx["postfx_fog_fade"])
		if fx.has("postfx_noise") and _postfx_noise_toggle:
			_set_check_value(_postfx_noise_toggle, bool(fx["postfx_noise"]))
		if fx.has("postfx_noise_time") and _postfx_noise_time_slider:
			_postfx_noise_time_slider.value = float(fx["postfx_noise_time"])
		if fx.has("postfx_color_limit") and _postfx_color_limit_toggle:
			_set_check_value(_postfx_color_limit_toggle, bool(fx["postfx_color_limit"]))
		if fx.has("postfx_color_levels") and _postfx_color_levels_slider:
			_postfx_color_levels_slider.value = float(fx["postfx_color_levels"])
		if fx.has("postfx_dither") and _postfx_dither_toggle:
			_set_check_value(_postfx_dither_toggle, bool(fx["postfx_dither"]))
		if fx.has("postfx_dither_strength") and _postfx_dither_strength_slider:
			_postfx_dither_strength_slider.value = float(fx["postfx_dither_strength"])
		if fx.has("postfx_opacity") and _postfx_opacity_slider:
			_postfx_opacity_slider.value = float(fx["postfx_opacity"])
		_apply_postfx_settings()
	if meta.has("composition") and meta["composition"] is Dictionary:
		var comp := meta["composition"] as Dictionary
		if comp.has("crop_ratio"):
			var ratio := float(comp["crop_ratio"])
			_composition_crop_ratio = ratio
			if _composition_crop_options:
				var selected_idx := -1
				for i in range(_composition_crop_options.get_item_count()):
					var opt_meta: Variant = _composition_crop_options.get_item_metadata(i)
					if opt_meta is Dictionary:
						var opt_ratio := float((opt_meta as Dictionary).get("ratio", 0.0))
						if absf(opt_ratio - ratio) < 0.001:
							selected_idx = i
							break
				if selected_idx >= 0:
					_composition_crop_options.select(selected_idx)
		if comp.has("offset") and comp["offset"] is Array and (comp["offset"] as Array).size() >= 2:
			var arr := comp["offset"] as Array
			_composition_crop_offset = Vector2(float(arr[0]), float(arr[1]))
			if _composition_offset_x_slider:
				_composition_offset_x_slider.value = _composition_crop_offset.x
			if _composition_offset_y_slider:
				_composition_offset_y_slider.value = _composition_crop_offset.y
		if comp.has("roll"):
			_composition_horizon_roll = float(comp["roll"])
			if _composition_roll_slider:
				_composition_roll_slider.value = _composition_horizon_roll
			_apply_camera_rotation_from_angles()
		if comp.has("thirds_snap") and _composition_snap_toggle:
			_composition_snap_toggle.button_pressed = bool(comp["thirds_snap"])
	if meta.has("capture_workflow") and meta["capture_workflow"] is Dictionary:
		var workflow := meta["capture_workflow"] as Dictionary
		if workflow.has("timer_seconds") and _capture_timer_slider:
			_capture_timer_slider.value = float(workflow["timer_seconds"])
		if workflow.has("burst_count") and _capture_burst_options:
			var burst_count := int(workflow["burst_count"])
			for i in range(_capture_burst_options.get_item_count()):
				var burst_meta: Variant = _capture_burst_options.get_item_metadata(i)
				if int(burst_meta) == burst_count:
					_capture_burst_options.select(i)
					break
		if workflow.has("bracket_count") and _capture_bracket_options:
			var bracket_count := int(workflow["bracket_count"])
			for i in range(_capture_bracket_options.get_item_count()):
				var bracket_meta: Variant = _capture_bracket_options.get_item_metadata(i)
				if int(bracket_meta) == bracket_count:
					_capture_bracket_options.select(i)
					break
		if workflow.has("bracket_step_ev") and _capture_bracket_step_slider:
			_capture_bracket_step_slider.value = float(workflow["bracket_step_ev"])
		if workflow.has("watermark_enabled") and _capture_watermark_toggle:
			_capture_watermark_toggle.button_pressed = bool(workflow["watermark_enabled"])
		if workflow.has("watermark_text") and _capture_watermark_text:
			_capture_watermark_text.text = String(workflow["watermark_text"])
	_update_viewfinder()


func _reapply_capture(idx: int) -> void:
	if idx < 0 or idx >= _session_captures.size():
		return
	_select_capture(idx)
	var cap := _session_captures[idx] as Dictionary
	_apply_capture_metadata(_load_capture_metadata(cap))
	if cap.has("camera") and _camera:
		var cam := cap["camera"] as Dictionary
		if cam.has("position"):
			_camera.global_position = cam["position"] as Vector3
		if cam.has("rotation"):
			_camera.rotation_degrees = cam["rotation"] as Vector3
		_sync_camera_angles_from_rotation()
	if _status:
		_status.text = "Reapplied capture settings"


func _on_thumb_export_selected(path: String) -> void:
	var idx := _thumb_export_target_index
	if idx < 0 or idx >= _session_captures.size():
		return
	var cap: Dictionary = _session_captures[idx] as Dictionary
	var src := String(cap.get("path", ""))
	if src != "":
		# Try to copy original file manually (FileAccess.copy may not be available everywhere)
		if FileAccess.file_exists(src):
			var r = FileAccess.open(src, FileAccess.ModeFlags.READ)
			if r:
				var size := r.get_length()
				var buf := r.get_buffer(size)
				r.close()
				var w = FileAccess.open(path, FileAccess.ModeFlags.WRITE)
				if w:
					w.store_buffer(buf)
					w.close()
					if _status:
						_status.text = "Exported: %s" % path
					return
				#else fall through to thumbnail fallback
				
	# Fallback: save thumbnail image if source missing
	var tex = cap.get("thumb", null)
	if tex and tex is ImageTexture:
		var img = (tex as ImageTexture).get_image()
		var ext := path.get_extension().to_lower()
		match ext:
			"jpg", "jpeg":
				img.save_jpg(path)
			"exr":
				img.save_exr(path)
			_:
				img.save_png(path)
		if _status:
			_status.text = "Exported thumbnail: %s" % path


func _reveal_in_finder(capture: Dictionary) -> void:
	if capture == null:
		return
	var p := String(capture.get("path", ""))
	if p == "":
		return
	var os_name := OS.get_name().to_lower()
	if os_name.find("mac") != -1 or os_name.find("osx") != -1:
		# 'open -R <path>' reveals file in Finder; omit explicit blocking arg for broader compatibility
		OS.execute("open", ["-R", p])
	elif os_name.find("windows") != -1:
		OS.execute("explorer", ["/select,", p])
	else:
		# Linux: open parent folder
		var parent := p.get_base_dir()
		OS.execute("xdg-open", [parent])


func _on_toolbar_viewfinder_pressed(pressed: bool) -> void:
	if _viewfinder != null:
		_set_viewfinder_visible(pressed)


func _on_toolbar_guides_pressed(pressed: bool) -> void:
	if _guides != null:
		_guides.visible = pressed
	if _guides_check:
		_guides_check.button_pressed = pressed


func _on_capture_pressed() -> void:
	var size := _get_capture_size()
	await _capture_image(size)


func _get_capture_timer_seconds() -> int:
	if _capture_timer_slider == null:
		return 0
	return int(round(_capture_timer_slider.value))


func _get_capture_burst_count() -> int:
	if _capture_burst_options == null or _capture_burst_options.selected < 0:
		return 1
	var meta: Variant = _capture_burst_options.get_item_metadata(_capture_burst_options.selected)
	if meta is int:
		return int(meta)
	if meta is float:
		return int(round(float(meta)))
	return 1


func _get_capture_bracket_count() -> int:
	if _capture_bracket_options == null or _capture_bracket_options.selected < 0:
		return 1
	var meta: Variant = _capture_bracket_options.get_item_metadata(_capture_bracket_options.selected)
	if meta is int:
		return int(meta)
	if meta is float:
		return int(round(float(meta)))
	return 1


func _get_capture_bracket_offsets() -> Array:
	var count := maxi(1, _get_capture_bracket_count())
	var step := _capture_bracket_step_slider.value if _capture_bracket_step_slider else 1.0
	var offsets: Array = []
	if count == 1:
		offsets.append(0.0)
		return offsets
	var half := int((count - 1) / 2)
	for i in range(count):
		offsets.append((float(i - half)) * step)
	return offsets


func _wait_capture_timer() -> void:
	var total := _get_capture_timer_seconds()
	if total <= 0:
		return
	for t in range(total, 0, -1):
		if _status:
			_status.text = "Capturing in %ds…" % t
		await get_tree().create_timer(1.0).timeout


func _apply_capture_watermark(image: Image) -> void:
	if image == null:
		return
	if _capture_watermark_toggle == null or not _capture_watermark_toggle.button_pressed:
		return
	var width := image.get_width()
	var height := image.get_height()
	if width <= 1 or height <= 1:
		return
	var pad := maxi(8, int(round(minf(width, height) * 0.012)))
	var band_h := maxi(20, int(round(height * 0.05)))
	var rect := Rect2i(pad, height - band_h - pad, width - (pad * 2), band_h)
	var overlay := Color(0.02, 0.02, 0.02, 0.55)
	image.fill_rect(rect, overlay)
	# Add a bright top stroke and a corner stamp so watermark is visible without a font dependency.
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, 2), Color(1, 1, 1, 0.75))
	var stamp_size := maxi(14, int(round(band_h * 0.65)))
	var stamp_rect := Rect2i(rect.position.x + rect.size.x - stamp_size - 6, rect.position.y + 4, stamp_size, stamp_size)
	image.fill_rect(stamp_rect, Color(1, 1, 1, 0.85))
	var mark_text := _capture_watermark_text.text if _capture_watermark_text else "SF"
	var bits: int = abs(mark_text.hash())
	var bit_width := maxi(2, int(round(rect.size.x / 48.0)))
	var bit_height := maxi(8, band_h - 10)
	var start_x := rect.position.x + 8
	var start_y := rect.position.y + 5
	for i in range(0, 24):
		if ((bits >> i) & 1) == 1:
			image.fill_rect(Rect2i(start_x + (i * bit_width), start_y, bit_width - 1, bit_height), Color(1, 1, 1, 0.7))


func _run_capture_sequence(size: Vector2i) -> void:
	await _wait_capture_timer()
	var base_exposure := _base_exposure
	var burst_count := maxi(1, _get_capture_burst_count())
	var bracket_offsets := _get_capture_bracket_offsets()
	var ts := Time.get_datetime_string_from_system().replace(":", "-")
	for burst_index in range(burst_count):
		for offset in bracket_offsets:
			var exposure := base_exposure + float(offset)
			_on_exposure_changed(exposure)
			if _exposure_slider:
				_set_slider_value(_exposure_slider, exposure)
			if _status:
				_status.text = "Capturing burst %d/%d (EV %+0.1f)…" % [burst_index + 1, burst_count, float(offset)]
			var img := await _render_to_image(size)
			if img:
				_apply_capture_watermark(img)
				_save_image(img, {
					"sequence": ts,
					"burst_index": burst_index + 1,
					"burst_total": burst_count,
					"bracket_ev": float(offset)
				})
		if burst_index < burst_count - 1:
			await get_tree().create_timer(0.08).timeout
	_on_exposure_changed(base_exposure)
	if _exposure_slider:
		_set_slider_value(_exposure_slider, base_exposure)
	if _status:
		_status.text = "Saved capture sequence"


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


func _format_bracket_suffix(ev: float) -> String:
	var abs_ev := absf(ev)
	var hundredths := int(round(abs_ev * 100.0))
	var major := int(hundredths / 100)
	var minor := int(hundredths % 100)
	var sign := "p" if ev >= 0.0 else "m"
	return "ev%s%d_%02d" % [sign, major, minor]


func _build_capture_metadata(full_path: String, size: Vector2i, format: String, context: Dictionary) -> Dictionary:
	return {
		"captured_at": Time.get_datetime_string_from_system(),
		"path": full_path,
		"size": [size.x, size.y],
		"format": format,
		"camera": {
			"position": [_camera.global_position.x, _camera.global_position.y, _camera.global_position.z] if _camera else [0.0, 0.0, 0.0],
			"rotation": [_camera.rotation_degrees.x, _camera.rotation_degrees.y, _camera.rotation_degrees.z] if _camera else [0.0, 0.0, 0.0],
			"fov": _camera.fov if _camera else 60.0,
			"iso": _iso_current,
			"aperture": _aperture_current,
			"shutter": _shutter_current,
			"focus_distance": _focus_distance
		},
		"exposure": {
			"base": _base_exposure,
			"auto": _auto_exposure_enabled
		},
		"environment": {
			"preset": _env_options.get_item_text(_env_options.selected) if _env_options else "",
			"sun_shadows": _sun_shadow_toggle.button_pressed if _sun_shadow_toggle else true,
			"sun_shadow_opacity": _sun_shadow_opacity_slider.value if _sun_shadow_opacity_slider else 1.0,
			"sun_softness": _sun_softness_slider.value if _sun_softness_slider else 0.0,
			"sun_color": _sun_color_picker.color if _sun_color_picker else (_key_light.light_color if _key_light else Color(1.0, 0.98, 0.92)),
			"ambient_color": _ambient_color_picker.color if _ambient_color_picker else (_world_env.environment.ambient_light_color if _world_env and _world_env.environment else Color(0.6, 0.65, 0.7)),
			"fog_enabled": _fog_toggle.button_pressed if _fog_toggle else false,
			"fog_color": _fog_color_picker.color if _fog_color_picker else Color(0.72, 0.77, 0.83),
			"fog_density": _fog_density_slider.value if _fog_density_slider else 0.0,
			"fog_begin": _fog_begin_slider.value if _fog_begin_slider else 5.0,
			"fog_end": _fog_end_slider.value if _fog_end_slider else 200.0,
			"fog_height_enabled": _fog_height_toggle.button_pressed if _fog_height_toggle else false,
			"fog_height_density": _fog_height_density_slider.value if _fog_height_density_slider else 0.05,
			"fog_height_falloff": _fog_height_falloff_slider.value if _fog_height_falloff_slider else 0.5,
			"volumetric_enabled": _volumetric_fog_toggle.button_pressed if _volumetric_fog_toggle else false,
			"volumetric_density": _volumetric_fog_density_slider.value if _volumetric_fog_density_slider else 0.03,
			"volumetric_aniso": _volumetric_fog_aniso_slider.value if _volumetric_fog_aniso_slider else 0.0
		},
		"color": {
			"temp": _temp_slider.value if _temp_slider else 0.0,
			"tint": _tint_slider.value if _tint_slider else 0.0,
			"saturation": _saturation_slider.value if _saturation_slider else 1.0,
			"contrast": _contrast_slider.value if _contrast_slider else 1.0
		},
		"effects": {
			"vignette": _vignette_slider.value if _vignette_slider else 0.0,
			"grain": _grain_slider.value if _grain_slider else 0.0,
			"bloom": _bloom_slider.value if _bloom_slider else 0.0,
			"ps1_enabled": _ps1_shader_toggle.button_pressed if _ps1_shader_toggle else _is_ps1_shader_enabled(),
			"postfx_enabled": _postfx_toggle.button_pressed if _postfx_toggle else _postfx_enabled,
			"postfx_fog": _postfx_fog_toggle.button_pressed if _postfx_fog_toggle else false,
			"postfx_fog_distance": _postfx_fog_distance_slider.value if _postfx_fog_distance_slider else 120.0,
			"postfx_fog_fade": _postfx_fog_fade_slider.value if _postfx_fog_fade_slider else 60.0,
			"postfx_noise": _postfx_noise_toggle.button_pressed if _postfx_noise_toggle else false,
			"postfx_noise_time": _postfx_noise_time_slider.value if _postfx_noise_time_slider else 4.0,
			"postfx_color_limit": _postfx_color_limit_toggle.button_pressed if _postfx_color_limit_toggle else true,
			"postfx_color_levels": _postfx_color_levels_slider.value if _postfx_color_levels_slider else 32.0,
			"postfx_dither": _postfx_dither_toggle.button_pressed if _postfx_dither_toggle else true,
			"postfx_dither_strength": _postfx_dither_strength_slider.value if _postfx_dither_strength_slider else 0.35,
			"postfx_opacity": _postfx_opacity_slider.value if _postfx_opacity_slider else 1.0
		},
		"composition": {
			"crop_ratio": _composition_crop_ratio,
			"offset": [_composition_crop_offset.x, _composition_crop_offset.y],
			"roll": _composition_horizon_roll,
			"thirds_snap": _composition_thirds_snap_enabled
		},
		"capture_workflow": {
			"timer_seconds": _get_capture_timer_seconds(),
			"burst_count": _get_capture_burst_count(),
			"bracket_count": _get_capture_bracket_count(),
			"bracket_step_ev": _capture_bracket_step_slider.value if _capture_bracket_step_slider else 1.0,
			"watermark_enabled": _capture_watermark_toggle.button_pressed if _capture_watermark_toggle else false,
			"watermark_text": _capture_watermark_text.text if _capture_watermark_text else ""
		},
		"sequence": context
	}


func _save_image(image: Image, capture_context: Dictionary = {}) -> void:
	if image == null:
		return
	var dir_path := _get_capture_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var ts := String(capture_context.get("sequence", Time.get_datetime_string_from_system().replace(":", "-")))
	_capture_sequence_counter += 1
	var format := _get_capture_format()
	var ext := "png"
	if format == "JPG":
		ext = "jpg"
	elif format == "EXR":
		ext = "exr"
	var filename := "photo_%s" % ts
	var burst_total := int(capture_context.get("burst_total", 1))
	if burst_total > 1:
		filename += "_b%02d" % int(capture_context.get("burst_index", 1))
	if capture_context.has("bracket_ev"):
		filename += "_" + _format_bracket_suffix(float(capture_context.get("bracket_ev", 0.0)))
	if _capture_watermark_toggle and _capture_watermark_toggle.button_pressed:
		filename += "_wm"
	filename += "_%03d.%s" % [_capture_sequence_counter, ext]
	var full_path := dir_path.path_join(filename)
	match format:
		"JPG":
			image.save_jpg(full_path)
		"EXR":
			image.save_exr(full_path)
		_:
			image.save_png(full_path)
	var size := Vector2i(image.get_width(), image.get_height())
	var metadata := _build_capture_metadata(full_path, size, format, capture_context)
	var metadata_path := full_path.get_basename() + ".json"
	var metadata_file := FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata_file:
		metadata_file.store_string(JSON.stringify(metadata))
		metadata_file.close()
	if _status:
		_status.text = "Saved: %s" % full_path

	# Add to session captures and contact strip
	var cam_state := {
		"position": _camera.global_position if _camera else Vector3.ZERO,
		"rotation": _camera.rotation_degrees if _camera else Vector3.ZERO,
		"fov": _camera.fov if _camera else 60.0,
		"iso": _iso_current,
		"aperture": _aperture_current,
		"shutter": _shutter_current,
		"focus_distance": _focus_distance
	}
	var capture: Dictionary = {
		"path": full_path,
		"metadata_path": metadata_path,
		"metadata": metadata,
		"thumb": null,
		"camera": cam_state
	}
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
	await _run_capture_sequence(size)


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
	if _postfx_overlay:
		_postfx_overlay.visible = _postfx_enabled and pass_name == PASS_BEAUTY
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
		_apply_postfx_settings()
		return
	for mesh in _material_state.keys():
		if mesh and is_instance_valid(mesh):
			var state: Dictionary = _material_state[mesh] as Dictionary
			(mesh as MeshInstance3D).material_override = state["override"]
			var surface_overrides: Array = state["surface"]
			for i in range(surface_overrides.size()):
				(mesh as MeshInstance3D).set_surface_override_material(i, surface_overrides[i])
	_material_state.clear()
	_apply_postfx_settings()


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


func _get_attr_if_exists(obj: Object, prop_name: String, fallback: Variant) -> Variant:
	if obj == null:
		return fallback
	for prop in obj.get_property_list():
		if prop.name == prop_name:
			return obj.get(prop_name)
	return fallback
