## Globals.gd — Autoload Singleton
## Setup:
##   Project → Project Settings → AutoLoad
##   Path: res://Scripts/Globals.gd
##   Name: Globals     (← this is the global you use from code)
##   [✔] Enable
extends Node

# --- MODIFIED: Replaced Rect2 bounds with a dynamic center and radius ---
var world_center: Vector2 = Vector2.ZERO
var world_radius: float = 10000.0 # Default radius, will be overwritten by the star

signal bounds_changed(new_center: Vector2, new_radius: float)

# --- REMOVED: Old Rect2-based functions ---
# func clamp_position(pos: Vector2) -> Vector2: ...
# func clamp_body_state(state: PhysicsDirectBodyState2D) -> void: ...
# func set_world_bounds(rect: Rect2) -> void: ...

## This is now called by the Star in its _ready() function
func set_world_center_and_radius(center: Vector2, radius: float) -> void:
	world_center = center
	world_radius = radius
	print("[Globals] New world bounds set. Center: ", center, " Radius: ", radius)
	emit_signal("bounds_changed", center, radius)
