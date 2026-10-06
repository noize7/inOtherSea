class_name WaterRock
extends RigidBody2D

@export var radius: float = 12.0
@export var rock_color: Color = Color(0.45, 0.48, 0.52)
@export var rock_outline: Color = Color(0.25, 0.28, 0.32)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, rock_color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, rock_outline, 2.0, true)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, Color(0.7, 0.72, 0.75, 0.8))

func _physics_process(_delta: float) -> void:
	if global_position.y > 1200.0:
		queue_free()
