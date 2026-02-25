@tool
class_name FuncMove
extends AnimatableBody3D
const Util := preload("res://scripts/util.gd")

@export var targetname: String = ""
@export var move_pos: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
@export var move_rot: Vector3 = Vector3.ZERO
@export var speed: float = 3.0

enum MoveStates {
	READY,
	MOVE
}
var move_state: MoveStates = MoveStates.READY
var move_progress: float = 0.0
var move_progress_target: float = 0.0
var sfx: AudioStreamPlayer3D
var _base_rotation: Vector3 = Vector3.ZERO
var _move_pos_relative: Vector3 = Vector3.ZERO
var _move_rate: float = 0.0
var _is_ready_runtime: bool = false

const PIVOT_FALLBACK_MIN_DISTANCE: float = 0.5

func _func_godot_apply_properties(props: Dictionary) -> void:
	targetname = props["targetname"] as String
	_move_pos_relative = GameManager.id_vec_to_godot_vec(props["move_pos"]) * GameManager.INVERSE_SCALE
	if props["move_rot"] is Vector3:
		var r: Vector3 = props["move_rot"]
		for i in 3:
			move_rot[i] = deg_to_rad(r[i])
	speed = props["speed"] as float
	if _is_ready_runtime:
		_finalize_runtime_motion_state()

func mv_forward() -> void:
	move_progress_target = 1.0

func mv_reverse() -> void:
	move_progress_target = 0.0

func use() -> void:
	mv_forward()

func toggle() -> void:
	if move_progress_target > 0.0:
		mv_reverse()
	else:
		mv_forward()

func _init() -> void:
	add_to_group("func_move")
	sync_to_physics = false

func _infer_visual_center_local() -> Vector3:
	var mins: Vector3 = Vector3.INF
	var maxs: Vector3 = -Vector3.INF
	var found_mesh: bool = false
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh_instance: MeshInstance3D = child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var aabb: AABB = mesh_instance.get_aabb()
		var local_min: Vector3 = mesh_instance.position + aabb.position
		var local_max: Vector3 = local_min + aabb.size
		if mins != Vector3.INF:
			mins = mins.min(local_min)
		else:
			mins = local_min
		if maxs != -Vector3.INF:
			maxs = maxs.max(local_max)
		else:
			maxs = local_max
		found_mesh = true
	if not found_mesh:
		return Vector3.ZERO
	return maxs - ((maxs - mins) * 0.5)

func _apply_pivot_fallback_from_visuals() -> void:
	# Some imported brush entities can end up with the root left at local origin while the
	# generated mesh is offset in local-space, which causes rotation around world origin.
	if position.length_squared() > 0.000001:
		return
	var inferred_center: Vector3 = _infer_visual_center_local()
	if inferred_center.length() < PIVOT_FALLBACK_MIN_DISTANCE:
		return
	# Shift pivot to inferred center while preserving child global transforms.
	position = inferred_center
	for child in get_children():
		if child is Node3D:
			(child as Node3D).position -= inferred_center

func _finalize_runtime_motion_state() -> void:
	GAME.set_targetname(self, targetname)
	move_pos[0] = position
	move_pos[1] = move_pos[0] + _move_pos_relative
	_base_rotation = rotation
	_move_rate = 0.0 if speed <= 0.0 else (1.0 / speed)

func _ready() -> void:
	if Util.editor_hint():
		return
	
	_is_ready_runtime = true
	_apply_pivot_fallback_from_visuals()
	_finalize_runtime_motion_state()

func _physics_process(delta: float) -> void:
	if Util.editor_hint():
		return
	
	if move_progress != move_progress_target:
		if move_progress < move_progress_target:
			move_progress = minf(move_progress + _move_rate * delta, move_progress_target)
		elif move_progress > move_progress_target:
			move_progress = maxf(move_progress - _move_rate * delta, move_progress_target)
		if move_pos[0] != move_pos[1]:
			position = move_pos[0].lerp(move_pos[1], move_progress)
		if move_rot != Vector3.ZERO:
			rotation = _base_rotation.lerp(_base_rotation + move_rot, move_progress)
