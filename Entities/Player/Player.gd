# Entities/Player/Player.gd
extends RigidBody2D
class_name Player

# ===== Movement tuning =====
@export var thrust_force: float = 700.0
@export var reverse_force: float = 450.0
@export var max_speed: float = 700.0
@export var rotation_speed_rps: float = 3.0

@export var world_linear_damp: float = 0.12
@export var world_angular_damp: float = 0.2

@export var facing_offset_deg: float = 0.0
@export var forward_axis: Vector2 = Vector2.UP

# --- ADD THESE LINES ---
@export_group("World Bounds")
@export var bounds_pushback_force: float = 100.0
@export var bounds_damp_factor: float = 2.0
# --- END ADD ---

# ===== Thruster visuals =====
@onready var thruster_forward: CanvasItem = get_node_or_null("Thrusters/thruster1")
@onready var thruster_rev_left: CanvasItem = get_node_or_null("Thrusters/reverse_thruster_left_1")
@onready var thruster_rev_right: CanvasItem = get_node_or_null("Thrusters/reverse_thruster_right_1")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var thrusters_node: Node2D = $Thrusters

# --- REFACTORED: State is held in resources ---
var captain_profile: CaptainProfile = null
var ship_data: ShipData = null

# --- NEW: Interaction state ---
var _current_interactable: Node = null

# --- NEW: Orbiting State ---
enum State { FLYING, ORBITING }
var _state: State = State.FLYING
var _orbiting_planet: Node2D = null
var _entities_root: Node = null

# --- ADD THIS LINE ---
var _current_world_bounds: Rect2 = Rect2() # Stores the active sector's bounds


func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = world_linear_damp
	angular_damp = world_angular_damp

	if not is_in_group("players"):
		add_to_group("players")

	_set_thrusters(false, false)
	if has_node("BoostParticles"):
		$BoostParticles.emitting = false

	EventBus.sector_intro_complete.connect(_on_sector_intro_complete)
	EventBus.player_entered_orbit.connect(_on_enter_orbit)
	EventBus.player_leave_orbit.connect(_on_leave_orbit)

	# Store parent for re-parenting later
	_entities_root = get_parent()


func _physics_process(_delta: float) -> void:
	if _state != State.FLYING:
		return

	# --- ADD THIS ENTIRE BLOCK ---
	# Apply soft wall world bounds
	var pushback_force := Vector2.ZERO
	var is_outside := false

	if _current_world_bounds.has_area():
		var pos: Vector2 = global_position
		
		# Check X axis
		if pos.x < _current_world_bounds.position.x:
			# How far past the left edge
			pushback_force.x = _current_world_bounds.position.x - pos.x
			is_outside = true
		elif pos.x > _current_world_bounds.end.x:
			# How far past the right edge
			pushback_force.x = _current_world_bounds.end.x - pos.x
			is_outside = true
			
		# Check Y axis
		if pos.y < _current_world_bounds.position.y:
			# How far past the top edge
			pushback_force.y = _current_world_bounds.position.y - pos.y
			is_outside = true
		elif pos.y > _current_world_bounds.end.y:
			# How far past the bottom edge
			pushback_force.y = _current_world_bounds.end.y - pos.y
			is_outside = true

	if is_outside:
		# Apply a pushback force proportional to the distance outside the bounds
		apply_central_force(pushback_force * bounds_pushback_force)
		
		# Apply extra damping to slow the player down
		linear_damp = world_linear_damp * bounds_damp_factor
	else:
		# Ensure damping is reset when back inside
		linear_damp = world_linear_damp
	# --- END OF BLOCK ---

	var turn_input: int = int(Input.is_action_pressed("rotate_right")) - int(Input.is_action_pressed("rotate_left"))
	var thrust_pressed: bool = Input.is_action_pressed("thrust")
	var reverse_pressed: bool = Input.is_action_pressed("reverse")

	if Input.is_action_just_pressed("interact"):
		if is_instance_valid(_current_interactable):
			if _current_interactable.has_method("on_player_interact"):
				_current_interactable.on_player_interact()
			else:
				print("[Player] DEBUG: ERROR - Node has no 'on_player_interact' method.")
		else:
			print("[Player] DEBUG: No interactable in range.")

	angular_velocity = rotation_speed_rps * turn_input

	var forward_dir: Vector2 = forward_axis.normalized().rotated(rotation + deg_to_rad(facing_offset_deg))
	if thrust_pressed:
		apply_central_force(forward_dir * thrust_force)
	if reverse_pressed:
		apply_central_force(-forward_dir * reverse_force)

	var spd: float = linear_velocity.length()
	if spd > max_speed and spd > 0.0:
		linear_velocity *= (max_speed / spd)

	if has_node("BoostParticles"):
		$BoostParticles.emitting = thrust_pressed
	_set_thrusters(thrust_pressed, reverse_pressed)


# ===== Helpers =====
func _set_thrusters(forward_on: bool, reverse_on: bool) -> void:
	if thruster_forward:
		thruster_forward.visible = forward_on
	if thruster_rev_left:
		thruster_rev_left.visible = reverse_on
	if thruster_rev_right:
		thruster_rev_right.visible = reverse_on

# --- ADD THIS FUNCTION ---
# This is the new function UniverseManager will call
func set_world_bounds(new_bounds: Rect2) -> void:
	_current_world_bounds = new_bounds
# --- END ADD ---

# ===== New Game hook =====
func apply_captain_and_ship_data(profile: CaptainProfile, s_data: ShipData) -> void:
	captain_profile = profile
	PlayerManager.captain_profile = profile
	if s_data:
		ship_data = s_data
		PlayerManager.ship_data = s_data


# ===== Interaction Handlers =====
func set_interactable(node: Node) -> void:
	_current_interactable = node

func clear_interactable(node: Node) -> void:
	if _current_interactable == node:
		_current_interactable = null


# ===== Warp and Intro Logic =====
func initiate_warp() -> void:
	print("[Player] Initiating warp... physics disabled.")
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_set_thrusters(false, false)
	set_physics_process(false)

func _on_sector_intro_complete() -> void:
	print("[Player] Sector intro complete. Physics re-enabled.")
	set_physics_process(true)


# ===== ORBIT STATE =====
func _on_enter_orbit(planet_node: Node2D) -> void:
	if _state == State.ORBITING:
		return

	_state = State.ORBITING
	_orbiting_planet = planet_node

	freeze = true
	set_physics_process(false)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	collision_shape.set_deferred("disabled", true)

	if is_instance_valid(thrusters_node):
		thrusters_node.visible = false
	else:
		_set_thrusters(false, false)

	if has_node("BoostParticles"):
		$BoostParticles.emitting = false

	var cam := get_viewport().get_camera_2d()
	var tween_duration: float = 1.0

	if cam:
		if cam.has_method("lock_zoom_for_orbit"):
			cam.lock_zoom_for_orbit(tween_duration)
		if cam.has_method("set_follow_target"):
			cam.set_follow_target(planet_node, cam.zoom, tween_duration)

	if planet_node.has_method("capture_player_for_orbit"):
		planet_node.capture_player_for_orbit(self)
	else:
		push_error("[Player] Planet is missing 'capture_player_for_orbit' method!")

	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", Vector2(0.5, 0.5), tween_duration)


func _on_leave_orbit() -> void:
	if _state == State.FLYING:
		return

	if not is_instance_valid(_orbiting_planet):
		push_warning("[Player] Cannot leave orbit, planet reference is invalid!")
		return

	if not _orbiting_planet.has_method("release_player_from_orbit"):
		push_error("[Player] Planet is missing 'release_player_from_orbit'!")
		return

	var exit_position: Vector2 = global_position
	var exit_rotation: float = global_rotation
	_state = State.FLYING

	var cam := get_viewport().get_camera_2d()
	var tween_duration: float = 1.0
	var cam_move_tween: Tween = null

	if cam:
		if cam.has_method("set_follow_target"):
			cam_move_tween = cam.set_follow_target(self, cam.zoom, tween_duration)

	_orbiting_planet.release_player_from_orbit(self, _entities_root)

	global_position = exit_position
	global_rotation = exit_rotation

	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), tween_duration)

	if is_instance_valid(cam_move_tween):
		await cam_move_tween.finished

	if cam:
		if cam.has_method("unlock_zoom_after_orbit"):
			cam.unlock_zoom_after_orbit(tween_duration)

	if is_instance_valid(scale_tween):
		await scale_tween.finished

	_orbiting_planet = null

	freeze = false
	set_physics_process(true)
	collision_shape.set_deferred("disabled", false)

	if is_instance_valid(thrusters_node):
		thrusters_node.visible = true
