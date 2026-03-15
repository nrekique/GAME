@tool
class_name TriggerChangeLevel
extends Area3D
const Util := preload("res://scripts/core/util.gd")

@export var map_path: String = ""
@export var delay: float = 0.0
@export var targetname: String = ""

const ALLOWED_SCENE_ROOTS: Array[String] = [
	"res://scenes/",
	"res://tb/",
	"res://entities/"
]

var _used: bool = false

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("map"):
		map_path = Util.sanitize_allowed_resource_path(String(props["map"]), ALLOWED_SCENE_ROOTS, ".tscn")
	elif props.has("map_path"):
		map_path = Util.sanitize_allowed_resource_path(String(props["map_path"]), ALLOWED_SCENE_ROOTS, ".tscn")
	if props.has("delay"):
		delay = props["delay"] as float
	if props.has("targetname"):
		targetname = props["targetname"] as String
	if (props.has("map") or props.has("map_path")) and map_path.is_empty():
		push_warning("trigger_changelevel '%s' rejected map_path outside allowlist" % name)

func _init() -> void:
	monitoring = true
	monitorable = false
	connect("body_entered", _on_body_entered)

func _ready() -> void:
	if Util.editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)

func _on_body_entered(body: Node) -> void:
	if Util.editor_hint() or _used:
		return
	if body != null and body.is_in_group("PLAYER"):
			_used = true
			if delay > 0.0:
				await get_tree().create_timer(delay).timeout
			var safe_scene := Util.sanitize_allowed_resource_path(map_path, ALLOWED_SCENE_ROOTS, ".tscn")
			if safe_scene != "":
				get_tree().change_scene_to_file(safe_scene)
