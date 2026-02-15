extends Control

@export var back_scene_path: String = "res://scenes/ui/main_menu.tscn"

@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var resolution_option: OptionButton = %ResolutionOption

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sens_slider: HSlider = %SensSlider

@onready var apply_button: Button = %ApplyButton
@onready var back_button: Button = %BackButton

var _resolutions: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]


func _ready() -> void:
	_fill_resolution_options()
	_load_from_settings()

	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)

	# Sensible focus
	back_button.grab_focus()


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

	fullscreen_check.button_pressed = s.fullscreen
	vsync_check.button_pressed = s.vsync

	master_slider.value = float(s.master_volume)
	music_slider.value = float(s.music_volume)
	sfx_slider.value = float(s.sfx_volume)
	sens_slider.value = float(s.mouse_sens)

	_select_resolution(s.window_size)


func _select_resolution(size: Vector2i) -> void:
	if resolution_option == null:
		return
	var best := 0
	for i in range(_resolutions.size()):
		if _resolutions[i] == size:
			best = i
			break
	resolution_option.select(best)


func _on_apply_pressed() -> void:
	var s := get_node_or_null("/root/SETTINGS")
	if s == null:
		return

	s.fullscreen = fullscreen_check.button_pressed
	s.vsync = vsync_check.button_pressed

	var idx := resolution_option.selected
	if idx >= 0 and idx < _resolutions.size():
		s.window_size = _resolutions[idx]

	s.master_volume = float(master_slider.value)
	s.music_volume = float(music_slider.value)
	s.sfx_volume = float(sfx_slider.value)
	s.mouse_sens = float(sens_slider.value)

	if s.has_method("apply_and_save"):
		s.call("apply_and_save")


func _on_back_pressed() -> void:
	if back_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(back_scene_path)
