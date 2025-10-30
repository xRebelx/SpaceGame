@tool
extends Node2D
class_name OrbitPath2D

@export var semi_major_axis: float = 600.0:
	set(value):
		semi_major_axis = value
		queue_redraw()

@export_range(0.0, 0.95, 0.01) var eccentricity: float = 0.0:
	set(value):
		eccentricity = value
		queue_redraw()

@export var tilt_deg: float = 0.0:
	set(value):
		tilt_deg = value
		queue_redraw()

@export_range(16, 512, 1) var segments: int = 128:
	set(value):
		segments = value
		queue_redraw()

@export var color: Color = Color(1, 1, 1, 0.35):
	set(value):
		color = value
		queue_redraw()

@export var width: float = 2.0:
	set(value):
		width = value
		queue_redraw()

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	var a: float = semi_major_axis
	var b: float = a * sqrt(max(0.0, 1.0 - eccentricity * eccentricity))
	var segs: int = max(12, segments)

	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segs + 1):
		var t: float = float(i) * TAU / float(segs)
		var p: Vector2 = Vector2(a * cos(t), b * sin(t)).rotated(deg_to_rad(tilt_deg))
		pts.append(p)

	draw_polyline(pts, color, width, true)
