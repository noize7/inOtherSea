class_name PlayerCamera
extends Camera2D

@export_group("Target & Follow")
@export var target: Node2D
@export var follow_delay: float = 2.0 ## Seconds of movement before camera starts following
@export var follow_smooth_speed: float = 3.0 ## Smoothing speed (lerp)
@export var max_leash_distance: float = 380.0 ## Max distance before camera nudges to keep player on screen
@export var look_ahead_distance: float = 80.0 ## Offset in movement direction

@export_group("Offset")
@export var vertical_offset: float = -30.0 ## Frame player slightly above center

var movement_timer: float = 0.0
var is_tracking: bool = false
var last_target_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	top_level = true
	if not target and get_parent() is Node2D:
		target = get_parent()
	if target:
		global_position = target.global_position + Vector2(0.0, vertical_offset)
		last_target_pos = target.global_position

func _physics_process(delta: float) -> void:
	if not target:
		return

	var target_pos = target.global_position
	var target_velocity = Vector2.ZERO
	if target is CharacterBody2D:
		target_velocity = target.velocity
	else:
		target_velocity = (target_pos - last_target_pos) / maxf(delta, 0.001)

	var is_moving = target_velocity.length_squared() > 400.0

	# 2-second delay logic
	if is_moving:
		movement_timer += delta
		if movement_timer >= follow_delay:
			is_tracking = true
	else:
		movement_timer = 0.0
		is_tracking = true

	# Leash safety check
	var dist_to_target = global_position.distance_to(target_pos)
	if dist_to_target > max_leash_distance:
		is_tracking = true

	# Target camera position with look-ahead
	var desired_pos = target_pos + Vector2(0.0, vertical_offset)
	if is_moving and absf(target_velocity.x) > 30.0:
		desired_pos.x += signf(target_velocity.x) * look_ahead_distance

	if is_tracking:
		global_position = global_position.lerp(desired_pos, follow_smooth_speed * delta)
		if not is_moving and global_position.distance_to(desired_pos) < 1.5:
			global_position = desired_pos
			is_tracking = false

	last_target_pos = target_pos
