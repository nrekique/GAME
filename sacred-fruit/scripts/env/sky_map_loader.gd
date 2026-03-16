extends Node3D
## Loads and builds a TrenchBroom .map file as a background sky scene.
## Intended to be instantiated by env_sky_scene, which handles camera-following.
## Point sky_map_path at a .map file (absolute/global path).
## Use func_illusionary brushes in the sky map so there is no collision.

const FuncGodotMap := preload("res://addons/func_godot/src/map/func_godot_map.gd")
const MAP_SETTINGS := preload("res://tb/fgd/map_settings.tres")

@export_global_file("*.map") var sky_map_path: String = ""

var _map: FuncGodotMap = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if sky_map_path.is_empty():
		push_warning("sky_map_loader: sky_map_path is not set")
		return
	_build()


func _build() -> void:
	_map = FuncGodotMap.new()
	_map.name = "SkyMap"
	_map.global_map_file = sky_map_path
	_map.map_settings = MAP_SETTINGS
	add_child(_map)
	_map.build_complete.connect(_on_build_complete)
	_map.build_failed.connect(_on_build_failed)
	_map.verify_and_build()


func _on_build_complete() -> void:
	pass


func _on_build_failed() -> void:
	push_error("sky_map_loader: failed to build sky map at '%s'" % sky_map_path)
