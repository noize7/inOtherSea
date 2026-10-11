class_name Water2D
extends Node2D

class WaterSpring:
	var height: float = 0.0
	var target_height: float = 0.0
	var velocity: float = 0.0

@export_group("Water Dimensions")
@export var water_width: float = 4000.0:
	set(val):
		water_width = maxf(val, 50.0)
		_init_simulation()
@export var water_depth: float = 1600.0:
	set(val):
		water_depth = maxf(val, 20.0)
		_setup_collision()
		_update_mesh()
@export var spring_count: int = 220:
	set(val):
		spring_count = clampi(val, 10, 400)
		_init_simulation()

@export_group("Spring Physics")
@export_range(0.005, 0.1, 0.001) var tension: float = 0.022
@export_range(0.005, 0.1, 0.001) var dampening: float = 0.026
@export_range(0.005, 0.1, 0.001) var spread: float = 0.028
@export_range(1, 12, 1) var passes: int = 8

@export_group("Ambient Waves")
@export var enable_ambient_waves: bool = true
@export_range(0.0, 15.0, 0.5) var ambient_amplitude: float = 4.0 ## Natural rolling ocean swell height
@export_range(0.2, 4.0, 0.1) var ambient_speed: float = 1.25 ## Travel speed of swells
@export_range(100.0, 1200.0, 10.0) var ambient_wavelength: float = 440.0 ## Length of primary swell wave

@export_group("Visuals")
@export var water_color: Color = Color(0.12, 0.45, 0.78, 0.75)
@export var surface_color: Color = Color(0.72, 0.94, 1.0, 0.95)
@export var surface_line_width: float = 3.5

@export_group("Effects")
@export var splash_scene: PackedScene = preload("res://scenes/objects/water_splash.tscn")

@onready var water_polygon: Polygon2D = $WaterPolygon
@onready var surface_line: Line2D = $SurfaceLine
@onready var water_area: Area2D = $WaterArea
@onready var collision_shape: CollisionShape2D = $WaterArea/CollisionShape2D

var springs: Array[WaterSpring] = []
var spring_distance: float = 0.0
var is_initialized: bool = false
var ambient_time: float = 0.0

func _ready() -> void:
	_init_simulation()
	_setup_collision()
	_setup_area_physics()
	water_area.body_entered.connect(_on_body_entered)
	water_area.body_exited.connect(_on_body_exited)
	get_tree().process_frame.connect(func(): is_initialized = true, CONNECT_ONE_SHOT)

func _init_simulation() -> void:
	springs.clear()
	spring_distance = water_width / float(spring_count - 1)
	for i in range(spring_count):
		var spring = WaterSpring.new()
		spring.height = 0.0
		spring.target_height = 0.0
		spring.velocity = 0.0
		springs.append(spring)
	_update_mesh()

func _setup_collision() -> void:
	if not collision_shape:
		return
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(water_width, water_depth)
	collision_shape.shape = rect_shape
	collision_shape.position = Vector2(water_width * 0.5, water_depth * 0.5)

func _setup_area_physics() -> void:
	if not water_area:
		return
	water_area.gravity_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	water_area.gravity = -250.0
	water_area.linear_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	water_area.linear_damp = 5.0
	water_area.angular_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	water_area.angular_damp = 3.0

func _physics_process(delta: float) -> void:
	if springs.is_empty():
		return
	
	ambient_time += delta * ambient_speed

	# 1. Update ambient swell targets across all springs
	if enable_ambient_waves:
		var k1 = TAU / ambient_wavelength
		var k2 = TAU / (ambient_wavelength * 0.44)
		var k3 = TAU / (ambient_wavelength * 0.23)
		for i in range(springs.size()):
			var wx = i * spring_distance
			var h1 = sin(wx * k1 - ambient_time) * ambient_amplitude
			var h2 = sin(wx * k2 + ambient_time * 1.35) * (ambient_amplitude * 0.35)
			var h3 = cos(wx * k3 - ambient_time * 1.8) * (ambient_amplitude * 0.15)
			springs[i].target_height = h1 + h2 + h3
	else:
		for spring in springs:
			spring.target_height = 0.0
	
	# 2. Continuous surface wake from swimming / moving bodies
	if is_initialized and water_area:
		var bodies = water_area.get_overlapping_bodies()
		for body in bodies:
			if body is FloatingPlatform:
				continue
			var body_x = body.global_position.x
			var surface_y = get_water_height_at(body_x)
			var dist_to_surface = absf(body.global_position.y - surface_y)
			if dist_to_surface < 70.0:
				var vel = Vector2.ZERO
				if "velocity" in body:
					vel = body.velocity
				elif body is RigidBody2D:
					vel = body.linear_velocity
				
				if vel.length() > 25.0:
					var local_x = to_local(body.global_position).x
					var wake_force = clampf(vel.length() * 0.008, 0.2, 1.8)
					var dir = signf(vel.y) if absf(vel.y) > 20.0 else 0.4
					splash(local_x, wake_force * dir)

	# 3. Hooke's Law for spring network
	for spring in springs:
		var x = spring.height - spring.target_height
		var loss = -dampening * spring.velocity
		var force = -tension * x + loss
		spring.velocity += force
		spring.height += spring.velocity
	
	# 4. Wave propagation between adjacent springs
	var count = springs.size()
	var left_deltas: Array[float] = []
	var right_deltas: Array[float] = []
	left_deltas.resize(count)
	right_deltas.resize(count)
	left_deltas.fill(0.0)
	right_deltas.fill(0.0)
	
	for p in range(passes):
		for i in range(count):
			if i > 0:
				left_deltas[i] = spread * (springs[i].height - springs[i - 1].height)
				springs[i - 1].velocity += left_deltas[i]
			if i < count - 1:
				right_deltas[i] = spread * (springs[i].height - springs[i + 1].height)
				springs[i + 1].velocity += right_deltas[i]
		
		for i in range(count):
			if i > 0:
				springs[i - 1].height += left_deltas[i]
			if i < count - 1:
				springs[i + 1].height += right_deltas[i]
	
	_update_mesh()

func _update_mesh() -> void:
	if not is_instance_valid(water_polygon) or not is_instance_valid(surface_line):
		return
	if springs.is_empty():
		return
	
	var surface_points: PackedVector2Array = []
	surface_points.resize(springs.size())
	for i in range(springs.size()):
		surface_points[i] = Vector2(i * spring_distance, springs[i].height)
	
	surface_line.default_color = surface_color
	surface_line.width = surface_line_width
	surface_line.points = surface_points
	
	var poly_points: PackedVector2Array = surface_points.duplicate()
	poly_points.append(Vector2(water_width, water_depth))
	poly_points.append(Vector2(0.0, water_depth))
	
	water_polygon.color = water_color
	water_polygon.polygon = poly_points

func splash(local_x: float, speed: float) -> void:
	if springs.is_empty():
		return
	if local_x < 0.0 or local_x > water_width:
		return
	var index = clampi(int(round(local_x / spring_distance)), 0, springs.size() - 1)
	springs[index].velocity += speed
	if index > 0:
		springs[index - 1].velocity += speed * 0.6
	if index < springs.size() - 1:
		springs[index + 1].velocity += speed * 0.6

func splash_at_global(global_x: float, speed: float) -> void:
	var local_x = to_local(Vector2(global_x, 0.0)).x
	splash(local_x, speed)
	if absf(speed) >= 20.0:
		emit_splash_particles(global_x, absf(speed) * 8.0, speed > 0.0)

func get_water_height_at(global_x: float) -> float:
	var local_x = to_local(Vector2(global_x, 0.0)).x
	if springs.is_empty() or local_x < 0.0 or local_x > water_width:
		return global_position.y
	var index = clampi(int(round(local_x / spring_distance)), 0, springs.size() - 1)
	return global_position.y + springs[index].height

func emit_splash_particles(global_x: float, raw_speed: float, is_entering: bool = true) -> void:
	if not is_initialized or not splash_scene:
		return
	var surface_y = get_water_height_at(global_x)
	var splash_inst = splash_scene.instantiate()
	splash_inst.global_position = Vector2(global_x, surface_y)
	if splash_inst.has_method("trigger"):
		splash_inst.trigger(raw_speed, is_entering)
	
	var parent_node = get_parent()
	if parent_node:
		parent_node.call_deferred("add_child", splash_inst)
	else:
		call_deferred("add_child", splash_inst)

func _on_body_entered(body: Node2D) -> void:
	if body is FloatingPlatform:
		return
		
	var raw_vel = 180.0
	if "velocity" in body:
		raw_vel = absf(body.velocity.y)
	elif body is RigidBody2D:
		raw_vel = absf(body.linear_velocity.y)
	
	if raw_vel >= 35.0:
		var vel_y = clampf(raw_vel * 0.08, 10.0, 35.0)
		var local_pos = to_local(body.global_position)
		splash(local_pos.x, vel_y)
		emit_splash_particles(body.global_position.x, raw_vel, true)
	
	if body.has_method("enter_water"):
		body.enter_water()

func _on_body_exited(body: Node2D) -> void:
	if body is FloatingPlatform:
		return
		
	var raw_vel = 120.0
	if "velocity" in body:
		raw_vel = absf(body.velocity.y)
	elif body is RigidBody2D:
		raw_vel = absf(body.linear_velocity.y)
	
	if raw_vel >= 35.0:
		var vel_y = -clampf(raw_vel * 0.05, 8.0, 25.0)
		var local_pos = to_local(body.global_position)
		splash(local_pos.x, vel_y)
		emit_splash_particles(body.global_position.x, raw_vel * 0.7, false)
	
	if body.has_method("exit_water"):
		body.exit_water()
