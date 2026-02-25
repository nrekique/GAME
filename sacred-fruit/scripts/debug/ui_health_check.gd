extends Control

const SCENES := {
	"Main Menu": {
		"path": "res://scenes/ui/main_menu.tscn",
		"expected": [
			"Background",
			"Center",
			"Center/Panel",
			"Center/Panel/Margin",
			"Center/Panel/Margin/VBox",
			"Center/Panel/Margin/VBox/Title",
			"Center/Panel/Margin/VBox/PlayButton",
			"Center/Panel/Margin/VBox/OptionsButton",
			"Center/Panel/Margin/VBox/QuitButton"
		]
	},
	"Options Menu": {
		"path": "res://scenes/ui/options_menu.tscn",
		"expected": [
			"Background",
			"Center",
			"Center/Panel",
			"Center/Panel/Margin",
			"Center/Panel/Margin/VBox",
			"Center/Panel/Margin/VBox/Title",
			"Center/Panel/Margin/VBox/Grid",
			"Center/Panel/Margin/VBox/AudioGrid",
			"Center/Panel/Margin/VBox/ControlsGrid",
			"Center/Panel/Margin/VBox/Buttons"
		]
	},
	"Photo Mode": {
		"path": "res://scenes/photo_mode.tscn",
		"expected": [
			"PhotoCamera",
			"WorldEnvironment",
			"LightRig",
			"CanvasLayer",
			"CanvasLayer/PhotoUI",
			"CanvasLayer/PhotoUI/Panel",
			"CanvasLayer/PhotoUI/Panel/Margin",
			"CanvasLayer/PhotoUI/Panel/Margin/VBox",
			"CanvasLayer/PhotoUI/Panel/Margin/VBox/Status",
			"CanvasLayer/PhotoUI/Panel/Margin/VBox/PassesGrid",
			"CanvasLayer/PhotoUI/Panel/Margin/VBox/LightRigGrid"
		]
	},
	"Debug Menu": {
		"path": "res://scenes/ui/debug_menu.tscn",
		"expected": [
			"Backdrop",
			"Center",
			"Center/Panel",
			"Center/Panel/Margin",
			"Center/Panel/Margin/VBox",
			"Center/Panel/Margin/VBox/MapList",
			"Center/Panel/Margin/VBox/Status"
		]
	}
}

@onready var results: RichTextLabel = $Panel/Margin/VBox/Results
@onready var run_button: Button = $Panel/Margin/VBox/Buttons/RunButton
@onready var back_button: Button = $Panel/Margin/VBox/Buttons/BackButton


func _ready() -> void:
	run_button.pressed.connect(_run_audit)
	back_button.pressed.connect(_back_to_menu)
	_run_audit()


func _run_audit() -> void:
	results.clear()
	_add_line("[b]UI Health Check[/b]")
	for label in SCENES.keys():
		var entry: Dictionary = SCENES[label]
		_add_line("\n[b]" + label + "[/b]")
		var ok := _check_scene(entry["path"], entry["expected"])
		_add_line("Result: " + ("OK" if ok else "Issues found"))


func _check_scene(scene_path: String, expected_paths: Array) -> bool:
	if not ResourceLoader.exists(scene_path):
		_add_line("  [color=#ff8888]Missing scene: " + scene_path + "[/color]")
		return false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_add_line("  [color=#ff8888]Failed to load scene[/color]")
		return false
	var inst := packed.instantiate()
	var ok := true
	for p in expected_paths:
		if inst.get_node_or_null(p) == null:
			ok = false
			var hint := _find_by_substring(inst, p.get_file())
			if hint.is_empty():
				_add_line("  [color=#ff8888]Missing:[/color] " + p)
			else:
				_add_line("  [color=#ffcc66]Missing:[/color] " + p + " (found name match: " + hint + ")")
	inst.queue_free()
	return ok


func _find_by_substring(root: Node, name_hint: String) -> String:
	for n in root.find_children("*", "", true, false):
		if String(n.name).find(name_hint) != -1:
			return n.get_path()
	return ""


func _add_line(text: String) -> void:
	results.append_text(text + "\n")


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
