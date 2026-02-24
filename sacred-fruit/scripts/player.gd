extends CharacterBody3D

signal health_changed(current: int, max_health: int, max_overhealth: int)
signal died

# Quake-ish health model
@export var max_health: int = 100
@export var max_overhealth: int = 200
@export var health: int = 100
@export var overheal_decay_per_sec: float = 5.0
@export var respawn_on_death: bool = true
@export var respawn_delay: float = 1.0

# Movement (HL2-grounded style)
@export var JUMP_HEIGHT: float = 1.0
@export var WALKING_SPEED: float = 4.5
@export var SPRINTING_SPEED: float = 7.5
@export var CROUCHING_SPEED: float = 2.2
@export var CROUCHING_DEPTH: float = -0.6
@export var GROUND_ACCELERATION: float = 22.0
@export var AIR_ACCELERATION: float = 6.0
@export var GROUND_FRICTION: float = 8.0
@export var STOP_SPEED: float = 1.8
@export var AIR_CONTROL: float = 0.22
@export var BUNNY_HOP_ACCELERATION: float = 0.12
@export var BUNNY_HOP_MAX_SPEED: float = 9.0

# Look/feel
@export var MOUSE_SENS: float = 0.25
@export var MOUSE_SMOOTHING: float = 0.0
@export var GAMEPLAY_FOV: float = 90.0
@export var FOV_MIN: float = 75.0
@export var FOV_MAX: float = 110.0
@export var LERP_SPEED: float = 10.0
@export var AIR_LERP_SPEED: float = 6.0

# Camera grounding
@export var BOB_WALK_FREQ: float = 10.0
@export var BOB_SPRINT_FREQ: float = 14.0
@export var BOB_CROUCH_FREQ: float = 7.0
@export var BOB_WALK_INTENSITY: float = 0.025
@export var BOB_SPRINT_INTENSITY: float = 0.038
@export var BOB_CROUCH_INTENSITY: float = 0.014
@export var LANDING_DIP_SCALE: float = 0.012
@export var LANDING_DIP_MAX: float = 0.08
@export var LANDING_DIP_RECOVER: float = 9.0
@export var SWAY_ROLL_MAX_DEG: float = 1.6
@export var SWAY_ROLL_SPEED: float = 8.0
@export var SWAY_STRAFE_SCALE: float = 0.015
@export_range(0.5, 8.0, 0.1) var INTERACT_DISTANCE: float = 3.2
@export_range(0.3, 5.0, 0.1) var HOLD_DISTANCE: float = 1.8
@export_range(0.0, 30.0, 0.1) var DROP_THROW_SPEED: float = 7.0
@export_range(0.0, 60.0, 0.1) var PUNT_THROW_SPEED: float = 15.0
@export var show_interact_crosshair: bool = true
@export_range(1.0, 12.0, 1.0) var crosshair_dot_size: float = 4.0
@export var crosshair_idle_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var crosshair_target_color: Color = Color(0.65, 1.0, 0.65, 0.95)
@export var crosshair_holding_color: Color = Color(1.0, 0.85, 0.45, 0.95)

# Feel helpers
@export var COYOTE_TIME: float = 0.12
@export var JUMP_BUFFER: float = 0.12

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var direction: Vector3 = Vector3.ZERO
var current_speed: float = WALKING_SPEED
var bunny_hop_speed: float = SPRINTING_SPEED

var is_walking: bool = false
var is_sprinting: bool = false
var is_crouching: bool = false

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _was_on_floor: bool = false

var _mouse_delta_accum: Vector2 = Vector2.ZERO
var _mouse_delta_filtered: Vector2 = Vector2.ZERO
var _last_frame_mouse_delta: Vector2 = Vector2.ZERO

var _bob_phase: float = 0.0
var _landing_dip: float = 0.0
var _camera_roll: float = 0.0

@onready var _neck: Node3D = $Neck
@onready var _head: Node3D = $Neck/Head
@onready var _eyes: Node3D = $Neck/Head/Eyes
@onready var _camera: Camera3D = $Neck/Head/Eyes/Camera
@onready var _standing_collision: CollisionShape3D = $StandingCollisionShape
@onready var _crouching_collision: CollisionShape3D = $CrouchingCollisionShape
@onready var _headroom_raycast: RayCast3D = $RayCast
@onready var _anim_player: AnimationPlayer = $Neck/Head/Eyes/AnimationPlayer

var _held_ball: PhysicsBall = null
var _current_interaction_target: Node = null
var _crosshair_layer: CanvasLayer = null
var _crosshair_dot: ColorRect = null


func _ready() -> void:
	add_to_group("PLAYER")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ensure_use_input_action()
	_ensure_throw_input_action()
	_ensure_interact_crosshair()

	var settings := get_node_or_null("/root/SETTINGS")
	if settings != null:
		_apply_settings_from_singleton(settings)
		if settings.has_signal("settings_applied"):
			settings.settings_applied.connect(_on_settings_applied)

	var game := get_node_or_null("/root/GAME")
	if game != null and game.has_method("register_player"):
		game.call("register_player", self)

	_emit_health_changed()


func _on_settings_applied() -> void:
	var settings := get_node_or_null("/root/SETTINGS")
	if settings != null:
		_apply_settings_from_singleton(settings)


func _apply_settings_from_singleton(settings: Node) -> void:
	if "mouse_sens" in settings:
		MOUSE_SENS = float(settings.mouse_sens)
	if "mouse_smoothing" in settings:
		MOUSE_SMOOTHING = clampf(float(settings.mouse_smoothing), 0.0, 0.25)
	if "gameplay_fov" in settings:
		GAMEPLAY_FOV = clampf(float(settings.gameplay_fov), FOV_MIN, FOV_MAX)
	if _camera != null:
		_camera.fov = GAMEPLAY_FOV


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta_accum += event.relative


func _physics_process(delta: float) -> void:
	var was_on_floor: bool = _was_on_floor
	var on_floor: bool = is_on_floor()

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_left = JUMP_BUFFER
	else:
		_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	if on_floor:
		_coyote_left = COYOTE_TIME
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)

	_update_crouch_state(delta)
	_apply_look(delta)

	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "back")
	var wish_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)

	_update_move_state(input_dir)
	var target_speed: float = _target_speed()
	current_speed = lerpf(current_speed, target_speed, clampf(delta * 8.0, 0.0, 1.0))

	if on_floor:
		horizontal_vel = _apply_friction(horizontal_vel, delta)
		horizontal_vel = _accelerate(horizontal_vel, wish_dir, current_speed, GROUND_ACCELERATION, delta)
	else:
		horizontal_vel = _accelerate(horizontal_vel, wish_dir, current_speed, AIR_ACCELERATION, delta)
		horizontal_vel = _air_control(horizontal_vel, wish_dir, input_dir.y, current_speed, delta)

	if not on_floor:
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.01

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = sqrt(2.0 * gravity * maxf(JUMP_HEIGHT, 0.01))
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		if is_sprinting and input_dir.length() > 0.0:
			bunny_hop_speed = minf(maxf(bunny_hop_speed, SPRINTING_SPEED) + BUNNY_HOP_ACCELERATION, BUNNY_HOP_MAX_SPEED)
		else:
			bunny_hop_speed = SPRINTING_SPEED
		if _anim_player != null:
			_anim_player.play("jump")
	elif on_floor and not is_sprinting:
		bunny_hop_speed = SPRINTING_SPEED

	velocity.x = horizontal_vel.x
	velocity.z = horizontal_vel.z

	var pre_move_velocity_y: float = velocity.y
	move_and_slide()
	_was_on_floor = is_on_floor()

	if _was_on_floor and not was_on_floor:
		var impact_speed: float = -pre_move_velocity_y
		if impact_speed > 0.0:
			_landing_dip = minf(LANDING_DIP_MAX, impact_speed * LANDING_DIP_SCALE)
		if impact_speed >= 5.0 and _anim_player != null:
			_anim_player.play("landing")

	_apply_camera_grounding(delta, was_on_floor)
	_update_held_ball()
	_update_interaction_target()
	_update_interact_crosshair()

	if health > max_health and overheal_decay_per_sec > 0.0:
		var new_health := maxf(float(max_health), float(health) - overheal_decay_per_sec * delta)
		var rounded := int(floor(new_health + 0.5))
		if rounded != health:
			health = rounded
			_emit_health_changed()
	if InputMap.has_action("use") and Input.is_action_just_pressed("use"):
		_handle_interact_pressed()
	if InputMap.has_action("throw_held") and Input.is_action_just_pressed("throw_held"):
		_handle_throw_pressed()


func _update_crouch_state(delta: float) -> void:
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	if not wants_crouch and _headroom_raycast.is_colliding():
		wants_crouch = true

	is_crouching = wants_crouch
	_standing_collision.disabled = wants_crouch
	_crouching_collision.disabled = not wants_crouch

	var target_head_y: float = CROUCHING_DEPTH if wants_crouch else 0.0
	_head.position.y = lerpf(_head.position.y, target_head_y, clampf(delta * LERP_SPEED, 0.0, 1.0))


func _apply_look(delta: float) -> void:
	var raw: Vector2 = _mouse_delta_accum
	_mouse_delta_accum = Vector2.ZERO

	if MOUSE_SMOOTHING <= 0.001:
		_mouse_delta_filtered = raw
	else:
		# Convert 0.00-0.25 slider to a stable smoothing rate.
		var smooth_t: float = clampf(delta / MOUSE_SMOOTHING, 0.0, 1.0)
		_mouse_delta_filtered = _mouse_delta_filtered.lerp(raw, smooth_t)

	_last_frame_mouse_delta = _mouse_delta_filtered

	rotate_y(deg_to_rad(-_mouse_delta_filtered.x * MOUSE_SENS))
	_head.rotate_x(deg_to_rad(-_mouse_delta_filtered.y * MOUSE_SENS))
	_head.rotation.x = clamp(_head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))


func _update_move_state(input_dir: Vector2) -> void:
	is_sprinting = Input.is_action_pressed("sprint") and (not is_crouching)
	is_walking = (not is_sprinting) and (not is_crouching)
	if input_dir.length() <= 0.001:
		is_sprinting = false


func _target_speed() -> float:
	if is_crouching:
		return CROUCHING_SPEED
	if is_sprinting:
		return maxf(SPRINTING_SPEED, bunny_hop_speed)
	return WALKING_SPEED


func _apply_friction(horizontal_vel: Vector3, delta: float) -> Vector3:
	var speed: float = horizontal_vel.length()
	if speed <= 0.0001:
		return Vector3.ZERO
	var control: float = maxf(speed, STOP_SPEED)
	var drop: float = control * GROUND_FRICTION * delta
	var new_speed: float = maxf(speed - drop, 0.0)
	if new_speed == speed:
		return horizontal_vel
	return horizontal_vel * (new_speed / speed)


func _accelerate(horizontal_vel: Vector3, wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> Vector3:
	if wish_dir.length_squared() <= 0.000001:
		return horizontal_vel
	var current_speed_along_wish: float = horizontal_vel.dot(wish_dir)
	var add_speed: float = wish_speed - current_speed_along_wish
	if add_speed <= 0.0:
		return horizontal_vel
	var accel_speed: float = accel * delta * wish_speed
	if accel_speed > add_speed:
		accel_speed = add_speed
	return horizontal_vel + wish_dir * accel_speed


func _air_control(horizontal_vel: Vector3, wish_dir: Vector3, forward_move: float, wish_speed: float, delta: float) -> Vector3:
	if absf(forward_move) < 0.001 or wish_speed <= 0.0:
		return horizontal_vel
	var z_speed: float = horizontal_vel.y
	horizontal_vel.y = 0.0
	var speed: float = horizontal_vel.length()
	if speed <= 0.0001:
		horizontal_vel.y = z_speed
		return horizontal_vel
	horizontal_vel = horizontal_vel.normalized()
	var dot_val: float = horizontal_vel.dot(wish_dir)
	var k: float = 32.0 * AIR_CONTROL * dot_val * dot_val * delta
	if dot_val > 0.0:
		horizontal_vel = (horizontal_vel * speed + wish_dir * k).normalized()
		horizontal_vel *= speed
	horizontal_vel.y = z_speed
	return horizontal_vel


func _apply_camera_grounding(delta: float, was_on_floor: bool) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clampf(horizontal_speed / maxf(SPRINTING_SPEED, 0.001), 0.0, 1.0)

	_landing_dip = lerpf(_landing_dip, 0.0, clampf(delta * LANDING_DIP_RECOVER, 0.0, 1.0))

	var bob_freq: float = BOB_WALK_FREQ
	var bob_intensity: float = BOB_WALK_INTENSITY
	if is_crouching:
		bob_freq = BOB_CROUCH_FREQ
		bob_intensity = BOB_CROUCH_INTENSITY
	elif is_sprinting:
		bob_freq = BOB_SPRINT_FREQ
		bob_intensity = BOB_SPRINT_INTENSITY

	if _was_on_floor and horizontal_speed > 0.1:
		_bob_phase += delta * bob_freq * (0.6 + speed_ratio)

	var bob_x: float = sin(_bob_phase * 0.5) * bob_intensity
	var bob_y: float = absf(sin(_bob_phase)) * bob_intensity * 0.6
	if not _was_on_floor:
		bob_x = 0.0
		bob_y = 0.0

	var target_eye_pos := Vector3(bob_x, bob_y - _landing_dip, 0.0)
	_eyes.position = _eyes.position.lerp(target_eye_pos, clampf(delta * (LERP_SPEED + 2.0), 0.0, 1.0))

	var local_vel: Vector3 = global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	var strafe_roll: float = clampf(-local_vel.x * SWAY_STRAFE_SCALE, deg_to_rad(-SWAY_ROLL_MAX_DEG), deg_to_rad(SWAY_ROLL_MAX_DEG))
	var mouse_roll: float = clampf(-_last_frame_mouse_delta.x * 0.0006, deg_to_rad(-SWAY_ROLL_MAX_DEG), deg_to_rad(SWAY_ROLL_MAX_DEG))
	var target_roll: float = strafe_roll + mouse_roll
	_camera_roll = lerpf(_camera_roll, target_roll, clampf(delta * SWAY_ROLL_SPEED, 0.0, 1.0))
	_camera.rotation.z = _camera_roll

	if _camera != null:
		_camera.fov = GAMEPLAY_FOV


func _on_sliding_timer_timeout() -> void:
	# Legacy signal kept for scene compatibility.
	pass


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	# Legacy signal kept for scene compatibility.
	pass


func add_health(amount: int, allow_overheal: bool = false, overheal_cap: int = 0) -> void:
	if amount <= 0:
		return
	var cap := max_health
	if allow_overheal:
		cap = max_overhealth
		if overheal_cap > 0:
			cap = min(cap, overheal_cap)
	health = clampi(health + amount, 0, cap)
	_emit_health_changed()


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health = maxi(0, int(floor(float(health) - amount + 0.5)))
	_emit_health_changed()
	if health <= 0:
		die()


func reset_health() -> void:
	health = max_health
	_emit_health_changed()


func die() -> void:
	if health > 0:
		health = 0
	_emit_health_changed()
	emit_signal("died")

	if not respawn_on_death:
		return
	# Ask GAME to respawn us (keeps logic centralized).
	var game := get_node_or_null("/root/GAME")
	if game != null and game.has_method("handle_player_death"):
		game.call("handle_player_death", self, respawn_delay)


func _emit_health_changed() -> void:
	emit_signal("health_changed", health, max_health, max_overhealth)


func _ensure_use_input_action() -> void:
	if InputMap.has_action("use"):
		return
	InputMap.add_action("use", 0.2)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("use", ev)


func _ensure_throw_input_action() -> void:
	if InputMap.has_action("throw_held"):
		return
	InputMap.add_action("throw_held", 0.2)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("throw_held", ev)


func _handle_interact_pressed() -> void:
	if _held_ball != null and is_instance_valid(_held_ball):
		_release_held_ball()
		return
	var target_node: Node = _current_interaction_target
	if target_node != null and not is_instance_valid(target_node):
		target_node = null
	if target_node == null:
		target_node = _find_interaction_target()
	if target_node == null:
		return
	if target_node.has_method("interact"):
		var result: Variant = target_node.call("interact", self)
		if result is bool and not bool(result):
			return
		if target_node is PhysicsBall and (target_node as PhysicsBall).is_held_by(self):
			_held_ball = target_node as PhysicsBall
		return
	if target_node.has_method("use"):
		target_node.call("use")


func _handle_throw_pressed() -> void:
	if _held_ball == null:
		return
	if not is_instance_valid(_held_ball) or not _held_ball.is_held_by(self):
		_held_ball = null
		return
	_throw_held_ball()


func _find_interaction_target() -> Node:
	if _camera == null:
		return null
	var world: World3D = _camera.get_world_3d()
	if world == null:
		return null
	var from: Vector3 = _camera.global_position
	var to: Vector3 = from + (-_camera.global_basis.z.normalized() * INTERACT_DISTANCE)
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.exclude = [self.get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return null
	var collider_v: Variant = hit.get("collider", null)
	if collider_v == null:
		return null
	var n: Node = collider_v as Node
	if n == null:
		return null
	var cur: Node = n
	while cur != null:
		if cur.has_method("interact") or cur.has_method("use"):
			return cur
		cur = cur.get_parent()
	return null


func _update_interaction_target() -> void:
	if _held_ball != null and is_instance_valid(_held_ball) and _held_ball.is_held_by(self):
		_current_interaction_target = _held_ball
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		_current_interaction_target = null
		return
	_current_interaction_target = _find_interaction_target()


func _update_held_ball() -> void:
	if _held_ball == null:
		return
	if not is_instance_valid(_held_ball) or not _held_ball.is_held_by(self):
		_held_ball = null
		return
	var hold_target: Vector3 = _camera.global_position + (-_camera.global_basis.z.normalized() * HOLD_DISTANCE)
	_held_ball.set_hold_target_position(hold_target)


func _release_held_ball() -> void:
	if _held_ball == null or not is_instance_valid(_held_ball):
		_held_ball = null
		return
	var drop_vel: Vector3 = -_camera.global_basis.z.normalized() * DROP_THROW_SPEED
	_held_ball.drop(drop_vel)
	_held_ball = null


func _throw_held_ball() -> void:
	if _held_ball == null or not is_instance_valid(_held_ball):
		_held_ball = null
		return
	var throw_vel: Vector3 = -_camera.global_basis.z.normalized() * PUNT_THROW_SPEED
	_held_ball.drop(throw_vel)
	_held_ball = null


func _ensure_interact_crosshair() -> void:
	if not show_interact_crosshair:
		return
	if _crosshair_layer != null and is_instance_valid(_crosshair_layer):
		return
	_crosshair_layer = CanvasLayer.new()
	_crosshair_layer.name = "InteractCrosshair"
	_crosshair_layer.layer = 10
	add_child(_crosshair_layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair_layer.add_child(root)

	_crosshair_dot = ColorRect.new()
	_crosshair_dot.name = "Dot"
	_crosshair_dot.color = crosshair_idle_color
	_crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair_dot)
	_set_crosshair_dot_size(crosshair_dot_size)


func _set_crosshair_dot_size(size_px: float) -> void:
	if _crosshair_dot == null:
		return
	var s: float = maxf(size_px, 1.0)
	_crosshair_dot.anchor_left = 0.5
	_crosshair_dot.anchor_top = 0.5
	_crosshair_dot.anchor_right = 0.5
	_crosshair_dot.anchor_bottom = 0.5
	_crosshair_dot.offset_left = -s * 0.5
	_crosshair_dot.offset_top = -s * 0.5
	_crosshair_dot.offset_right = s * 0.5
	_crosshair_dot.offset_bottom = s * 0.5


func _update_interact_crosshair() -> void:
	if _crosshair_layer == null or _crosshair_dot == null:
		return
	var active: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	_crosshair_layer.visible = active
	if not active:
		return
	if _held_ball != null and is_instance_valid(_held_ball) and _held_ball.is_held_by(self):
		_crosshair_dot.color = crosshair_holding_color
		_set_crosshair_dot_size(crosshair_dot_size + 1.0)
	elif _current_interaction_target != null:
		_crosshair_dot.color = crosshair_target_color
		_set_crosshair_dot_size(crosshair_dot_size + 1.0)
	else:
		_crosshair_dot.color = crosshair_idle_color
		_set_crosshair_dot_size(crosshair_dot_size)
