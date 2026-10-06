class_name SkyBackground
extends Node2D

@export var follow_camera_x: bool = true

func _process(_delta: float) -> void:
	if follow_camera_x:
		var cam = get_viewport().get_camera_2d()
		if cam:
			global_position.x = cam.global_position.x
