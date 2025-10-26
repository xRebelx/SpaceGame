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

# ===== Thruster visuals =====
@onready var thruster_forward: CanvasItem = get_node_or_null("Thrusters/thruster1")
@onready var thruster_rev_left: CanvasItem = get_node_or_null("Thrusters/reverse_thruster_left_1")
@onready var thruster_rev_right: CanvasItem = get_node_or_null("Thrusters/reverse_thruster_right_1")

# Runtime captain data
var captain_name: String = "Captain"
var stats: Dictionary = {}        # stat_name -> int
var class_id: String = ""         # e.g. "merchant"

func _ready() -> void:
	gravity_scale = 0.0
	linear_damp = world_linear_damp
	angular_damp = world_angular_damp

	if not is_in_group("players"):
		add_to_group("players")

	_set_thrusters(false, false)
	if has_node("BoostParticles"):
		$BoostParticles.emitting = false

func _physics_process(_delta: float) -> void:
	var turn_input: int = int(Input.is_action_pressed("rotate_right")) - int(Input.is_action_pressed("rotate_left"))
	var thrust_pressed: bool = Input.is_action_pressed("thrust")
	var reverse_pressed: bool = Input.is_action_pressed("reverse")

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

# ===== New Game hook =====
func apply_captain_profile(profile: Resource) -> void:
	if profile == null:
		return
	# fetch via property names to stay robust if the Resource is untyped
	if "captain_name" in profile:
		captain_name = String(profile.captain_name)
	if "stats" in profile and typeof(profile.stats) == TYPE_DICTIONARY:
		stats = profile.stats.duplicate()
	if "class_id" in profile:
		class_id = String(profile.class_id)
