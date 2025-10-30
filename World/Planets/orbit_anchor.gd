# World/Planets/orbit_anchor.gd
extends Node2D

# This is a simple helper script to forward the process call
# to the main planet script, so all logic stays in one place.
var _planet: Node

func _ready() -> void:
	_planet = get_parent()
	if not is_instance_valid(_planet) or not _planet.has_method("_orbit_anchor_process"):
		push_error("OrbitAnchor must be a child of a Node with _orbit_anchor_process() method (e.g., Planet)")
		set_process(false)
		return # --- NEW: Added return
	
	# --- NEW: Explicitly set process to false so it doesn't spin by default ---
	set_process(false)


func _process(delta: float) -> void:
	if is_instance_valid(_planet):
		_planet._orbit_anchor_process(delta)
	else:
		set_process(false) # Planet was destroyed
