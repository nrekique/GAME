extends Node


var _player: AnimationPlayer
var _btn_dolly_in: Button
var _btn_dolly_out: Button
var _container_btn: Control
var _label_info: Label
var _label_info_cam: Label
var _dolly_controller: DollyEffectController
var _camera: Camera3D



func _ready() -> void:
	_player = $AnimationPlayer
	_btn_dolly_in = $Control/HBoxContainer/VBoxContainer/ContainerBtn/Button_Dolly_In
	_btn_dolly_out = $Control/HBoxContainer/VBoxContainer/ContainerBtn/Button_Dolly_Out
	_container_btn = $Control/HBoxContainer/VBoxContainer/ContainerBtn
	_label_info = $Control/HBoxContainer/VBoxContainer/Label_Info
	_label_info_cam = $Control/HBoxContainer/VBoxContainer/Label_Info_Cam
	_dolly_controller = $Scene3d/Camera3D/DollyEffectController
	_camera = $Scene3d/Camera3D
	
	if _btn_dolly_in:
		_btn_dolly_in.pressed.connect(_on_btn_dolly_in_pressed)
		_btn_dolly_in.visible = true
	
	if _btn_dolly_out:
		_btn_dolly_out.pressed.connect(_on_btn_dolly_out_pressed)
		_btn_dolly_out.visible = false
	
	if _player:
		_player.animation_started.connect(_on_player_animation_started)
		_player.animation_finished.connect(_on_player_animation_finished)


func _process(delta: float) -> void:
	if _label_info and _dolly_controller:
		_label_info.text = str(_dolly_controller)
	
	if _camera and _label_info_cam:
		_label_info_cam.text = "[Camera info]\n"
		_label_info_cam.text += "- current FOV : " + str(_camera.fov) + "\n"
		_label_info_cam.text += "- near : " + str(_camera.near) + "\n"


func _on_btn_dolly_in_pressed() -> void:
	if _player:
		_player.play("dolly_in")
		_btn_dolly_in.visible = false
		_btn_dolly_out.visible = true


func _on_btn_dolly_out_pressed() -> void:
	if _player:
		_player.play("dolly_out")
		_btn_dolly_in.visible = true
		_btn_dolly_out.visible = false


func _on_player_animation_started(anim: String) -> void:
	if _container_btn:
		_container_btn.visible = false


func _on_player_animation_finished(anim: String) -> void:
	if _container_btn:
		_container_btn.visible = true
