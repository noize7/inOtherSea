class_name Seabed
extends StaticBody2D

class KelpStrand:
	var line: Line2D
	var base_pts: PackedVector2Array = []
	var sway_speed: float = 1.6
	var phase: float = 0.0
	var max_sway: float = 18.0

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

@export_group("Marine Vegetation")
@export var enable_kelp: bool = true
@export var kelp_clump_count: int = 26
@export var kelp_base_color: Color = Color(0.10, 0.44, 0.36, 0.90)
@export var kelp_tip_color: Color = Color(0.20, 0.68, 0.52, 0.95)

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

var kelp_strands: Array[KelpStrand] = []
var kelp_container: Node2D
var anim_time: float = 0.0

func _ready() -> void:
	generate_seabed()

func _process(delta: float) -> void:
	if kelp_strands.is_empty():
		return
	
	anim_time += delta
	for strand in kelp_strands:
		var pts = strand.line.points
		var count = pts.size()
		for i in range(1, count):
			var ratio = float(i) / float(count - 1)
			# Quadratic sway increasing towards the tip
			var wave = sin(anim_time * strand.sway_speed + ratio * 1.8 + strand.phase)
			var sway_offset = wave * (ratio * ratio * strand.max_sway)
			pts[i].x = strand.base_pts[i].x + sway_offset
		strand.line.points = pts

func _get_dune_height(x: float) -> float:
	return sin(x * dune_frequency_1) * dune_amplitude_1 + sin(x * dune_frequency_2 + 1.2) * dune_amplitude_2

func generate_seabed() -> void:
	var start_x = -margin_x
	var end_x = width + margin_x
	var step_x = (end_x - start_x) / float(resolution)

	var surface_points: PackedVector2Array = []
	for i in range(resolution + 1):
		var x = start_x + i * step_x
		var y = _get_dune_height(x)
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

	# 3. Spawn swaying kelp forest
	if enable_kelp:
		_spawn_kelp_forest(start_x, end_x)

	# 4. Side boundaries
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

func _spawn_kelp_forest(start_x: float, end_x: float) -> void:
	if not kelp_container:
		kelp_container = Node2D.new()
		kelp_container.name = "KelpForest"
		kelp_container.z_index = -1
		add_child(kelp_container)
	else:
		for child in kelp_container.get_children():
			child.queue_free()
	
	kelp_strands.clear()
	
	var total_span = end_x - start_x
	var spacing = total_span / float(kelp_clump_count + 1)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 # Deterministic aesthetic layout
	
	for c in range(kelp_clump_count):
		var clump_x = start_x + (c + 1) * spacing + rng.randf_range(-30.0, 30.0)
		var clump_strands = rng.randi_range(2, 4)
		
		for s in range(clump_strands):
			var strand_x = clump_x + (s - 1) * 8.0 + rng.randf_range(-4.0, 4.0)
			var strand_y = _get_dune_height(strand_x)
			var strand_h = rng.randf_range(70.0, 130.0)
			var segments = 5
			
			var line = Line2D.new()
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.width = rng.randf_range(3.5, 5.0)
			
			var grad = Gradient.new()
			grad.colors = PackedColorArray([kelp_base_color, kelp_tip_color])
			grad.offsets = PackedFloat32Array([0.0, 1.0])
			line.gradient = grad
			
			var pts: PackedVector2Array = []
			for p in range(segments + 1):
				var r = float(p) / float(segments)
				var pt_y = strand_y - r * strand_h
				pts.append(Vector2(strand_x, pt_y))
			
			line.points = pts
			kelp_container.add_child(line)
			
			var strand = KelpStrand.new()
			strand.line = line
			strand.base_pts = pts
			strand.sway_speed = rng.randf_range(1.2, 1.9)
			strand.phase = rng.randf_range(0.0, TAU)
			strand.max_sway = rng.randf_range(16.0, 26.0)
			kelp_strands.append(strand)
