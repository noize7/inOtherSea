class_name WaterSplashEffect
extends Node2D

@onready var spray_particles: CPUParticles2D = $SprayParticles
@onready var mist_particles: CPUParticles2D = $MistParticles
@onready var bubble_particles: CPUParticles2D = $BubbleParticles

var impact_speed: float = 25.0
var is_entering: bool = true

func trigger(speed: float = 25.0, entering: bool = true) -> void:
	impact_speed = speed
	is_entering = entering
	if is_node_ready():
		_play_effect()

func _ready() -> void:
	_play_effect()
	var tween = create_tween()
	if tween:
		tween.tween_interval(1.0)
		tween.tween_callback(queue_free)

func _play_effect() -> void:
	var intensity = clampf(absf(impact_speed) / 200.0, 0.6, 2.0)
	
	if spray_particles:
		spray_particles.initial_velocity_min = 200.0 * intensity
		spray_particles.initial_velocity_max = 380.0 * intensity
		spray_particles.amount = clampi(int(18 * clampf(intensity, 0.7, 1.6)), 10, 36)
		spray_particles.restart()
		spray_particles.emitting = true
		
	if mist_particles:
		mist_particles.initial_velocity_min = 80.0 * intensity
		mist_particles.initial_velocity_max = 170.0 * intensity
		mist_particles.amount = clampi(int(14 * clampf(intensity, 0.7, 1.6)), 8, 28)
		mist_particles.restart()
		mist_particles.emitting = true

	if bubble_particles and is_entering:
		bubble_particles.initial_velocity_min = 70.0 * intensity
		bubble_particles.initial_velocity_max = 160.0 * intensity
		bubble_particles.amount = clampi(int(12 * clampf(intensity, 0.7, 1.6)), 6, 24)
		bubble_particles.restart()
		bubble_particles.emitting = true
	elif bubble_particles:
		bubble_particles.emitting = false
