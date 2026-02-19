extends Control

@export var back_scene_path: String = "res://scenes/ui/main_menu.tscn"

var fullscreen_check: CheckButton
var vsync_check: CheckButton
var resolution_option: OptionButton

var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var sens_slider: HSlider
var smooth_slider: HSlider
var fov_slider: HSlider

var apply_button: Button
var back_button: Button

var _resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Defensive: ensure the scene truly occupies the full viewport so CenterContainer can center.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := get_node_or_null("Background") as Control
	if bg:
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := get_node_or_null("Center") as Control
	if center:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_resolve_nodes()
	# If nodes were dragged out of their containers, put them back so layout stacks correctly.
	call_deferred("_ensure_layout")
	_fill_resolution_options()
	_load_from_settings()

	if apply_button:
		apply_button.pressed.connect(_on_apply_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		# Sensible focus
		back_button.grab_focus()
	else:
		push_warning("OptionsMenu: BackButton not found; cannot return to main menu")


func _ensure_layout() -> void:
	var center := _get_or_create_container("Center", CenterContainer, self) as Control
	if center:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := _get_or_create_container("Panel", PanelContainer, center)
	var margin := _get_or_create_container("Margin", MarginContainer, panel)
	var vbox := _get_or_create_container("VBox", VBoxContainer, margin)
	if vbox is VBoxContainer:
		(vbox as VBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
		(vbox as VBoxContainer).add_theme_constant_override("separation", 10)

	if margin is MarginContainer:
		(margin as MarginContainer).add_theme_constant_override("margin_left", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_right", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_top", 24)
		(margin as MarginContainer).add_theme_constant_override("margin_bottom", 24)

	var grid := _get_or_create_container("Grid", GridContainer, vbox)
	var audio_grid := _get_or_create_container("AudioGrid", GridContainer, vbox)
	var controls_grid := _get_or_create_container("ControlsGrid", GridContainer, vbox)
	var buttons := _get_or_create_container("Buttons", HBoxContainer, vbox)
	if buttons is HBoxContainer:
		(buttons as HBoxContainer).alignment = BoxContainer.ALIGNMENT_END
		(buttons as HBoxContainer).add_theme_constant_override("separation", 10)

	# Ensure top-level stacking in VBox
	_reparent_by_name("Title", vbox)
	_reparent_by_name("Graphics", vbox)
	if grid:
		_reparent(grid, vbox)
	_reparent_by_name("Audio", vbox)
	if audio_grid:
		_reparent(audio_grid, vbox)
	_reparent_by_name("Controls", vbox)
	if controls_grid:
		_reparent(controls_grid, vbox)
	if buttons:
		_reparent(buttons, vbox)

	# Sweep any stray Controls that got dragged to the root or Margin.
	var top_level := get_children().duplicate()
	for ch in top_level:
		if ch is Control and ch != center and ch.name != "Background":
			_reparent(ch, vbox)
	var margin_children := margin.get_children().duplicate() if margin else []
	for ch in margin_children:
		if ch is Control and ch != vbox:
			_reparent(ch, vbox)

	# Grid children
	if grid:
		_reparent_by_name("FullscreenLabel", grid)
		_reparent_by_name("FullscreenCheck", grid)
		_reparent_by_name("VsyncLabel", grid)
		_reparent_by_name("VsyncCheck", grid)
		_reparent_by_name("ResolutionLabel", grid)
		_reparent_by_name("ResolutionOption", grid)

	# Audio grid children
	if audio_grid:
		_reparent_by_name("MasterLabel", audio_grid)
		_reparent_by_name("MasterSlider", audio_grid)
		_reparent_by_name("MusicLabel", audio_grid)
		_reparent_by_name("MusicSlider", audio_grid)
		_reparent_by_name("SfxLabel", audio_grid)
		_reparent_by_name("SfxSlider", audio_grid)

	# Controls grid children
	if controls_grid:
		_reparent_by_name("SensLabel", controls_grid)
		_reparent_by_name("SensSlider", controls_grid)
		_reparent_by_name("SmoothLabel", controls_grid)
		_reparent_by_name("SmoothSlider", controls_grid)
		_reparent_by_name("FovLabel", controls_grid)
		_reparent_by_name("FovSlider", controls_grid)

	# Buttons row
	if buttons:
		_reparent_by_name("ApplyButton", buttons)
		_reparent_by_name("BackButton", buttons)


func _reparent_by_name(name_hint: String, new_parent: Node) -> void:
	if new_parent == null:
		return
	var node := find_child(name_hint, true, false)
	if node == null:
		# Try substring match (mangled names like "...#ApplyButton")
		for n in find_children("*", "", true, false):
			if String(n.name).find(name_hint) != -1:
				node = n
				break
	if node != null:
		_reparent(node, new_parent)
		if node is Control:
			(node as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(node as Control).layout_mode = 2


func _reparent(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null:
		return
	if node.get_parent() == new_parent:
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)


func _get_or_create_container(name_hint: String, type_class: Variant, parent: Node) -> Node:
	if parent == null:
		return null
	var direct := parent.get_node_or_null(name_hint)
	if direct != null:
		return direct
	var found := find_child(name_hint, true, false)
	if found != null:
		_reparent(found, parent)
		return found
	var node: Node = type_class.new() as Node
	if node == null:
		return null
	node.name = name_hint
	parent.add_child(node)
	return node


func _resolve_nodes() -> void:
	# Prefer unique-name lookup (works with Unique Name in Owner), but fall back to name search
	# so manual edits don't break the script.
	fullscreen_check = _find_node("FullscreenCheck", "CheckButton") as CheckButton
	vsync_check = _find_node("VsyncCheck", "CheckButton") as CheckButton
	resolution_option = _find_node("ResolutionOption", "OptionButton") as OptionButton

	master_slider = _find_node("MasterSlider", "HSlider") as HSlider
	music_slider = _find_node("MusicSlider", "HSlider") as HSlider
	sfx_slider = _find_node("SfxSlider", "HSlider") as HSlider
	sens_slider = _find_node("SensSlider", "HSlider") as HSlider
	smooth_slider = _find_node("SmoothSlider", "HSlider") as HSlider
	fov_slider = _find_node("FovSlider", "HSlider") as HSlider

	apply_button = _find_node("ApplyButton", "Button") as Button
	back_button = _find_node("BackButton", "Button") as Button


func _find_node(name_hint: String, type_hint: String) -> Node:
	# 1) Unique-name lookup (safe)
	var by_unique := get_node_or_null("%" + name_hint)
	if by_unique != null and (type_hint.is_empty() or by_unique.is_class(type_hint)):
		return by_unique

	# 2) Exact name anywhere
	var by_name := find_child(name_hint, true, false)
	if by_name != null and (type_hint.is_empty() or by_name.is_class(type_hint)):
		return by_name

	# 3) Substring match (helps when names get mangled like "...#ApplyButton")
	var any := find_children("*", type_hint, true, false)
	for n in any:
		if n != null and String(n.name).find(name_hint) != -1:
			return n
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _fill_resolution_options() -> void:
	if resolution_option == null:
		return
	resolution_option.clear()
	for r in _resolutions:
		resolution_option.add_item("%dx%d" % [r.x, r.y])


func _load_from_settings() -> void:
	var s := get_node_or_null("/root/SETTINGS")
	if s == null:
		return

	if fullscreen_check:
		fullscreen_check.button_pressed = bool(s.fullscreen)
	if vsync_check:
		vsync_check.button_pressed = bool(s.vsync)

	if master_slider:
		master_slider.value = float(s.master_volume)
	if music_slider:
		music_slider.value = float(s.music_volume)
	if sfx_slider:
		sfx_slider.value = float(s.sfx_volume)
	if sens_slider:
		sens_slider.value = float(s.mouse_sens)
	if smooth_slider:
		smooth_slider.value = float(s.mouse_smoothing)
	if fov_slider:
		fov_slider.value = float(s.gameplay_fov)

	_select_resolution(s.window_size)


func _select_resolution(window_size: Vector2i) -> void:
	if resolution_option == null:
		return
	var best := 0
	for i in range(_resolutions.size()):
		if _resolutions[i] == window_size:
			best = i
			break
	resolution_option.select(best)


func _on_apply_pressed() -> void:
	var s := get_node_or_null("/root/SETTINGS")
	if s == null:
		return

	if fullscreen_check:
		s.fullscreen = fullscreen_check.button_pressed
	if vsync_check:
		s.vsync = vsync_check.button_pressed

	var idx := resolution_option.selected
	if idx >= 0 and idx < _resolutions.size():
		s.window_size = _resolutions[idx]

	if master_slider:
		s.master_volume = float(master_slider.value)
	if music_slider:
		s.music_volume = float(music_slider.value)
	if sfx_slider:
		s.sfx_volume = float(sfx_slider.value)
	if sens_slider:
		s.mouse_sens = float(sens_slider.value)
	if smooth_slider:
		s.mouse_smoothing = float(smooth_slider.value)
	if fov_slider:
		s.gameplay_fov = float(fov_slider.value)

	if s.has_method("apply_and_save"):
		s.call("apply_and_save")


func _on_back_pressed() -> void:
	if back_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(back_scene_path)
