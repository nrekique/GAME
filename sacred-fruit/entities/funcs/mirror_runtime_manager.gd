class_name MirrorRuntimeManager
extends Node

const SCORE_NEG_INF: float = -1.0e20

var max_active_mirrors: int = 4
var refresh_seconds: float = 0.08
var min_runtime_priority: float = 0.0

var _mirrors: Array = []
var _active_by_id: Dictionary = {}
var _refresh_accum: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum < refresh_seconds:
		return
	_refresh_accum = 0.0
	_refresh_active_set()


func configure(max_active: int, refresh_s: float, min_priority: float = 0.0) -> void:
	max_active_mirrors = maxi(1, max_active)
	refresh_seconds = clampf(refresh_s, 0.02, 0.5)
	min_runtime_priority = clampf(min_priority, 0.0, 4.0)


func register_mirror(mirror: Node, max_active: int, refresh_s: float, min_priority: float = 0.0) -> void:
	if mirror == null:
		return
	configure(max_active, refresh_s, min_priority)
	if _mirrors.has(mirror):
		return
	_mirrors.append(mirror)
	_refresh_active_set()


func unregister_mirror(mirror: Node) -> void:
	if mirror == null:
		return
	_mirrors.erase(mirror)
	_active_by_id.erase(mirror.get_instance_id())


func is_mirror_render_active(mirror: Node) -> bool:
	if mirror == null:
		return true
	if _mirrors.size() <= max_active_mirrors:
		return true
	return _active_by_id.has(mirror.get_instance_id())


func get_total_count() -> int:
	_prune_dead_mirrors()
	return _mirrors.size()


func get_active_count() -> int:
	_prune_dead_mirrors()
	return _active_by_id.size() if _mirrors.size() > max_active_mirrors else _mirrors.size()


func _refresh_active_set() -> void:
	_prune_dead_mirrors()
	_active_by_id.clear()
	if _mirrors.is_empty():
		return
	if _mirrors.size() <= max_active_mirrors:
		for m in _mirrors:
			_active_by_id[m.get_instance_id()] = true
		return

	var cam: Camera3D = _find_runtime_camera()
	if cam == null:
		for m in _mirrors:
			_active_by_id[m.get_instance_id()] = true
		return

	var scored: Array = []
	for m in _mirrors:
		var score_v: Variant = m.call("mirror_runtime_priority", cam)
		var score: float = float(score_v)
		if score <= SCORE_NEG_INF * 0.5 or score < min_runtime_priority:
			continue
		scored.append({"id": m.get_instance_id(), "score": score})
	if scored.is_empty():
		# Nothing is eligible this refresh (offscreen/occluded/low-priority).
		# Keep all mirror rendering disabled instead of re-enabling everything.
		return

	scored.sort_custom(_sort_score_desc)
	var keep: int = mini(max_active_mirrors, scored.size())
	for i in range(keep):
		var entry: Dictionary = scored[i] as Dictionary
		_active_by_id[int(entry.get("id", -1))] = true


func _prune_dead_mirrors() -> void:
	var kept: Array = []
	for m in _mirrors:
		if is_instance_valid(m):
			kept.append(m)
	_mirrors = kept


func _find_runtime_camera() -> Camera3D:
	for m in _mirrors:
		if not is_instance_valid(m):
			continue
		if not (m is Node):
			continue
		var mirror_node: Node = m as Node
		var vp: Viewport = mirror_node.get_viewport()
		if vp == null:
			continue
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null:
			return cam
	return null


func _sort_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", SCORE_NEG_INF)) > float(b.get("score", SCORE_NEG_INF))
