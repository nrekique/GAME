@tool
class_name AIWaveSpawner
extends Node3D
const Util := preload("res://scripts/core/util.gd")
const DEFAULT_NPC_SCENE: PackedScene = preload("res://entities/actors/npc/npc.tscn")
const ALLOWED_NPC_SCENE_ROOTS: Array[String] = [
	"res://entities/",
	"res://scenes/",
	"res://tb/"
]

@export var enabled: bool = true
@export var wave_id: String = "default"
@export var squad_id: String = ""
@export var npc_scene: PackedScene
@export var npc_scene_path: String = ""
@export var spawn_on_ready: bool = true
@export_range(0.1, 60.0, 0.01) var spawn_interval: float = 1.0
@export_range(1, 128, 1) var max_alive: int = 4
@export_range(1, 512, 1) var total_spawn_limit: int = 16

var _alive: Array[Node] = []
var _spawned_total: int = 0
var _time_to_next_spawn: float = 0.0
var _point_next_ready: Dictionary = {}
var _point_spawn_counts: Dictionary = {}

func _ready() -> void:
	if Util.editor_hint():
		return
	if spawn_on_ready and enabled:
		set_process(true)
		_time_to_next_spawn = 0.0

func _process(delta: float) -> void:
	if not enabled:
		return
	_prune_dead()
	if _spawned_total >= total_spawn_limit:
		return
	if _alive.size() >= max_alive:
		return
	_time_to_next_spawn -= delta
	if _time_to_next_spawn > 0.0:
		return
	if _spawn_one():
		_time_to_next_spawn = spawn_interval
	else:
		_time_to_next_spawn = minf(spawn_interval, 0.5)

func trigger_wave() -> void:
	enabled = true
	set_process(true)
	_time_to_next_spawn = 0.0

func stop_wave() -> void:
	enabled = false

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("enabled"):
		enabled = Util.to_bool(props["enabled"], enabled)
	if props.has("wave_id"):
		wave_id = String(props["wave_id"]).strip_edges()
	if props.has("squad_id"):
		squad_id = String(props["squad_id"]).strip_edges()
	if props.has("npc_scene"):
		npc_scene_path = String(props["npc_scene"]).strip_edges()
	if props.has("spawn_on_ready"):
		spawn_on_ready = Util.to_bool(props["spawn_on_ready"], spawn_on_ready)
	if props.has("spawn_interval"):
		spawn_interval = maxf(float(props["spawn_interval"]), 0.1)
	if props.has("max_alive"):
		max_alive = maxi(1, int(props["max_alive"]))
	if props.has("total_spawn_limit"):
		total_spawn_limit = maxi(1, int(props["total_spawn_limit"]))
	_try_load_npc_scene_from_path()

func _spawn_one() -> bool:
	var scene_to_spawn := _resolve_npc_scene()
	if scene_to_spawn == null:
		return false
	if not Engine.has_singleton("GAME") or not GAME.has_method("get_ai_spawn_wave_points"):
		return false
	var points_var: Variant = GAME.call("get_ai_spawn_wave_points", wave_id, squad_id)
	if not (points_var is Array):
		return false
	var points := points_var as Array
	if points.is_empty():
		return false
	var now := Time.get_ticks_msec() / 1000.0
	for p in points:
		if not (p is Node3D):
			continue
		var point := p as Node3D
		var pid := point.get_instance_id()
		var point_spawned := int(_point_spawn_counts.get(pid, 0))
		var point_max := maxi(1, int(Util.get_node_prop(point, "max_spawn_count", 1)))
		if point_spawned >= point_max:
			continue
		var ready_at := float(_point_next_ready.get(pid, 0.0))
		if now < ready_at:
			continue
		if Engine.has_singleton("GAME") and GAME.has_method("is_spawn_blocked"):
			if bool(GAME.call("is_spawn_blocked", point.global_position)):
				continue
		var inst := scene_to_spawn.instantiate()
		if not (inst is Node3D):
			if inst:
				inst.queue_free()
			continue
		var npc := inst as Node3D
		npc.global_position = point.global_position
		npc.global_rotation = point.global_rotation
		var parent_node: Node = get_tree().current_scene
		if parent_node == null:
			parent_node = get_parent()
		if parent_node == null:
			parent_node = self
		parent_node.add_child(npc)
		_alive.append(npc)
		_spawned_total += 1
		_point_spawn_counts[pid] = point_spawned + 1
		var point_cooldown: float = maxf(float(Util.get_node_prop(point, "cooldown", 0.0)), 0.0)
		_point_next_ready[pid] = now + point_cooldown
		return true
	return false

func _prune_dead() -> void:
	var kept: Array[Node] = []
	for n in _alive:
		if n != null and is_instance_valid(n):
			kept.append(n)
	_alive = kept

func _resolve_npc_scene() -> PackedScene:
	if npc_scene != null:
		return npc_scene
	_try_load_npc_scene_from_path()
	if npc_scene != null:
		return npc_scene
	return DEFAULT_NPC_SCENE

func _try_load_npc_scene_from_path() -> void:
	var path := Util.sanitize_allowed_resource_path(npc_scene_path, ALLOWED_NPC_SCENE_ROOTS, ".tscn")
	if path.is_empty():
		if not npc_scene_path.strip_edges().is_empty():
			push_warning("ai_wave_spawner '%s' rejected npc_scene outside allowlist: %s" % [name, npc_scene_path])
		return
	var loaded: Variant = load(path)
	if loaded is PackedScene:
		npc_scene = loaded as PackedScene
