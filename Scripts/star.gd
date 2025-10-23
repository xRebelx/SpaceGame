## star.gd — draws simple orbit guideline circles around the star
extends Node2D

@export var orbit_distances := [1300.0, 1000.0, 700.0]
@export var orbit_width: float = 2.0
@export var orbit_color: Color = Color(1, 1, 1, 0.5)

# --- ADDED: World bounds properties ---
@export var world_bound_radius: float = 20000.0
@export var world_bound_width: float = 5.0
@export var world_bound_color: Color = Color(1, 0.2, 0.2, 0.3)


func _ready() -> void:
	# --- ADDED: Set the global world bounds based on this star ---
	# We assume the star is the center of the world
	if Globals.has_method("set_world_center_and_radius"):
		Globals.set_world_center_and_radius(global_position, world_bound_radius)
	
	queue_redraw()

func update_orbit_paths() -> void:
	queue_redraw()

func _draw() -> void:
	# Draw orbit lines
	for d in orbit_distances:
		_draw_orbit(d, orbit_color, orbit_width)
		
	# --- ADDED: Draw the world bound line ---
	_draw_orbit(world_bound_radius, world_bound_color, world_bound_width)

func _draw_orbit(distance: float, color: Color, width: float) -> void:
	if distance <= 0.0:
		return
		
	var points: Array = []
	var segments := 128  # More segments -> smoother circle
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * distance)
	
	# Draw as a polyline
	draw_polyline(points, color, width)
