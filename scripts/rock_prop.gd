class_name RockProp
extends StaticBody2D

@export var has_collision: bool = true:
	set(val):
		has_collision = val
		if is_node_ready() and collision_polygon:
			collision_polygon.disabled = not has_collision

@export var flip_h: bool = false:
	set(val):
		flip_h = val
		if is_node_ready():
			_update_flip()

@export var tint: Color = Color.WHITE:
	set(val):
		tint = val
		if is_node_ready() and sprite:
			sprite.modulate = tint

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

func _ready() -> void:
	if collision_polygon:
		collision_polygon.disabled = not has_collision
	if sprite:
		sprite.modulate = tint
	_update_flip()

func _update_flip() -> void:
	if sprite:
		sprite.flip_h = flip_h
	if collision_polygon:
		collision_polygon.scale.x = -1.0 if flip_h else 1.0
