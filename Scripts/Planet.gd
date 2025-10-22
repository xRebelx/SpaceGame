## Planet.gd — owns docking trigger + on-map UI prompt + simple orbit motion
## Chain for docking proximity:
##   Player enters DockingArea -> _on_docking_area_body_entered() (this file)
##   -> calls Player.set_nearby_planet(self) [Player.gd]
##   -> Player can press "interact" (E) to call PlanetDockManager.start_docking(self) [PlanetDockManager.gd]
extends Node2D
class_name BasePlanet

signal player_overlapped(planet, body)     # Emitted when something enters DockingArea
signal player_left(planet, body)           # Emitted when something leaves DockingArea

@export var data: PlanetData
@export var sun_path: NodePath             # Optional: the node we orbit around (Star)
@export var orbit_speed: float = 1.0
@export var orbit_distance: float = 100.0

@onready var docking_area: Area2D = $DockingArea
@onready var dock_manager: Node = $PlanetDockManager

var prompt_root: CanvasItem = null         # Cached UI prompt root

var orbit_progress: float = 0.0
var previous_position: Vector2 = Vector2.ZERO
var current_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	previous_position = global_position
	_initialize_sun_path()
	_connect_docking_area()
	_resolve_prompt_root()
	_hide_prompt_immediate()

func _process(delta: float) -> void:
	_update_orbit(delta)
	_update_velocity(delta)

# ----- Orbit helpers -----
func _initialize_sun_path() -> void:
	# If not set, try to find a parent child named 'Sun' or 'Star'
	if sun_path.is_empty():
		var parent := get_parent()
		var potential_sun: Node = null
		if parent:
			potential_sun = parent.find_child("Sun", true, false)
			if potential_sun == null:
				potential_sun = parent.find_child("Star", true, false)
		if potential_sun:
			sun_path = get_parent().get_path_to(potential_sun)

func _update_orbit(delta: float) -> void:
	if not sun_path.is_empty():
		var sun_node := get_node_or_null(sun_path)
		if sun_node:
			orbit_progress += delta * orbit_speed
			var orbit_position := Vector2(cos(orbit_progress), sin(orbit_progress)) * orbit_distance
			global_position = sun_node.global_position + orbit_position

func _update_velocity(delta: float) -> void:
	current_velocity = (global_position - previous_position) / max(delta, 0.0001)
	previous_position = global_position

# ----- Prompt helpers -----
func _connect_docking_area() -> void:
	if not is_instance_valid(docking_area): return
	if not docking_area.is_connected("body_entered", Callable(self, "_on_docking_area_body_entered")):
		docking_area.connect("body_entered", Callable(self, "_on_docking_area_body_entered"))
	if not docking_area.is_connected("body_exited", Callable(self, "_on_docking_area_body_exited")):
		docking_area.connect("body_exited", Callable(self, "_on_docking_area_body_exited"))

func _resolve_prompt_root() -> void:
	# We support either a MarginContainer or InteractionBG as the "prompt root".
	var c := find_child("MarginContainer", true, false)
	if c is CanvasItem:
		prompt_root = c
	elif find_child("InteractionBG", true, false) is CanvasItem:
		prompt_root = find_child("InteractionBG", true, false) as CanvasItem

func _ensure_prompt_ancestors_visible() -> void:
	var n: Node = prompt_root
	while n and n != self:
		if n is CanvasItem:
			(n as CanvasItem).visible = true
		n = n.get_parent()

func _show_prompt() -> void:
	if is_instance_valid(prompt_root):
		_ensure_prompt_ancestors_visible()
		prompt_root.visible = true
		prompt_root.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(prompt_root, "modulate:a", 1.0, 0.12)

func _hide_prompt() -> void:
	if is_instance_valid(prompt_root) and prompt_root.visible:
		var tw := create_tween()
		tw.tween_property(prompt_root, "modulate:a", 0.0, 0.12)
		await tw.finished
		prompt_root.visible = false

func _hide_prompt_immediate() -> void:
	if is_instance_valid(prompt_root):
		prompt_root.visible = false
		prompt_root.modulate.a = 0.0

# ----- DockingArea callbacks -----
func _on_docking_area_body_entered(body: Node) -> void:
	emit_signal("player_overlapped", self, body)
	_show_prompt()
	if body and body.has_method("set_nearby_planet"):
		body.set_nearby_planet(self)      # -> Player.gd

func _on_docking_area_body_exited(body: Node) -> void:
	emit_signal("player_left", self, body)
	_hide_prompt()
	if body and body.has_method("set_nearby_planet"):
		body.set_nearby_planet(null)      # -> Player.gd

# Public so Player can hide UI when docking begins.
func hide_interaction_ui() -> void:
	_hide_prompt()
