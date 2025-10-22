## PlanetUI.gd — scene-local UI container; intentionally thin
## Chain: Planet.gd controls prompts; Player.gd hides it when docking starts
extends Control
class_name PlanetUI

@export var planet_reference: Node2D

func _ready() -> void:
	# Keep visibility as authored so child prompts can appear.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
