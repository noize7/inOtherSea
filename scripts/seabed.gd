class_name Seabed
extends StaticBody2D

@export_group("Dimensions")
@export var width: float = 4000.0 ## Total width matching water width
@export var margin_x: float = 120.0 ## Extra sand beyond edges
@export var bed_thickness: float = 350.0 ## Depth of sand downwards
@export var resolution: int = 160 ## Segments for smooth organic dunes

@export_group("Dunes Profile")
@export var dune_amplitude_1: float = 18.0
@export var dune_frequency_1: float = 0.006
@export var dune_amplitude_2: float = 8.0
@export var dune_frequency_2: float = 0.015

@export_group("Side Boundaries")
@export var enable_boundaries: bool = true
@export var boundary_height: float = 1800.0

@export_group("Visuals")
@export var crest_color: Color = Color(0.95, 0.88, 0.66, 0.95)
@export var crest_width: float = 4.0

@onready var sand_polygon: Polygon2D = $SandPolygon
@onready var crest_line: Line2D = $CrestLine
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var left_boundary: CollisionShape2D = $LeftBoundary
@onready var right_boundary: CollisionShape2D = $RightBoundary

func _ready() -> void:
	generate_seabed()

func generate_seabed() -> void:
	var start_x = -margin_x
	var end_x = width + margin_x
	var step_x = (end_x - start_x) / float(resolution)

	var surface_points: PackedVector2Array = []
	for i in range(resolution + 1):
		var x = start_x + i * step_x
		var y = sin(x * dune_frequency_1) * dune_amplitude_1 + sin(x * dune_frequency_2 + 1.2) * dune_amplitude_2
		surface_points.append(Vector2(x, y))

	# 1. Update CrestLine along the dune peaks
	if crest_line:
		crest_line.points = surface_points
		crest_line.default_color = crest_color
		crest_line.width = crest_width
		crest_line.joint_mode = Line2D.LINE_JOINT_ROUND
		crest_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		crest_line.end_cap_mode = Line2D.LINE_CAP_ROUND

	# 2. Build closed polygon for SandPolygon & CollisionPolygon2D
	var poly_points: PackedVector2Array = surface_points.duplicate()
	poly_points.append(Vector2(end_x, bed_thickness))
	poly_points.append(Vector2(start_x, bed_thickness))

	if sand_polygon:
		sand_polygon.polygon = poly_points

	if collision_polygon:
		collision_polygon.polygon = poly_points

	# 3. Side boundaries to keep the player inside the sea basin
	if enable_boundaries:
		if left_boundary:
			var left_shape = RectangleShape2D.new()
			left_shape.size = Vector2(80.0, boundary_height)
			left_boundary.shape = left_shape
			left_boundary.position = Vector2(start_x - 40.0, -boundary_height * 0.5 + 50.0)
			left_boundary.disabled = false
		if right_boundary:
			var right_shape = RectangleShape2D.new()
			right_shape.size = Vector2(80.0, boundary_height)
			right_boundary.shape = right_shape
			right_boundary.position = Vector2(end_x + 40.0, -boundary_height * 0.5 + 50.0)
			right_boundary.disabled = false
	else:
		if left_boundary: left_boundary.disabled = true
		if right_boundary: right_boundary.disabled = true
