@tool
class_name SkyMapController
extends Node3D
## Point entity that loads one of up to 4 TrenchBroom sky maps at runtime.
## Switch skies via logic_relay targetfunc:
##   load_sky_0 / load_sky_1 / load_sky_2 / load_sky_3 / clear_sky
##
## Sky maps should use func_illusionary brushes only (no collision).
##
## parallax_factor controls camera tracking:
##   0.0 = sky stays at entity position (camera moves relative to sky = parallax)
##   1.0 = sky follows camera exactly (classic skybox, no parallax)
##
## sky_scale is a post-build uniform scale multiplier applied to the built map node.
## Default 20 turns the ~20m citySky geometry into ~400m, enclosing any normal level.

const Util := preload("res://scripts/core/util.gd")
const FuncGodotMap := preload("res://addons/func_godot/src/map/func_godot_map.gd")
# Loaded at runtime to avoid circular dependency: map_settings → fgd_main → fgd_point → this script
var _map_settings: Resource = null

@export var targetname: String = ""
@export var enabled: bool = true
## 0.0 = sky fixed at entity world position (parallax from player movement).
## 1.0 = sky follows camera exactly (no parallax). Values in between blend.
@export_range(0.0, 1.0, 0.01) var parallax_factor: float = 0.0
## Uniform scale applied to the built sky map node after build.
## Compensates for sky map geometry being modelled at playable scale.
@export var sky_scale: float = 20.0
@export var start_sky: int = 0

@export_global_file("*.map") var sky_0: String = ""
@export_global_file("*.map") var sky_1: String = ""
@export_global_file("*.map") var sky_2: String = ""
@export_global_file("*.map") var sky_3: String = ""

var _map: FuncGodotMap = null
var _camera: Camera3D = null
var _current_index: int = -1
var _started: bool = false


func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("targetname"):
		targetname = String(props["targetname"])
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	# Legacy follow_camera bool → parallax_factor conversion.
	if props.has("follow_camera") and not props.has("parallax_factor"):
		parallax_factor = 1.0 if Util.to_bool(props["follow_camera"], true) else 0.0
	if props.has("parallax_factor"):
		parallax_factor = clampf(float(props["parallax_factor"]), 0.0, 1.0)
	if props.has("sky_scale"):
		sky_scale = maxf(float(props["sky_scale"]), 0.1)
	if props.has("start_sky"):
		start_sky = int(props["start_sky"])
	if props.has("sky_0"):
		sky_0 = String(props["sky_0"]).strip_edges()
	if props.has("sky_1"):
		sky_1 = String(props["sky_1"]).strip_edges()
	if props.has("sky_2"):
		sky_2 = String(props["sky_2"]).strip_edges()
	if props.has("sky_3"):
		sky_3 = String(props["sky_3"]).strip_edges()
	# Reset so _start() runs again with the correct properties.
	_started = false
	_start()


func _ready() -> void:
	if Util.editor_hint():
		return
	# Fallback for standalone (non-func_godot) use.
	# _func_godot_apply_properties already calls _start() when built from a map.
	if not _started:
		_start()


func _start() -> void:
	if _started:
		return
	_started = true
	if not targetname.is_empty():
		GAME.set_targetname(self, targetname)
	if enabled:
		_load_by_index(start_sky)
	set_process(enabled)


func _process(_delta: float) -> void:
	if _map == null:
		return
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return

	if parallax_factor <= 0.0:
		# Sky fixed at entity position. Camera moving relative to it = parallax.
		_map.global_position = global_position
	else:
		# XZ follows camera at the given factor. Y uses a reduced factor so the
		# horizon doesn't shift unnaturally when crouching/jumping.
		var cam := _camera.global_position
		var t := parallax_factor
		_map.global_position = Vector3(
			lerpf(global_position.x, cam.x, t),
			lerpf(global_position.y, cam.y, t * 0.4),
			lerpf(global_position.z, cam.z, t)
		)


func _get_sky_path(idx: int) -> String:
	match idx:
		0: return sky_0
		1: return sky_1
		2: return sky_2
		3: return sky_3
	return ""


func _load_by_index(idx: int) -> void:
	if not enabled:
		return
	var path := _get_sky_path(idx).strip_edges()
	if path.is_empty():
		push_warning("sky_map_controller '%s': sky_%d path is empty" % [name, idx])
		return
	if idx == _current_index and _map != null and is_instance_valid(_map):
		return
	_current_index = idx
	_clear_map()
	if _map_settings == null:
		_map_settings = load("res://tb/fgd/map_settings.tres")
	if _map_settings == null:
		push_error("sky_map_controller '%s': failed to load map_settings.tres" % name)
		return
	_map = FuncGodotMap.new()
	_map.name = "SkyMap_%d" % idx
	_map.global_map_file = path
	_map.map_settings = _map_settings
	_map.scale = Vector3.ONE * sky_scale
	add_child(_map)
	_map.build_complete.connect(_on_sky_build_complete)
	_map.build_failed.connect(
		func(): push_error("sky_map_controller '%s': build failed for sky_%d at '%s'" % [name, idx, path])
	)
	_map.verify_and_build()


func _on_sky_build_complete() -> void:
	if _map == null:
		return
	# Reapply scale in case func_godot resets it during build.
	_map.scale = Vector3.ONE * sky_scale
	_apply_sky_render_properties(_map)


## Walk all MeshInstance3D children of the built sky map and force render settings
## appropriate for a distant sky: no shadows, no GI, and unshaded fallback for any
## material that isn't already using an unshaded shader.
func _apply_sky_render_properties(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		if mi.mesh != null:
			for surf in range(mi.mesh.get_surface_count()):
				var mat: Material = mi.get_surface_override_material(surf)
				if mat == null:
					mat = mi.mesh.surface_get_material(surf)
				if mat is StandardMaterial3D:
					var sm := mat.duplicate() as StandardMaterial3D
					sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					sm.shadow_to_opacity = false
					mi.set_surface_override_material(surf, sm)
	for child in node.get_children():
		_apply_sky_render_properties(child)


func _clear_map() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
	_map = null


# ── Targetfunc-callable methods ──────────────────────────────────────────────

func load_sky_0() -> void: _load_by_index(0)
func load_sky_1() -> void: _load_by_index(1)
func load_sky_2() -> void: _load_by_index(2)
func load_sky_3() -> void: _load_by_index(3)

func clear_sky() -> void:
	_clear_map()
	_current_index = -1

func use() -> void:
	_load_by_index(start_sky)
