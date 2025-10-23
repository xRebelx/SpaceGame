extends Node
class_name PlanetDockManager

## Signals
signal docking_complete(planet)
signal fade_complete(planet) # emitted when the fade reaches full black
signal undocking_complete(planet) # --- ADDED ---

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

## --- ADDED: Undock settings ---
@export var undock_duration: float = 1.0      # Time for ship to scale up
@export var undock_impulse: float = 40.0      # Force to push player away

## Internals
var player: Node2D
var target_planet: Node2D
var start_pos: Vector2
var start_scale: Vector2
var is_docking: bool = false
var is_undocking: bool = false # --- ADDED ---
var t: float = 0.0

var _fade_overlay: Node = null
var _fade_started: bool = false
var _fade_done: bool = false


func _ready() -> void:
	if not player_path.is_empty():
		player = get_node_or_null(player_path) as Node2D
	_try_resolve_overlay()
	# FIXED: Cast .name (StringName) to String to resolve ternary warning
	print("[PDM] PlanetDockManager _ready on: ", str(get_parent().name) if get_parent() else "Unknown")
	print("[PDM] Player node: ", player)


func start_docking(planet: Node2D) -> void:
	if player == null:
		push_warning("Player path not assigned in PlanetDockManager")
		return
	# --- MODIFIED: Check both flags ---
	if is_docking or is_undocking:
		print("[PDM] Already docking or undocking. Ignoring request.")
		return

	print("[PDM] start_docking() called for planet: ", planet.name)
	target_planet = planet
	start_pos = player.global_position
	start_scale = player.scale
	t = 0.0
	is_docking = true
	is_undocking = false # --- ADDED ---
	_fade_started = false
	_fade_done = false

	_try_resolve_overlay()

	# If your player has sleeping/awake flags, ensure it's awake during approach
	if "sleeping" in player:
		player.set("sleeping", false) # Use set() for safety


# --- ADDED: start_undocking function ---
func start_undocking() -> void:
	if not is_instance_valid(player):
		push_error("[PDM] Player is invalid! Cannot undock.")
		return
	if not is_instance_valid(target_planet):
		push_error("[PDM] Target planet is invalid! Cannot undock.")
		return
	# --- MODIFIED: Check both flags ---
	if is_docking or is_undocking:
		print("[PDM] Already docking or undocking. Ignoring request.")
		return
		
	print("[PDM] start_undocking() called.")
	
	is_docking = false
	is_undocking = true
	
	_try_resolve_overlay() # Ensure overlay is resolved
	
	# --- Start Undocking Sequence (Parallel) ---
	
	# 1. Fade screen FROM black (fade_out)
	if is_instance_valid(_fade_overlay):
		print("[PDM] Fading screen FROM black (fade_out) over ", fade_in_duration, "s")
		_fade_overlay.call("fade_out", fade_in_duration)
	else:
		push_warning("[PDM] _fade_overlay not found! Cannot fade from black.")

	# 2. Animate player scale back to 1.0
	print("[PDM] Tweening player scale to ONE over ", undock_duration, "s")
	var tw: Tween = player.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "scale", Vector2.ONE, undock_duration)
	
	# 3. Wait for the *player scale* to finish
	await tw.finished
	
	print("[PDM] Player scale tween finished. Restoring player state.")
	
	# 4. Restore player state using safe .set() calls
	# This correctly modifies Player.gd properties without a direct script dependency
	player.set("is_docked", false)
	player.set("is_docking", false)
	player.set("dock_follow_planet", null)
	player.set("docked_to_planet", null)
	player.set("scale", Vector2.ONE) # Ensure it's set
	
	if "sleeping" in player:
		player.set("sleeping", false)
		
	# 5. Apply impulse to push player away
	# We assume the player is facing the planet, so we apply a *backwards* impulse
	var forward_dir: Vector2 = player.get("forward_axis").normalized().rotated(player.rotation + deg_to_rad(player.get("facing_offset_deg")))
	var impulse_vector: Vector2 = -forward_dir * undock_impulse
	
	if player.has_method("apply_central_impulse"):
		player.apply_central_impulse(impulse_vector)
		print("[PDM] Applied undock impulse: ", impulse_vector)
	else:
		push_warning("[PDM] Player has no 'apply_central_impulse' method.")
		
	# 6. Finish
	is_undocking = false
	emit_signal("undocking_complete", target_planet)
	print("[PDM] Undocking complete.")


func _process(delta: float) -> void:
	if not is_docking: # Keep _process clean
		return

	t += delta / animation_duration

	# --- Start fade earlier by fade_start_early_seconds ---
	var early_norm: float = fade_start_early_seconds / max(animation_duration, 0.0001)
	var trigger_t: float = max(0.0, fade_start_t - early_norm)
	
	if not _fade_started and t >= trigger_t:
		_fade_started = true
		if is_instance_valid(_fade_overlay):
			print("[PDM] Docking fade trigger reached (t=", t, "). Starting fade_to_black.")
			_start_fade_to_black()
		else:
			push_warning("[PDM] Docking fade trigger reached, but _fade_overlay is invalid.")

	# Finish docking motion?
	if t >= 1.0:
		_finalize_dock()
		return

	# Animate position/scale during approach
	var move_t: float = clamp(t / move_portion, 0.0, 1.0)
	if ease_in_out:
		move_t = 0.5 - cos(move_t * PI) * 0.5

	# --- ADDED: Check if target_planet is still valid ---
	if not is_instance_valid(target_planet):
		push_warning("[PDM] target_planet became invalid during docking tween. Aborting.")
		is_docking = false
		return
		
	var new_pos: Vector2 = start_pos.lerp(target_planet.global_position, move_t)
	var new_scale: Vector2 = start_scale.lerp(end_scale, move_t)

	player.global_position = new_pos
	player.scale = new_scale


func _try_resolve_overlay() -> void:
	if is_instance_valid(_fade_overlay): # Already resolved
		return

	if not fade_overlay_path.is_empty():
		_fade_overlay = get_node_or_null(fade_overlay_path)

	if not is_instance_valid(_fade_overlay) and get_tree().current_scene:
		# Fallback to common layout: %UILayer/Control/FadeOverlay
		_fade_overlay = get_tree().current_scene.get_node_or_null("%UILayer/Control/FadeOverlay")
		
	if not is_instance_valid(_fade_overlay):
		push_warning("[PDM] Could not resolve _fade_overlay node!")


func _start_fade_to_black() -> void:
	if not is_instance_valid(_fade_overlay):
		push_error("[PDM] _start_fade_to_black failed, overlay is invalid.")
		return

	_fade_done = false
	# _fade_overlay is typed as Node; call by name to avoid static typing errors
	await _fade_overlay.call("fade_in", fade_duration)
	_fade_done = true
	print("[PDM] Fade to black finished. Emitting 'fade_complete'.")
	emit_signal("fade_complete", target_planet)

	# NEW: route to centralized UI manager (autoloaded as /root/UI)
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("on_dock_fade_complete"):
		print("[PDM] Calling /root/UI.on_dock_fade_complete()")
		ui.on_dock_fade_complete(target_planet)
	else:
		push_warning("[PDM] Could not find /root/UI or it's missing 'on_dock_fade_complete'")

	# Keep it black for now. (No fade-out here.)
	if fade_in_after_docking:
		print("[PDM] 'fade_in_after_docking' is true, fading back out (debugging?).")
		await _fade_overlay.call("fade_out", fade_in_duration)


func _finalize_dock() -> void:
	is_docking = false
	print("[PDM] _finalize_dock() called.")

	# --- ADDED: Check if target_planet is still valid ---
	if not is_instance_valid(target_planet):
		push_error("[PDM] target_planet became invalid before _finalize_dock. Player is stranded.")
		return
		
	# Keep the final small scale at dock
	player.scale = end_scale

	# Snap to a locked position that follows the planet without reparenting
	var target_rot: float = target_planet.global_rotation
	var pp: Vector2 = target_planet.global_position
	var world_offset: Vector2 = dock_anchor_offset.rotated(target_rot)
	player.global_position = pp + world_offset
	
	print("[PDM] Docking motion complete. Snapped player to final position.")
	emit_signal("docking_complete", target_planet)
