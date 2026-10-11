class_name FloatingPlatform
extends RigidBody2D

@export var water: Water2D
@export var default_surface_y: float = 540.0
@export var float_depth: float = 2.0 ## Submerged depth in pixels at equilibrium (rests on water from its base)
@export var buoyancy_stiffness: float = 55.0 ## Upward spring restoration
@export var water_damping: float = 8.0 ## Vertical drag in fluid to stop oscillation
@export var lateral_drag: float = 3.0 ## Horizontal drag in water

var half_height: float = 20.0
var half_width: float = 200.0
var was_submerged: bool = false

func _ready() -> void:
	# Lock rotation in physics so solver doesn't tumble, we smoothly tilt visually/kinematically
	lock_rotation = true
	if not water:
		water = get_tree().get_first_node_in_group("water")
		if not water:
			water = get_parent().get_node_or_null("Water2D")

func _physics_process(delta: float) -> void:
	var surface_y = default_surface_y
	if is_instance_valid(water):
		surface_y = water.get_water_height_at(global_position.x)

	var platform_bottom = global_position.y + half_height
	var is_submerged = platform_bottom > surface_y

	if is_submerged:
		# Equilibrium target: base sits right at the water surface
		var target_y = surface_y - half_height + float_depth
		var displacement = global_position.y - target_y
		
		# Hooke's Law buoyancy spring
		var spring_force = -displacement * buoyancy_stiffness * mass
		# Hydrodynamic damping
		var damping_force = -linear_velocity.y * water_damping * mass
		apply_central_force(Vector2(0.0, spring_force + damping_force))

		# Lateral water friction
		apply_central_force(Vector2(-linear_velocity.x * lateral_drag * mass, 0.0))

		# Subtle realistic rocking with wave slope (kept small for stability)
		if is_instance_valid(water):
			var left_y = water.get_water_height_at(global_position.x - half_width * 0.75)
			var right_y = water.get_water_height_at(global_position.x + half_width * 0.75)
			var wave_slope = (right_y - left_y) / (half_width * 1.5)
			var target_rot = clampf(wave_slope * 0.6, -0.04, 0.04)
			rotation = lerp_angle(rotation, target_rot, 4.5 * delta)

			# Continuous gentle ripple displacement when moving
			if absf(linear_velocity.y) > 2.0:
				var wave_speed = clampf(linear_velocity.y * 0.015, -4.0, 4.0)
				water.splash_at_global(global_position.x - half_width * 0.7, wave_speed)
				water.splash_at_global(global_position.x + half_width * 0.7, wave_speed)

	was_submerged = is_submerged
