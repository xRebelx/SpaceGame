extends Node
class_name PlanetDockManager

## Signals
signal docking_complete(planet)
signal fade_complete(planet) # emitted when the fade reaches full black

## Exports
@export var player_path: NodePath
@export var animation_duration: float = 2.5
@export var approach_radius: float = 250.0
@export var end_scale: Vector2 = Vector2(0.3, 0.3)
@export var move_portion: float = 0.6
@export var ease_in_out: bool = true

## Fade settings
@export_range(0.0, 1.0, 0.01) var fade_start_t: float = 0.85 # normalized 0–1
@export var fade_start_early_seconds: float = 1.5            # start this many seconds sooner
@export var fade_duration: float = 1.5                        # seconds
@export var fade_overlay_path: NodePath                       # set to %UILayer/Control/FadeOverlay
@export var fade_in_after_docking: bool = false               # keep screen black for now
@export var fade_in_duration: float = 0.8                     # used later on undock

## Dock placement
@export var dock_anchor_offset: Vector2 = Vector2(0, -48)
@export var align_rotation_while_docked: bool = true

## Internals
var player: Node2D
var target_planet: Node2D
var start_pos: Vector2
var start_scale: Vector2
var is_docking: bool = false
var t: float = 0.0

var _fade_overlay: Node = null
var _fade_started: bool = false
var _fade_done: bool = false


func _ready() -> void:
	if not player_path.is_empty():
		player = get_node_or_null(player_path) as Node2D
	_try_resolve_overlay()


func start_docking(planet: Node2D) -> void:
	if player == null:
		push_warning("Player path not assigned in PlanetDockManager")
		return

	target_planet = planet
	start_pos = player.global_position
	start_scale = player.scale
	t = 0.0
	is_docking = true
	_fade_started = false
	_fade_done = false

	_try_resolve_overlay()

	# If your player has sleeping/awake flags, ensure it's awake during approach
	if "sleeping" in player:
		player.sleeping = false


func _process(delta: float) -> void:
	if not is_docking:
		return

	t += delta / animation_duration

	# --- Start fade earlier by fade_start_early_seconds ---
	var early_norm: float = fade_start_early_seconds / max(animation_duration, 0.0001)
	var trigger_t: float = max(0.0, fade_start_t - early_norm)
	if not _fade_started and t >= trigger_t:
		_fade_started = true
		if is_instance_valid(_fade_overlay):
			_start_fade_to_black()

	# Finish docking motion?
	if t >= 1.0:
		_finalize_dock()
		return

	# Animate position/scale during approach
	var move_t: float = clamp(t / move_portion, 0.0, 1.0)
	if ease_in_out:
		move_t = 0.5 - cos(move_t * PI) * 0.5

	var new_pos: Vector2 = start_pos.lerp(target_planet.global_position, move_t)
	var new_scale: Vector2 = start_scale.lerp(end_scale, move_t)

	player.global_position = new_pos
	player.scale = new_scale


func _try_resolve_overlay() -> void:
	if _fade_overlay:
		return

	if not fade_overlay_path.is_empty():
		_fade_overlay = get_node_or_null(fade_overlay_path)

	if not _fade_overlay and get_tree().current_scene:
		# Fallback to common layout: %UILayer/Control/FadeOverlay
		_fade_overlay = get_tree().current_scene.get_node_or_null("%UILayer/Control/FadeOverlay")


func _start_fade_to_black() -> void:
	if not is_instance_valid(_fade_overlay):
		return

	_fade_done = false
	# _fade_overlay is typed as Node; call by name to avoid static typing errors
	await _fade_overlay.call("fade_in", fade_duration)
	_fade_done = true
	emit_signal("fade_complete", target_planet)

	# NEW: route to centralized UI manager (autoloaded as /root/UI)
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("on_dock_fade_complete"):
		ui.on_dock_fade_complete(target_planet)

	# Keep it black for now. (No fade-out here.)
	if fade_in_after_docking:
		await _fade_overlay.call("fade_out", fade_in_duration)


func _finalize_dock() -> void:
	is_docking = false

	# Keep the final small scale at dock
	player.scale = end_scale

	# Snap to a locked position that follows the planet without reparenting
	var target_rot: float = target_planet.global_rotation
	var pp: Vector2 = target_planet.global_position
	var world_offset: Vector2 = dock_anchor_offset.rotated(target_rot)
	player.global_position = pp + world_offset

	emit_signal("docking_complete", target_planet)
