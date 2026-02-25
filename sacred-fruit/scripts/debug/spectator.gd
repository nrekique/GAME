extends Node3D

@export var move_speed: float = 12.0
@export var fast_multiplier: float = 3.0
@export var mouse_sens: float = 0.25

var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _camera:
		_camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sens
		_pitch = clamp(_pitch - event.relative.y * mouse_sens, -89.0, 89.0)
		rotation_degrees.y = _yaw
		if _camera:
			_camera.rotation_degrees.x = _pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var input_vec := Input.get_vector("left", "right", "forward", "back")
	var dir := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
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
	global_position += vel * speed * delta
