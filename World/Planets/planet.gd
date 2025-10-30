@tool
extends Node2D
class_name Planet

# === CONFIG ===
const ORBIT_PATH_SCRIPT_PATH: String = "res://World/Stars/OrbitPath.gd"

# --- Visuals ---
@export var display_name: String = "Planet":
	set(value):
		display_name = value
		_refresh_label()
		_apply_node_name()

@export var texture: Texture2D:
	set(value):
		texture = value
		_apply_visual_radius()

@export_range(1, 4096, 1, "or_greater") var radius_px: int = 48:
	set(value):
		radius_px = value
		_apply_visual_radius()

@export var show_name_label: bool = false:
	set(value):
		show_name_label = value
		_refresh_label()

# --- Orbit params ---
@export var central_body_id: String = "":
	set(value):
		central_body_id = value
		_resolve_target_later()

@export var target_override: NodePath:
	set(value):
		target_override = value
		_resolve_target_later()

@export var semi_major_axis: float = 600.0:
	set(value):
		semi_major_axis = value
		_update_orbit_path()

@export_range(0.0, 0.95, 0.01) var eccentricity: float = 0.0:
	set(value):
		eccentricity = value
		_update_orbit_path()

@export var orbital_period_sec: float = 30.0
@export var tilt_deg: float = 0.0:
	set(value):
		tilt_deg = value
		_update_orbit_path()

@export var initial_angle_deg: float = 0.0
@export var clockwise: bool = false

# --- Orbit path rendering (lives under the Star) ---
@export var show_orbit_path: bool = true:
	set(value):
		show_orbit_path = value
		_update_orbit_path()

@export_range(16, 512, 1) var orbit_segments: int = 128:
	set(value):
		orbit_segments = value
		_update_orbit_path()

@export var orbit_color: Color = Color(1, 1, 1, 0.35):
	set(value):
		orbit_color = value
		_update_orbit_path()

@export var orbit_width: float = 2.0:
	set(value):
		orbit_width = value
		_update_orbit_path()

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = get_node_or_null("NameLabel")

var _target: Node2D
var _angle: float
var _path_node: Node2D
var _orbit_path_script: Script

func _enter_tree() -> void:
	_apply_visual_radius()
	_refresh_label()
	_apply_node_name()

func _ready() -> void:
	_angle = deg_to_rad(initial_angle_deg)
	_target = _resolve_orbit_target()
	
	# --- FIX: Start frozen and wait for the "all clear" signal ---
	set_process(false) # Start frozen
	EventBus.sector_intro_complete.connect(_on_intro_complete)
	# --- END FIX ---
	
	# Prefer global class if your OrbitPath.gd declares `class_name OrbitPath2D`
	if ClassDB.class_exists("OrbitPath2D"):
		_orbit_path_script = null
	else:
		_orbit_path_script = load(ORBIT_PATH_SCRIPT_PATH)
	_update_orbit_path()

func _exit_tree() -> void:
	_remove_orbit_path()
	# --- FIX: Disconnect from signal to prevent memory leaks ---
	if EventBus.is_connected("sector_intro_complete", Callable(self, "_on_intro_complete")):
		EventBus.sector_intro_complete.disconnect(Callable(self, "_on_intro_complete"))
	# --- END FIX ---

func _process(delta: float) -> void:
	# don't animate in the editor
	if Engine.is_editor_hint():
		return
	if _target == null or orbital_period_sec <= 0.0:
		return

	var dir: float = -1.0 if clockwise else 1.0
	_angle += dir * (TAU / max(0.0001, orbital_period_sec)) * delta

	var a: float = semi_major_axis
	var b: float = a * sqrt(max(0.0, 1.0 - eccentricity * eccentricity))
	var local: Vector2 = Vector2(a * cos(_angle), b * sin(_angle)).rotated(deg_to_rad(tilt_deg))
	global_position = _target.global_position + local

# --- NEW/MODIFIED FUNCTIONS ---
func _on_intro_complete() -> void:
	"""Called by EventBus when the sector intro animation is finished."""
	set_process(true) # Start moving

func initialize_position() -> void:
	"""
	Called by UniverseManager to set the planet's visual position
	one time before it starts processing.
	"""
	if _target == null: # Ensure target is resolved
		_target = _resolve_orbit_target()
		
	if not is_instance_valid(_target):
		return # Can't set position without a target

	# This is the same logic from _process()
	var a: float = semi_major_axis
	var b: float = a * sqrt(max(0.0, 1.0 - eccentricity * eccentricity))
	var local: Vector2 = Vector2(a * cos(_angle), b * sin(_angle)).rotated(deg_to_rad(tilt_deg))
	global_position = _target.global_position + local

func get_current_angle() -> float:
	"""Returns the planet's current position in its orbit."""
	return _angle

func set_current_angle(new_angle: float) -> void:
	"""Sets the planet's orbital position, overriding its initial angle."""
	_angle = new_angle
# --- END NEW/MODIFIED ---

# ===== Helpers: visuals & names =====
func _apply_visual_radius() -> void:
	if not is_instance_valid(sprite):
		return
	if texture:
		sprite.texture = texture
	if sprite.texture == null:
		return
	var w: float = float(sprite.texture.get_width())
	if w <= 0.0:
		return
	var desired_diameter: float = float(radius_px) * 2.0
	var scale_factor: float = desired_diameter / w
	sprite.scale = Vector2(scale_factor, scale_factor)

func _refresh_label() -> void:
	if not is_instance_valid(name_label):
		return
	name_label.visible = show_name_label
	name_label.text = display_name

func _apply_node_name() -> void:
	if display_name.strip_edges() != "":
		name = StringName(display_name)

# ===== Helpers: target resolution =====
func _resolve_orbit_target() -> Node2D:
	# 1) explicit NodePath
	if target_override != NodePath():
		var n: Node = get_node_or_null(target_override)
		if n is Node2D:
			return n
	# 2) lookup star by id via group
	if central_body_id != "":
		for s in get_tree().get_nodes_in_group("stars"):
			if "id" in s and s.id == central_body_id and s is Node2D:
				return s
	return null

func _resolve_target_later() -> void:
	call_deferred("_resolve_target_apply")

func _resolve_target_apply() -> void:
	_target = _resolve_orbit_target()
	_update_orbit_path()

# ===== Orbit path handling (drawn under the Star) =====
func _update_orbit_path() -> void:
	if not show_orbit_path:
		_remove_orbit_path()
		return
	if _target == null:
		return

	# Create under the star if missing
	if _path_node == null or not is_instance_valid(_path_node):
		if ClassDB.class_exists("OrbitPath2D"):
			_path_node = ClassDB.instantiate("OrbitPath2D") as Node2D
		else:
			if _orbit_path_script == null:
				push_warning("Orbit path script not found at: %s" % ORBIT_PATH_SCRIPT_PATH)
				return
			_path_node = _orbit_path_script.new() as Node2D
		_target.add_child(_path_node)
		_path_node.position = Vector2.ZERO
		# Make the helper visible in the editor's owner if needed
		if Engine.is_editor_hint():
			var root: Node = get_tree().edited_scene_root
			if root != null:
				_path_node.owner = root

	# Sync params defensively (only if fields exist on your OrbitPath.gd)
	if "semi_major_axis" in _path_node: _path_node.semi_major_axis = semi_major_axis
	if "eccentricity"    in _path_node: _path_node.eccentricity    = eccentricity
	if "tilt_deg"        in _path_node: _path_node.tilt_deg        = tilt_deg
	if "segments"        in _path_node: _path_node.segments        = orbit_segments
	if "color"           in _path_node: _path_node.color           = orbit_color
	if "width"           in _path_node: _path_node.width           = orbit_width
	if _path_node.has_method("refresh"): _path_node.call("refresh")
	if _path_node.has_method("queue_redraw"): _path_node.call("queue_redraw")

func _remove_orbit_path() -> void:
	if _path_node != null and is_instance_valid(_path_node):
		_path_node.queue_free()
	_path_node = null
