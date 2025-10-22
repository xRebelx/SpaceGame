## star.gd — draws simple orbit guideline circles around the star
extends Node2D

@export var orbit_distances := [1300.0, 1000.0, 700.0]
@export var orbit_width: float = 2.0
@export var orbit_color: Color = Color(1, 1, 1, 0.5)

func _ready() -> void:
	queue_redraw()

func update_orbit_paths() -> void:
	queue_redraw()

func _draw() -> void:
	for d in orbit_distances:
		_draw_orbit(d)

func _draw_orbit(distance: float) -> void:
	var points: Array = []
	var segments := 64  # More segments -> smoother circle
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * distance)
	for i in range(segments):
		draw_line(points[i], points[i + 1], orbit_color, orbit_width)
