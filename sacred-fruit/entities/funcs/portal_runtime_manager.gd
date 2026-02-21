class_name PortalRuntimeManager
extends Node

const SCORE_NEG_INF: float = -1.0e20

var max_active_portals: int = 8
var refresh_seconds: float = 0.08
var min_runtime_priority: float = 0.0

var _portals: Array = []
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
	max_active_portals = maxi(1, max_active)
	refresh_seconds = clampf(refresh_s, 0.02, 0.5)
	min_runtime_priority = clampf(min_priority, 0.0, 4.0)


func register_portal(portal: Node, max_active: int, refresh_s: float, min_priority: float = 0.0) -> void:
	if portal == null:
		return
	configure(max_active, refresh_s, min_priority)
	if _portals.has(portal):
		return
	_portals.append(portal)
	_refresh_active_set()


func unregister_portal(portal: Node) -> void:
	if portal == null:
		return
	_portals.erase(portal)
	_active_by_id.erase(portal.get_instance_id())


func is_portal_render_active(portal: Node) -> bool:
	if portal == null:
		return true
	if _portals.size() <= max_active_portals:
		return true
	return _active_by_id.has(portal.get_instance_id())


func get_total_count() -> int:
	_prune_dead_portals()
	return _portals.size()


func get_active_count() -> int:
	_prune_dead_portals()
	return _active_by_id.size() if _portals.size() > max_active_portals else _portals.size()


func _refresh_active_set() -> void:
	_prune_dead_portals()
	_active_by_id.clear()
	if _portals.is_empty():
		return
	if _portals.size() <= max_active_portals:
		for p in _portals:
			_active_by_id[p.get_instance_id()] = true
		return

	var cam := _find_runtime_camera()
	if cam == null:
		for p in _portals:
			_active_by_id[p.get_instance_id()] = true
		return

	var scored: Array = []
	for p in _portals:
		var score: float = p.portal_runtime_priority(cam)
		if score <= SCORE_NEG_INF * 0.5 or score < min_runtime_priority:
			continue
		scored.append({"id": p.get_instance_id(), "score": score})
	if scored.is_empty():
		# Nothing is eligible this refresh (offscreen/occluded/low-priority).
		# Keep all portal rendering disabled instead of re-enabling everything.
		return

	scored.sort_custom(_sort_score_desc)
	var keep: int = mini(max_active_portals, scored.size())
	for i in range(keep):
		var entry: Dictionary = scored[i] as Dictionary
		_active_by_id[int(entry.get("id", -1))] = true


func _prune_dead_portals() -> void:
	var kept: Array = []
	for p in _portals:
		if is_instance_valid(p):
			kept.append(p)
	_portals = kept


func _find_runtime_camera() -> Camera3D:
	for p in _portals:
		if not is_instance_valid(p):
			continue
		var cam: Camera3D = p.get_viewport().get_camera_3d()
		if cam != null:
			return cam
	return null


func _sort_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", SCORE_NEG_INF)) > float(b.get("score", SCORE_NEG_INF))
