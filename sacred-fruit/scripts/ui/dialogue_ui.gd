class_name DialogueUI
extends CanvasLayer

signal option_selected(choice_index: int)
signal close_requested()

@export_range(24.0, 320.0, 1.0) var default_line_reveal_rate: float = 90.0

var _root: Control = null
var _backdrop: ColorRect = null
var _panel: PanelContainer = null
var _speaker_label: Label = null
var _line_label: Label = null
var _options_box: VBoxContainer = null
var _hint_label: Label = null
var _option_buttons: Array[Button] = []

var _full_line_text: String = ""
var _line_reveal_accum: float = 0.0
var _line_reveal_index: int = 0
var _line_reveal_done: bool = true
var _line_reveal_rate: float = 90.0
var _show_hints: bool = true

var _root_tween: Tween = null
var _options_tween: Tween = null


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	visible = false
	_build_ui()


func _process(delta: float) -> void:
	if not visible:
		return
	_tick_line_reveal(delta)


func _build_ui() -> void:
	if _root != null and _speaker_label != null and _line_label != null and _options_box != null:
		return

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.color = Color(0.02, 0.02, 0.03, 0.64)
	_root.add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.08
	_panel.anchor_top = 0.56
	_panel.anchor_right = 0.92
	_panel.anchor_bottom = 0.95
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.08, 0.10, 0.93)
	panel_style.border_color = Color(0.72, 0.68, 0.50, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	_panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	_speaker_label = Label.new()
	_speaker_label.name = "Speaker"
	_speaker_label.text = ""
	_speaker_label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.50, 1.0))
	_speaker_label.add_theme_font_size_override("font_size", 18)
	stack.add_child(_speaker_label)

	_line_label = Label.new()
	_line_label.name = "Line"
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.text = ""
	_line_label.add_theme_color_override("font_color", Color(0.94, 0.95, 0.97, 1.0))
	_line_label.add_theme_font_size_override("font_size", 20)
	stack.add_child(_line_label)

	_options_box = VBoxContainer.new()
	_options_box.name = "Options"
	_options_box.add_theme_constant_override("separation", 8)
	stack.add_child(_options_box)

	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.text = "1-9 pick option  |  Enter continue  |  Esc close"
	_hint_label.add_theme_color_override("font_color", Color(0.78, 0.80, 0.85, 0.90))
	_hint_label.add_theme_font_size_override("font_size", 13)
	stack.add_child(_hint_label)


func show_dialogue(speaker: String, line_text: String, options: Array[Dictionary], view_settings: Dictionary = {}) -> void:
	_build_ui()
	visible = true
	_speaker_label.text = speaker
	_show_hints = bool(view_settings.get("show_hints", true))
	_line_reveal_rate = clampf(float(view_settings.get("line_reveal_rate", default_line_reveal_rate)), 24.0, 320.0)
	_full_line_text = line_text
	_line_reveal_accum = 0.0
	_line_reveal_index = 0
	_line_reveal_done = false
	_line_label.text = ""
	_rebuild_options(options)
	_set_options_visible(false)
	_animate_open()
	if _full_line_text.is_empty():
		_complete_line_reveal()


func close_dialogue() -> void:
	if _root_tween != null:
		_root_tween.kill()
		_root_tween = null
	if _options_tween != null:
		_options_tween.kill()
		_options_tween = null
	if _root != null:
		_root.modulate = Color(1, 1, 1, 1)
	visible = false
	_rebuild_options([])
	_full_line_text = ""
	_line_label.text = ""
	_line_reveal_done = true


func _animate_open() -> void:
	if _root == null:
		return
	if _root_tween != null:
		_root_tween.kill()
	_root.modulate = Color(1, 1, 1, 0)
	_root_tween = get_tree().create_tween()
	_root_tween.tween_property(_root, "modulate:a", 1.0, 0.12)


func _set_options_visible(show: bool) -> void:
	if _options_box == null:
		return
	_options_box.visible = show
	if _hint_label != null:
		_hint_label.visible = show and _show_hints
	if _options_tween != null:
		_options_tween.kill()
		_options_tween = null
	if not show:
		return
	_options_box.modulate = Color(1, 1, 1, 0)
	_options_tween = get_tree().create_tween()
	_options_tween.tween_property(_options_box, "modulate:a", 1.0, 0.1)
	if _hint_label != null and _hint_label.visible:
		_hint_label.modulate = Color(1, 1, 1, 0)
		_options_tween.parallel().tween_property(_hint_label, "modulate:a", 1.0, 0.1)


func _tick_line_reveal(delta: float) -> void:
	if _line_reveal_done:
		return
	if _full_line_text.is_empty():
		_complete_line_reveal()
		return
	_line_reveal_accum += _line_reveal_rate * maxf(delta, 0.0)
	var next_idx: int = mini(_full_line_text.length(), int(floor(_line_reveal_accum)))
	if next_idx == _line_reveal_index:
		return
	_line_reveal_index = next_idx
	_line_label.text = _full_line_text.substr(0, _line_reveal_index)
	if _line_reveal_index >= _full_line_text.length():
		_complete_line_reveal()


func _complete_line_reveal() -> void:
	_line_reveal_done = true
	_line_reveal_index = _full_line_text.length()
	_line_label.text = _full_line_text
	_set_options_visible(true)


func _rebuild_options(options: Array[Dictionary]) -> void:
	if _options_box == null:
		return
	for child in _options_box.get_children():
		child.queue_free()
	_option_buttons.clear()

	for i in range(options.size()):
		var option_data: Dictionary = options[i]
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if "alignment" in button:
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		elif "text_alignment" in button:
			button.text_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var choice_index: int = int(option_data.get("choice_index", i))
		var choice_text: String = String(option_data.get("text", "")).strip_edges()
		var requirement: String = String(option_data.get("requirement", "")).strip_edges()
		if choice_text.is_empty():
			choice_text = "(continue)"
		if requirement.is_empty():
			button.text = "%d. %s" % [i + 1, choice_text]
		else:
			button.text = "%d. [%s] %s" % [i + 1, requirement, choice_text]

		var enabled: bool = bool(option_data.get("enabled", true))
		button.disabled = not enabled
		var reason: String = String(option_data.get("reason", "")).strip_edges()
		if not reason.is_empty():
			button.tooltip_text = reason
		_apply_option_style(button, enabled)
		button.set_meta("choice_index", choice_index)
		button.pressed.connect(_on_option_button_pressed.bind(choice_index))
		_options_box.add_child(button)
		_option_buttons.append(button)


func _apply_option_style(button: Button, enabled: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.bg_color = Color(0.16, 0.18, 0.22, 0.95) if enabled else Color(0.12, 0.13, 0.15, 0.85)
	normal.border_color = Color(0.35, 0.37, 0.44, 0.95)

	var hover := StyleBoxFlat.new()
	hover.border_width_left = normal.border_width_left
	hover.border_width_top = normal.border_width_top
	hover.border_width_right = normal.border_width_right
	hover.border_width_bottom = normal.border_width_bottom
	hover.corner_radius_top_left = normal.corner_radius_top_left
	hover.corner_radius_top_right = normal.corner_radius_top_right
	hover.corner_radius_bottom_left = normal.corner_radius_bottom_left
	hover.corner_radius_bottom_right = normal.corner_radius_bottom_right
	hover.bg_color = Color(0.24, 0.27, 0.31, 0.98)
	hover.border_color = Color(0.84, 0.78, 0.56, 0.98)

	var pressed := StyleBoxFlat.new()
	pressed.border_width_left = normal.border_width_left
	pressed.border_width_top = normal.border_width_top
	pressed.border_width_right = normal.border_width_right
	pressed.border_width_bottom = normal.border_width_bottom
	pressed.corner_radius_top_left = normal.corner_radius_top_left
	pressed.corner_radius_top_right = normal.corner_radius_top_right
	pressed.corner_radius_bottom_left = normal.corner_radius_bottom_left
	pressed.corner_radius_bottom_right = normal.corner_radius_bottom_right
	pressed.bg_color = Color(0.14, 0.20, 0.24, 1.0)
	pressed.border_color = Color(0.90, 0.84, 0.64, 1.0)

	var disabled_style := StyleBoxFlat.new()
	disabled_style.border_width_left = normal.border_width_left
	disabled_style.border_width_top = normal.border_width_top
	disabled_style.border_width_right = normal.border_width_right
	disabled_style.border_width_bottom = normal.border_width_bottom
	disabled_style.corner_radius_top_left = normal.corner_radius_top_left
	disabled_style.corner_radius_top_right = normal.corner_radius_top_right
	disabled_style.corner_radius_bottom_left = normal.corner_radius_bottom_left
	disabled_style.corner_radius_bottom_right = normal.corner_radius_bottom_right
	disabled_style.bg_color = Color(0.10, 0.10, 0.11, 0.86)
	disabled_style.border_color = Color(0.22, 0.23, 0.25, 0.9)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.88, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.98, 0.90, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.56, 0.58, 0.63, 1.0))


func _on_option_button_pressed(choice_index: int) -> void:
	if not _line_reveal_done:
		_complete_line_reveal()
		return
	option_selected.emit(choice_index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var code: int = key_event.physical_keycode
	if code == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return

	var digit: int = _digit_from_event(key_event)
	if digit > 0:
		if not _line_reveal_done:
			_complete_line_reveal()
			get_viewport().set_input_as_handled()
			return
		var idx: int = digit - 1
		if idx >= 0 and idx < _option_buttons.size():
			var btn: Button = _option_buttons[idx]
			if btn != null and not btn.disabled:
				option_selected.emit(int(btn.get_meta("choice_index")))
				get_viewport().set_input_as_handled()
		return

	if code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
		if not _line_reveal_done:
			_complete_line_reveal()
		else:
			_emit_first_enabled_option()
		get_viewport().set_input_as_handled()


func _emit_first_enabled_option() -> void:
	for btn in _option_buttons:
		if btn != null and not btn.disabled:
			option_selected.emit(int(btn.get_meta("choice_index")))
			return


func _digit_from_event(event: InputEventKey) -> int:
	var code: int = event.physical_keycode
	match code:
		KEY_1, KEY_KP_1:
			return 1
		KEY_2, KEY_KP_2:
			return 2
		KEY_3, KEY_KP_3:
			return 3
		KEY_4, KEY_KP_4:
			return 4
		KEY_5, KEY_KP_5:
			return 5
		KEY_6, KEY_KP_6:
			return 6
		KEY_7, KEY_KP_7:
			return 7
		KEY_8, KEY_KP_8:
			return 8
		KEY_9, KEY_KP_9:
			return 9
	code = event.keycode
	match code:
		KEY_1:
			return 1
		KEY_2:
			return 2
		KEY_3:
			return 3
		KEY_4:
			return 4
		KEY_5:
			return 5
		KEY_6:
			return 6
		KEY_7:
			return 7
		KEY_8:
			return 8
		KEY_9:
			return 9
	return -1
