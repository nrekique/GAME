extends Node3D

func _ready():
	set_process(true)

func _process(_delta):
	if Input.is_action_pressed("key_exit"):
		get_tree().quit()
