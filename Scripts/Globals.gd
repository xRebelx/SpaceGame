## Globals.gd — Autoload Singleton (no class_name to avoid name collision)
## Setup:
##   Project → Project Settings → AutoLoad
##   Path: res://Scripts/Globals.gd
##   Name: Globals     (← this is the global you use from code)
##   [✔] Enable
## Usage from any script:
##   Globals.clamp_body_state(state)
extends Node

## World bounds rectangle. Position = top-left; Size = width/height.
@export var world_bounds: Rect2 = Rect2(Vector2(50, 50), Vector2(11900, 7900))

signal bounds_changed(new_bounds: Rect2)

func clamp_position(pos: Vector2) -> Vector2:
	var min_x := world_bounds.position.x
	var min_y := world_bounds.position.y
	var max_x := world_bounds.position.x + world_bounds.size.x
	var max_y := world_bounds.position.y + world_bounds.size.y
	return Vector2(
		clamp(pos.x, min_x, max_x),
		clamp(pos.y, min_y, max_y)
	)

func clamp_body_state(state: PhysicsDirectBodyState2D) -> void:
	var t := state.transform
	t.origin = clamp_position(t.origin)
	state.transform = t

func set_world_bounds(rect: Rect2) -> void:
	world_bounds = rect
	emit_signal("bounds_changed", rect)
