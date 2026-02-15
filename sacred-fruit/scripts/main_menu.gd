extends Control

@export var start_scene_path: String = "res://scenes/HOME_play.tscn"
@export var options_scene_path: String = "res://scenes/ui/options_menu.tscn"

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	# Focus for keyboard/controller navigation
	if play_button:
		play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()


func _on_play_pressed() -> void:
	if start_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(start_scene_path)


func _on_options_pressed() -> void:
	if options_scene_path.is_empty():
		return
	get_tree().change_scene_to_file(options_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
