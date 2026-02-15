extends Node3D

const HOME_SETUP_SCRIPT := preload("res://scripts/home_setup.gd")
const PHOTO_CAPTURE_DIR := "user://photo_captures"
const MAIN_MENU_SCENE := preload("res://scenes/ui/main_menu.tscn")

@export var move_speed: float = 12.0
@export var fast_multiplier: float = 3.0
@export var mouse_sens: float = 0.25

var _map: FuncGodotMap
var _yaw: float = 0.0
var _pitch: float = 0.0
var _bookmarks: Dictionary = {}
var _ui_visible: bool = true
var _material_state: Dictionary = {}
var _env_presets: Dictionary = {}

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
var _status: Label
var _guides: Control
var _fov_slider: HSlider
var _fov_value: Label
var _focal_options: OptionButton
var _iso_slider: HSlider
var _iso_value: Label
var _aperture_slider: HSlider
var _aperture_value: Label
var _shutter_slider: HSlider
var _shutter_value: Label
var _exposure_slider: HSlider
var _exposure_value: Label
var _env_options: OptionButton
var _res_options: OptionButton
var _guides_check: CheckBox
var _golden_check: CheckBox
var _safe_check: CheckBox
var _capture_button: Button
var _capture_layers_button: Button
var _back_button: Button
var _pass_beauty: CheckBox
var _pass_albedo: CheckBox
var _pass_normals: CheckBox
var _pass_depth: CheckBox
var _pass_lighting: CheckBox
var _key_enabled: CheckBox
var _key_color: ColorPickerButton
var _key_intensity: HSlider
var _fill_enabled: CheckBox
var _fill_color: ColorPickerButton
var _fill_intensity: HSlider
var _rim_enabled: CheckBox
var _rim_color: ColorPickerButton
var _rim_intensity: HSlider
var _top_enabled: CheckBox
var _top_color: ColorPickerButton
var _top_intensity: HSlider
var _bounce_enabled: CheckBox
var _bounce_color: ColorPickerButton
var _bounce_intensity: HSlider


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_resolve_nodes()
	_setup_camera_attributes()
	_setup_pass_materials()
	_setup_ui()
	_setup_environment_presets()
	if _ui_root:
		_ui_root.visible = _ui_visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if _ui_visible else Input.MOUSE_MODE_CAPTURED)
	call_deferred("_ensure_ui_layout")
	await _build_map_from_debug()
	_position_camera_at_start()
	_ensure_camera_active()


func _setup_camera_attributes() -> void:
	if _camera == null:
		return
	_camera.current = true
	var attrs := CameraAttributesPhysical.new()
	_set_attr_if_exists(attrs, "aperture", 4.0)
	_set_attr_if_exists(attrs, "f_stop", 4.0)
	_set_attr_if_exists(attrs, "fstop", 4.0)
	_set_attr_if_exists(attrs, "shutter_speed", 1.0 / 125.0)
	_set_attr_if_exists(attrs, "iso", 200.0)
	_camera.attributes = attrs
	if _world_env == null:
		_world_env = WorldEnvironment.new()
		_world_env.name = "WorldEnvironment"
		add_child(_world_env)
	if _world_env.environment == null:
		_world_env.environment = Environment.new()


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
	_ui_root = _find_node("PhotoUI", "Control") as Control
	if _ui_root:
		_ui_root.visible = true
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
	_exposure_slider = _find_node("ExposureSlider", "HSlider") as HSlider
	_exposure_value = _find_node("ExposureValue", "Label") as Label
	_env_options = _find_node("EnvOptions", "OptionButton") as OptionButton
	_res_options = _find_node("ResOptions", "OptionButton") as OptionButton
	_guides_check = _find_node("GuidesCheck", "CheckBox") as CheckBox
	_golden_check = _find_node("GoldenCheck", "CheckBox") as CheckBox
	_safe_check = _find_node("SafeCheck", "CheckBox") as CheckBox
	_capture_button = _find_node("CaptureButton", "Button") as Button
	_capture_layers_button = _find_node("CaptureLayersButton", "Button") as Button
	_back_button = _find_node("BackButton", "Button") as Button
	_pass_beauty = _find_node("PassBeauty", "CheckBox") as CheckBox
	_pass_albedo = _find_node("PassAlbedo", "CheckBox") as CheckBox
	_pass_normals = _find_node("PassNormals", "CheckBox") as CheckBox
	_pass_depth = _find_node("PassDepth", "CheckBox") as CheckBox
	_pass_lighting = _find_node("PassLighting", "CheckBox") as CheckBox
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
	if _exposure_slider:
		_exposure_slider.value_changed.connect(_on_exposure_changed)
		_on_exposure_changed(_exposure_slider.value)
	if _env_options:
		_env_options.item_selected.connect(_on_environment_selected)
	if _res_options:
		_res_options.item_selected.connect(_on_resolution_selected)
	if _guides_check:
		_guides_check.toggled.connect(_on_guides_toggled)
	if _golden_check:
		_golden_check.toggled.connect(_on_golden_toggled)
	if _safe_check:
		_safe_check.toggled.connect(_on_safe_toggled)
	if _capture_button:
		_capture_button.pressed.connect(_on_capture_pressed)
	if _capture_layers_button:
		_capture_layers_button.pressed.connect(_on_capture_layers_pressed)
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)
	_setup_light_rig_ui()


func _ensure_ui_layout() -> void:
	# Root UI anchoring
	if _ui_root:
		_ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_ui_root.visible = true
	if _guides:
		_guides.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_guides.visible = true

	var panel := _get_or_create_container("Panel", PanelContainer, _ui_root)
	if panel is Control:
		(panel as Control).set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		(panel as Control).visible = true
		(panel as Control).offset_left = 16
		(panel as Control).offset_top = 16
		(panel as Control).offset_right = 420
		(panel as Control).offset_bottom = 620

	var margin := _get_or_create_container("Margin", MarginContainer, panel)
	if margin is MarginContainer:
		(margin as MarginContainer).add_theme_constant_override("margin_left", 16)
		(margin as MarginContainer).add_theme_constant_override("margin_right", 16)
		(margin as MarginContainer).add_theme_constant_override("margin_top", 16)
		(margin as MarginContainer).add_theme_constant_override("margin_bottom", 16)

	var vbox := _get_or_create_container("VBox", VBoxContainer, margin)
	if vbox is VBoxContainer:
		(vbox as VBoxContainer).add_theme_constant_override("separation", 8)

	# Reparent known nodes back into VBox (in case they were dragged out)
	var vbox_nodes := [
		"Title", "Status",
		"FOVRow", "FocalRow", "ISORow", "ApertureRow", "ShutterRow",
		"ExposureRow", "EnvRow", "ResRow", "GuidesRow", "ButtonsRow",
		"PassesLabel", "PassesGrid", "LightRigLabel", "LightRigGrid"
	]
	for n in vbox_nodes:
		_reparent_by_name(n, vbox)
		var node := vbox.get_node_or_null(n)
		if node is Control:
			(node as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Ensure rows/grids exist and their child controls are under the right parent.
	_ensure_row("FOVRow", HBoxContainer, vbox, ["FOVLabel", "FOVSlider", "FOVValue"])
	_ensure_row("FocalRow", HBoxContainer, vbox, ["FocalLabel", "FocalOptions"])
	_ensure_row("ISORow", HBoxContainer, vbox, ["ISOLabel", "ISOSlider", "ISOValue"])
	_ensure_row("ApertureRow", HBoxContainer, vbox, ["ApertureLabel", "ApertureSlider", "ApertureValue"])
	_ensure_row("ShutterRow", HBoxContainer, vbox, ["ShutterLabel", "ShutterSlider", "ShutterValue"])
	_ensure_row("ExposureRow", HBoxContainer, vbox, ["ExposureLabel", "ExposureSlider", "ExposureValue"])
	_ensure_row("EnvRow", HBoxContainer, vbox, ["EnvLabel", "EnvOptions"])
	_ensure_row("ResRow", HBoxContainer, vbox, ["ResLabel", "ResOptions"])
	_ensure_row("GuidesRow", HBoxContainer, vbox, ["GuidesCheck", "GoldenCheck", "SafeCheck"])
	_ensure_row("ButtonsRow", HBoxContainer, vbox, ["CaptureButton", "CaptureLayersButton", "BackButton"])
	_ensure_row("PassesGrid", GridContainer, vbox, ["PassBeauty", "PassAlbedo", "PassNormals", "PassDepth", "PassLighting"])
	_ensure_row("LightRigGrid", GridContainer, vbox, [
		"KeyEnabled", "KeyColor", "KeyIntensity", "KeySpacer",
		"FillEnabled", "FillColor", "FillIntensity", "FillSpacer",
		"RimEnabled", "RimColor", "RimIntensity", "RimSpacer",
		"TopEnabled", "TopColor", "TopIntensity", "TopSpacer",
		"BounceEnabled", "BounceColor", "BounceIntensity", "BounceSpacer"
	])

	# Sweep stray Controls under PhotoUI into VBox
	if _ui_root and vbox:
		var ui_children := _ui_root.get_children().duplicate()
		for ch in ui_children:
			if ch is Control and ch != panel and ch != _guides:
				_reparent(ch, vbox)
				(ch as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sweep stray Controls under Margin into VBox
	if margin and vbox:
		var margin_children := margin.get_children().duplicate()
		for ch in margin_children:
			if ch is Control and ch != vbox:
				_reparent(ch, vbox)
				(ch as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ensure_row(row_name: String, type_class: Variant, parent: Node, child_names: Array) -> void:
	if parent == null:
		return
	var row := _get_or_create_container(row_name, type_class, parent)
	if row is Control:
		(row as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child_name in child_names:
		_reparent_by_name(child_name, row)
		var node := row.get_node_or_null(child_name)
		if node is Control:
			(node as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL


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
		enabled.toggled.connect(func(pressed: bool):
			light.visible = pressed
		)
		light.visible = enabled.button_pressed
	if color:
		color.color_changed.connect(func(c: Color):
			light.light_color = c
		)
		light.light_color = color.color
	if intensity:
		intensity.value_changed.connect(func(v: float):
			light.light_energy = v
		)
		light.light_energy = intensity.value


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
		_status.text = "Photo mode ready"


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
	if _camera and _camera.attributes is CameraAttributesPhysical:
		_set_attr_if_exists(_camera.attributes, "iso", value)
	if _iso_value:
		_iso_value.text = "%d" % int(value)


func _on_aperture_changed(value: float) -> void:
	if _camera and _camera.attributes is CameraAttributesPhysical:
		_set_attr_if_exists(_camera.attributes, "aperture", value)
		_set_attr_if_exists(_camera.attributes, "f_stop", value)
		_set_attr_if_exists(_camera.attributes, "fstop", value)
	if _aperture_value:
		_aperture_value.text = "f/%.1f" % value


func _on_shutter_changed(value: float) -> void:
	if _camera and _camera.attributes is CameraAttributesPhysical:
		_set_attr_if_exists(_camera.attributes, "shutter_speed", value)
	if _shutter_value:
		var denom := int(round(1.0 / maxf(value, 0.0001)))
		_shutter_value.text = "1/%d" % denom


func _on_exposure_changed(value: float) -> void:
	if _world_env and _world_env.environment:
		_world_env.environment.tonemap_exposure = value
	if _exposure_value:
		_exposure_value.text = "%.2f" % value


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
		_env_options.select(0)
		_apply_environment_preset(_env_options.get_item_text(0))
	else:
		_apply_environment_preset("Clear Day")


func _on_environment_selected(index: int) -> void:
	if _env_options:
		_apply_environment_preset(_env_options.get_item_text(index))


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

	if _rim_light:
		_rim_light.light_energy = preset["moon_energy"]
		_rim_light.light_color = Color(0.55, 0.65, 1.0)
		_rim_light.rotation_degrees = Vector3(-20, 220, 0)
		if _rim_enabled:
			_rim_enabled.button_pressed = preset["moon_energy"] > 0.01

	# Adjust exposure UI if present.
	if _exposure_slider:
		_exposure_slider.value = preset["exposure"]


func _on_resolution_selected(_index: int) -> void:
	pass


func _on_guides_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_guides_enabled"):
		_guides.call("set_guides_enabled", pressed)


func _on_golden_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_golden_enabled"):
		_guides.call("set_golden_enabled", pressed)


func _on_safe_toggled(pressed: bool) -> void:
	if _guides and _guides.has_method("set_safe_frame_enabled"):
		_guides.call("set_safe_frame_enabled", pressed)


func _on_capture_pressed() -> void:
	var multiplier := _get_resolution_multiplier()
	await _capture_png(multiplier)


func _on_capture_layers_pressed() -> void:
	var multiplier := _get_resolution_multiplier()
	await _capture_layers_exr(multiplier)


func _on_back_pressed() -> void:
	var dbg := get_node_or_null("/root/DEBUG")
	if dbg != null and dbg.has_method("toggle_menu"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		dbg.call_deferred("toggle_menu")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _get_resolution_multiplier() -> int:
	if _res_options == null:
		return 1
	match _res_options.get_selected_id():
		0:
			return 1
		1:
			return 2
		2:
			return 4
		_:
			return 1


func _capture_png(multiplier: int) -> void:
	if _status:
		_status.text = "Capturing PNG…"
	var base_size := get_viewport().get_visible_rect().size
	var size := Vector2i(int(base_size.x * multiplier), int(base_size.y * multiplier))

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
	_save_png(img)
	sub.queue_free()

	if _status:
		_status.text = "Saved capture"


func _save_png(image: Image) -> void:
	if image == null:
		return
	var dir_path := ProjectSettings.globalize_path(PHOTO_CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var ts := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "photo_%s.png" % ts
	var full_path := dir_path.path_join(filename)
	image.save_png(full_path)
	if _status:
		_status.text = "Saved: %s" % full_path


func _capture_layers_exr(multiplier: int) -> void:
	var passes := _selected_passes()
	if passes.is_empty():
		if _status:
			_status.text = "No passes selected"
		return

	var dir_path := _make_capture_folder()
	var base_size := get_viewport().get_visible_rect().size
	var size := Vector2i(int(base_size.x * multiplier), int(base_size.y * multiplier))
	for pass_name in passes:
		if _status:
			_status.text = "Capturing %s…" % pass_name
		_apply_pass(pass_name)
		var img := await _render_to_image(size)
		if img:
			_save_exr(img, dir_path, pass_name)
	_restore_pass_state()
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
	var dir_path := ProjectSettings.globalize_path(PHOTO_CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var ts := Time.get_datetime_string_from_system().replace(":", "-")
	var folder := dir_path.path_join("photo_" + ts)
	DirAccess.make_dir_recursive_absolute(folder)
	return folder


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
