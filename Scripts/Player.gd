extends RigidBody2D
class_name Player

# --- REMOVED ---
# @export var dock_manager_path: NodePath (No longer needed)
# var dock_manager: Node = null (No longer needed)

# ===== Movement tuning =====
@export var thrust_force: float = 700.0
@export var reverse_force: float = 450.0
@export var max_speed: float = 700.0
@export var rotation_speed_rps: float = 3.0

@export var world_linear_damp: float = 0.12
@export var world_angular_damp: float = 0.2

@export var facing_offset_deg: float = 0.0
@export var forward_axis: Vector2 = Vector2.UP

# ===== Docking/UI =====
var is_docking: bool = false       # playing approach animation
var is_docked: bool = false        # fully docked (stays attached)
var docked_scale: Vector2 = Vector2.ONE
var docked_to_planet: Node2D = null
var _nearby_planet: Node2D = null

# Follow data (no reparenting)
var dock_follow_planet: Node2D = null
var dock_offset_local: Vector2 = Vector2.ZERO
var align_rotation_while_docked: bool = true

# ===== Thruster visuals =====
@onready var thruster_forward: CanvasItem = get_node_or_null("Thrusters/thruster1")
@onready var thruster_rev_left: CanvasItem = get_node_or_null("Thrusters/reverse_thruster_left_1")
@onready var thruster_rev_right: CanvasItem = get_node_or_null("Thrusters/reverse_thruster_right_1")

func _ready() -> void:
	# --- MODIFIED ---
	# Removed old dock_manager connections.
	
	gravity_scale = 0.0
	linear_damp = world_linear_damp
	angular_damp = world_angular_damp

	# Ensure all VFX start off
	_set_thrusters(false, false)
	if has_node("BoostParticles"):
		$BoostParticles.emitting = false


func _physics_process(_delta: float) -> void:
	# While docked, hard-follow planet and enforce docked scale every frame
	if is_docked and is_instance_valid(dock_follow_planet):
		var pr: float = dock_follow_planet.global_rotation
		var pp: Vector2 = dock_follow_planet.global_position
		var world_offset: Vector2 = dock_offset_local.rotated(pr)
		global_position = pp + world_offset
		scale = docked_scale
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		if align_rotation_while_docked:
			rotation = pr
		_set_thrusters(false, false)
		if has_node("BoostParticles"):
			$BoostParticles.emitting = false
		return
	elif is_docking:
		_set_thrusters(false, false)
		if has_node("BoostParticles"):
			$BoostParticles.emitting = false
		return

	# ---------- INPUT ----------
	var turn_input: int = int(Input.is_action_pressed("rotate_right")) - int(Input.is_action_pressed("rotate_left"))
	var thrust_pressed: bool = Input.is_action_pressed("thrust")
	var reverse_pressed: bool = Input.is_action_pressed("reverse")

	# ---------- ROTATION ----------
	angular_velocity = rotation_speed_rps * turn_input

	# ---------- THRUST / REVERSE ----------
	var forward_dir: Vector2 = forward_axis.normalized().rotated(rotation + deg_to_rad(facing_offset_deg))
	if thrust_pressed:
		apply_central_force(forward_dir * thrust_force)
	if reverse_pressed:
		apply_central_force(-forward_dir * reverse_force)

	# Clamp top speed
	var spd: float = linear_velocity.length()
	if spd > max_speed:
		linear_velocity = linear_velocity * (max_speed / spd)

	# VFX: particle booster and thruster sprites
	if has_node("BoostParticles"):
		$BoostParticles.emitting = thrust_pressed
	_set_thrusters(thrust_pressed, reverse_pressed)

	# Interact -> start docking on the planet you're overlapping
	if Input.is_action_just_pressed("interact") and _nearby_planet and not is_docking and not is_docked:
		var per_planet_dm: Node = _nearby_planet.get_node_or_null("PlanetDockManager")
		if per_planet_dm and per_planet_dm.has_method("start_docking"):
			print("[Player] Interact pressed. Found PDM on: ", _nearby_planet.name)
			is_docking = true
			# ensure awake for approach
			if "sleeping" in self:
				self.sleeping = false
				
			# --- ADDED: Connect to this specific planet's DM signals ---
			if not per_planet_dm.is_connected("docking_complete", Callable(self, "_on_docking_complete")):
				per_planet_dm.connect("docking_complete", Callable(self, "_on_docking_complete"))
				print("[Player] Connected to docking_complete.")
				
			if not per_planet_dm.is_connected("undocking_complete", Callable(self, "_on_undocking_complete")):
				per_planet_dm.connect("undocking_complete", Callable(self, "_on_undocking_complete"))
				print("[Player] Connected to undocking_complete.")
			# --- END ADDED ---
				
			per_planet_dm.start_docking(_nearby_planet)
			
	# --- ADDGITED: New World Bounds Clamping ---
	var offset_from_center: Vector2 = global_position - Globals.world_center
	var dist_sq: float = offset_from_center.length_squared()
	
	if dist_sq > Globals.world_radius * Globals.world_radius:
		# 1. Clamp position
		var dir: Vector2 = offset_from_center.normalized()
		global_position = Globals.world_center + dir * Globals.world_radius
		
		# 2. Remove outward velocity to prevent "sticking"
		var outward_velocity: Vector2 = linear_velocity.project(dir)
		if outward_velocity.dot(dir) > 0: # Check if velocity is pointing outwards
			linear_velocity -= outward_velocity


# Called by Planet.gd when you enter/exit its DockingArea.
func set_nearby_planet(p: Node2D) -> void:
	_nearby_planet = p


func _on_docking_complete(planet: Node2D) -> void:
	print("[Player] _on_docking_complete received.")
	# Remember the current (small) scale for enforcement
	docked_scale = scale
	docked_to_planet = planet
	is_docking = false
	is_docked = true
	dock_follow_planet = planet
	
	# --- ADDED: Store offset data from PDM ---
	var pdm := planet.get_node_or_null("PlanetDockManager")
	if is_instance_valid(pdm):
		dock_offset_local = pdm.get("dock_anchor_offset")
		align_rotation_while_docked = pdm.get("align_rotation_while_docked")
	
	_set_thrusters(false, false)
	if has_node("BoostParticles"):
		$BoostParticles.emitting = false


# --- ADDED: Handles signal from PlanetDockManager ---
func _on_undocking_complete(_planet: Node2D) -> void:
	print("[Player] _on_undocking_complete received. Resetting state.")
	is_docked = false
	is_docking = false
	dock_follow_planet = null
	docked_to_planet = null
	scale = Vector2.ONE
	
	if "sleeping" in self:
		sleeping = false
		

# ===== Helpers =====
func _set_thrusters(forward_on: bool, reverse_on: bool) -> void:
	if thruster_forward:
		thruster_forward.visible = forward_on
	if thruster_rev_left:
		thruster_rev_left.visible = reverse_on
	if thruster_rev_right:
		thruster_rev_right.visible = reverse_on
