class_name Player
extends CharacterBody2D

@export_group("Movement")
@export var speed: float = 250.0
@export var jump_velocity: float = -420.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0

@export_group("Juice & Animation")
@export var base_scale: Vector2 = Vector2(0.28, 0.28)
@export var jump_stretch: Vector2 = Vector2(0.82, 1.22)
@export var land_squash: Vector2 = Vector2(1.24, 0.76)
@export var water_enter_squash: Vector2 = Vector2(1.18, 0.82)
@export var max_tilt_angle: float = 0.12 # radians (~7 degrees)

@export_group("Water Physics")
@export var water_speed: float = 180.0
@export var water_acceleration: float = 950.0
@export var water_drag: float = 650.0
@export var water_sink_speed: float = 75.0 ## Downward sinking speed when idle in water
@export var water_sink_acceleration: float = 140.0 ## Acceleration toward sinking speed when idle

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
var is_in_water: bool = false
var was_on_floor: bool = true
var was_in_water: bool = false
var idle_time: float = 0.0
var water_time: float = 0.0

# Key-driven swim rotation & state
var current_swim_angle: float = 0.0
var last_facing_right: bool = true
var is_actively_swimming: bool = false

# Coyote time & Jump buffer for responsive feel
var coyote_time: float = 0.12
var coyote_timer: float = 0.0
var jump_buffer_time: float = 0.12
var jump_buffer_timer: float = 0.0

func _ready() -> void:
	if animated_sprite:
		animated_sprite.scale = base_scale
		animated_sprite.play("idle")

func _physics_process(delta: float) -> void:
	# Update timers
	coyote_timer -= delta
	jump_buffer_timer -= delta
	idle_time += delta
	if is_in_water:
		water_time += delta
	
	if is_on_floor():
		coyote_timer = coyote_time

	# Check for Landing (Squash)
	if not was_on_floor and is_on_floor() and not is_in_water:
		var fall_impact = clampf(absf(velocity.y) / 600.0, 0.5, 1.2)
		_apply_scale_impulse(Vector2(1.0 + 0.24 * fall_impact, 1.0 - 0.24 * fall_impact))

	# Check for Entering Water (Fluid squash)
	if not was_in_water and is_in_water:
		_apply_scale_impulse(water_enter_squash)
		# Start swimming oriented in the direction entered
		if velocity.length() > 30.0:
			current_swim_angle = velocity.normalized().angle() + PI / 2.0
	
	was_on_floor = is_on_floor()
	was_in_water = is_in_water

	# Input controls (WASD, Arrow keys, Space)
	var move_left = Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var move_right = Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	var swim_up = Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var swim_down = Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var jump_just_pressed = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up") or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var space_pressed = Input.is_action_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_SPACE)

	if jump_just_pressed:
		jump_buffer_timer = jump_buffer_time

	# Movement execution
	if is_in_water:
		# Calculate swim vector purely from keys (WASD / Arrows)
		var swim_vector = Vector2.ZERO
		if move_right: swim_vector.x += 1.0
		if move_left: swim_vector.x -= 1.0
		if swim_down: swim_vector.y += 1.0
		if swim_up: swim_vector.y -= 1.0
		elif (space_pressed or jump_just_pressed) and not swim_down:
			swim_vector.y -= 1.0
			if is_on_floor() and jump_just_pressed:
				velocity.y = -220.0
				_apply_scale_impulse(Vector2(0.86, 1.18))
		
		is_actively_swimming = swim_vector != Vector2.ZERO

		if is_actively_swimming:
			swim_vector = swim_vector.normalized()
			
			# Rotation points directly towards the pressed keys:
			# "S" points DOWN (PI), "W" points UP (0), "D" points RIGHT (PI/2), "A" points LEFT (-PI/2)
			current_swim_angle = swim_vector.angle() + PI / 2.0

			if swim_vector.x > 0.05:
				last_facing_right = true
			elif swim_vector.x < -0.05:
				last_facing_right = false

			var swim_mult = 1.35 if space_pressed else 1.0
			velocity = velocity.move_toward(swim_vector * (water_speed * swim_mult), water_acceleration * delta)
			if space_pressed:
				_apply_scale_impulse(Vector2(0.88, 1.16))
		else:
			# When still (no directional input), smoothly sink downwards
			velocity.x = move_toward(velocity.x, 0.0, water_drag * delta)
			if velocity.y < water_sink_speed:
				velocity.y = move_toward(velocity.y, water_sink_speed, water_sink_acceleration * delta)
			else:
				velocity.y = move_toward(velocity.y, water_sink_speed, water_drag * delta)
		
		velocity.x = clampf(velocity.x, -water_speed * 1.5, water_speed * 1.5)
		velocity.y = clampf(velocity.y, -water_speed * 1.5, water_speed * 1.5)

	else:
		# Normal ground / air platformer physics
		if not is_on_floor():
			velocity.y += gravity * delta

		if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
			velocity.y = jump_velocity
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			_apply_scale_impulse(jump_stretch)

		var direction = 0.0
		if move_right: direction += 1.0
		if move_left: direction -= 1.0

		var target_speed = speed * direction
		var accel_rate = acceleration if direction != 0.0 else friction
		velocity.x = move_toward(velocity.x, target_speed, accel_rate * delta)

	move_and_slide()

	_update_animation_and_juice(delta)

func _apply_scale_impulse(impulse_multiplier: Vector2) -> void:
	if animated_sprite:
		animated_sprite.scale = Vector2(
			base_scale.x * impulse_multiplier.x,
			base_scale.y * impulse_multiplier.y
		)

func _update_animation_and_juice(delta: float) -> void:
	if not animated_sprite:
		return

	if is_in_water:
		# 1. Key-driven rotation when actively swimming; smoothly rights itself upright when idle/sinking
		var target_angle = current_swim_angle if is_actively_swimming else 0.0
		var rot_speed = 14.0 if is_actively_swimming else 4.5
		animated_sprite.rotation = lerp_angle(animated_sprite.rotation, target_angle, rot_speed * delta)
		animated_sprite.flip_h = not last_facing_right

		# 2. Swimming vs Idle/Sinking animation state
		if is_actively_swimming and velocity.length() > 20.0:
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
			var swim_ratio = velocity.length() / (water_speed * 0.8)
			animated_sprite.speed_scale = clampf(swim_ratio, 0.6, 1.4)
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
			animated_sprite.speed_scale = 1.0

		# 3. Fluid bobbing scale
		var water_bob = sin(water_time * 4.0) * 0.025
		var target_scale = Vector2(base_scale.x * (1.0 + water_bob * 0.5), base_scale.y * (1.0 - water_bob))
		animated_sprite.scale = animated_sprite.scale.lerp(target_scale, 14.0 * delta)
		return

	# OUTSIDE WATER:
	var direction = 0.0
	if velocity.x > 15.0: direction = 1.0
	elif velocity.x < -15.0: direction = -1.0

	# 1. Flip horizontal
	if direction > 0:
		animated_sprite.flip_h = false
		last_facing_right = true
	elif direction < 0:
		animated_sprite.flip_h = true
		last_facing_right = false

	# 2. Smoothly return rotation to upright + tilt with velocity
	var target_tilt = 0.0
	if absf(velocity.x) > 10.0:
		var normalized_vx = clampf(velocity.x / speed, -1.0, 1.0)
		target_tilt = normalized_vx * max_tilt_angle
	animated_sprite.rotation = lerp_angle(animated_sprite.rotation, target_tilt, 12.0 * delta)

	# 3. Procedural breathing scale
	var target_scale = base_scale
	if is_on_floor() and absf(velocity.x) < 10.0:
		var breath = sin(idle_time * 3.5) * 0.02
		target_scale = Vector2(base_scale.x * (1.0 - breath * 0.5), base_scale.y * (1.0 + breath))

	animated_sprite.scale = animated_sprite.scale.lerp(target_scale, 14.0 * delta)

	# 4. State Animation & Posing
	if not is_on_floor():
		if animated_sprite.animation != "jump":
			animated_sprite.play("jump")
		
		if velocity.y < -150.0:
			animated_sprite.frame = 1
		elif velocity.y < 80.0:
			animated_sprite.frame = 2
		else:
			animated_sprite.frame = 3
		animated_sprite.pause()
		animated_sprite.speed_scale = 1.0

	elif absf(velocity.x) > 10.0:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
		else:
			animated_sprite.play()
		var speed_ratio = absf(velocity.x) / (speed * 0.8)
		animated_sprite.speed_scale = clampf(speed_ratio, 0.6, 1.35)

	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		else:
			animated_sprite.play()
		animated_sprite.speed_scale = 1.0

func enter_water() -> void:
	is_in_water = true

func exit_water() -> void:
	is_in_water = false
