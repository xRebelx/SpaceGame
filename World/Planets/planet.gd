@tool
extends Node2D
class_name Planet

# === CONFIG ===
const ORBIT_PATH_SCRIPT = preload("res://World/Stars/OrbitPath.gd")
@export var planet_data: PlanetData
# --- Visuals ---
@export var display_name: String = "Planet":
	set(value):
		display_name = value
		_refresh_label()
		_apply_node_name()

@export var texture: Texture2D:
	set(value):
		texture = value
		_apply_radius()

@export_range(1, 4096, 1, "or_greater") var radius_px: int = 128:
	set(value):
		radius_px = value
		_apply_radius()

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

@export var initial_angle_deg: float = 0.0:
	set(value):
		initial_angle_deg = value
		_angle = deg_to_rad(initial_angle_deg)
		if Engine.is_editor_hint():
			_update_orbit_path()
		elif is_instance_valid(self) and is_inside_tree():
			initialize_position()


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
@onready var orbit_trigger_area: Area2D = $OrbitTriggerArea
@onready var orbit_trigger_shape: CollisionShape2D = $OrbitTriggerArea/TriggerShape
@onready var world_space_prompt: Node2D = $WorldSpacePrompt
@onready var orbit_anchor: Node2D = $OrbitAnchor

var _target: Node2D
var _angle: float
var _path_node: Node2D
var _player_in_range: bool = false
var _interaction_consumed: bool = false

@export var orbit_anchor_speed: float = 1.0
@export var orbit_anchor_radius: float = 200.0


func _enter_tree() -> void:
	_refresh_label()
	_apply_node_name()

func _ready() -> void:
	_angle = deg_to_rad(initial_angle_deg) 
	_target = _resolve_orbit_target()
	
	set_process(false)
	set_physics_process(false) # Start frozen
	
	EventBus.sector_intro_complete.connect(_on_intro_complete)
	
	_update_orbit_path()
	
	if not is_instance_valid(orbit_trigger_area):
		push_warning("Planet: OrbitTriggerArea not found!")
	else:
		if not orbit_trigger_area.is_connected("body_entered", Callable(self, "_on_orbit_trigger_area_body_entered")):
			orbit_trigger_area.body_entered.connect(_on_orbit_trigger_area_body_entered)
		if not orbit_trigger_area.is_connected("body_exited", Callable(self, "_on_orbit_trigger_area_body_exited")):
			orbit_trigger_area.body_exited.connect(_on_orbit_trigger_area_body_exited)
		
	if is_instance_valid(world_space_prompt):
		world_space_prompt.visible = false
	else:
		push_warning("Planet: WorldSpacePrompt node not found! Did you create it?")

	if not is_instance_valid(orbit_anchor):
		push_error("[Planet] OrbitAnchor node not found! It is required for orbit logic.")

	if texture == null:
		if is_instance_valid(sprite) and sprite.texture != null:
			texture = sprite.texture
			
	_apply_radius()
	
	initialize_position()


func _exit_tree() -> void:
	_remove_orbit_path()
	if EventBus.is_connected("sector_intro_complete", Callable(self, "_on_intro_complete")):
		EventBus.sector_intro_complete.disconnect(Callable(self, "_on_intro_complete"))

func _process(_delta: float) -> void:
	if is_instance_valid(world_space_prompt) and world_space_prompt.visible:
		world_space_prompt.global_rotation = 0


func _physics_process(delta: float) -> void:
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


# --- Signal Handlers for Orbit Trigger Area ---
func _on_orbit_trigger_area_body_entered(body: Node) -> void:
	if body.is_in_group("players"):
		_player_in_range = true
		_interaction_consumed = false
		if is_instance_valid(world_space_prompt):
			world_space_prompt.visible = true
		
		if body.has_method("set_interactable"):
			body.set_interactable(self)


func _on_orbit_trigger_area_body_exited(body: Node) -> void:
	if body.is_in_group("players"):
		_player_in_range = false
		if is_instance_valid(world_space_prompt):
			world_space_prompt.visible = false
			
		if body.has_method("clear_interactable"):
			body.clear_interactable(self)


# --- Public function called by the Player ---
func on_player_interact() -> void:
	if _interaction_consumed:
		return
	_interaction_consumed = true
	
	EventBus.player_entered_orbit.emit(self)


# --- MODIFIED: Functions ---
func _on_intro_complete() -> void:
	set_process(true)
	set_physics_process(true)


func initialize_position() -> void:
	if _target == null:
		_target = _resolve_orbit_target()
		
	if not is_instance_valid(_target):
		return

	var a: float = semi_major_axis
	var b: float = a * sqrt(max(0.0, 1.0 - eccentricity * eccentricity))
	var local: Vector2 = Vector2(a * cos(_angle), b * sin(_angle)).rotated(deg_to_rad(tilt_deg))
	global_position = _target.global_position + local

func get_current_angle() -> float:
	return _angle

func set_current_angle(new_angle: float) -> void:
	_angle = new_angle
	
# --- NEW: Orbit Anchor Process ---
func _orbit_anchor_process(delta: float) -> void:
	# This function is called by orbit_anchor's script
	orbit_anchor.rotation -= orbit_anchor_speed * delta

# --- MODIFIED: Player Capture / Release Logic ---

func capture_player_for_orbit(player_node: Node2D) -> void:
	if not is_instance_valid(orbit_anchor):
		push_error("[Planet] Cannot capture player, OrbitAnchor is invalid!")
		return
	
	var player_world_pos: Vector2 = player_node.global_position
	
	# --- THIS IS THE FIX ---
	# Remove the child now
	if player_node.get_parent():
		player_node.get_parent().remove_child(player_node)
	
	# Call a new function deferred to add the child and do the tween
	call_deferred("_deferred_add_to_anchor", player_node, player_world_pos)
	# --- END FIX ---


# --- NEW DEFERRED FUNCTION ---
func _deferred_add_to_anchor(player_node: Node2D, player_world_pos: Vector2) -> void:
	orbit_anchor.add_child(player_node)
	player_node.global_position = player_world_pos
	
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	var orbit_local_pos := (player_node.global_position - global_position).normalized() * orbit_anchor_radius
	
	var target_rotation = orbit_local_pos.angle()
	
	tween.tween_property(player_node, "position", orbit_local_pos, 0.5)
	tween.tween_property(player_node, "rotation", target_rotation, 0.5)
	
	orbit_anchor.set_process(true)


func release_player_from_orbit(player_node: Node2D, entities_root: Node) -> void:
	if not is_instance_valid(player_node) or not is_instance_valid(entities_root):
		push_error("[Planet] Cannot release player, node references are invalid!")
		return
		
	# --- THIS IS THE FIX ---
	# Remove the child now
	if player_node.get_parent():
		player_node.get_parent().remove_child(player_node)
	
	# Call a new function deferred to add the child
	call_deferred("_deferred_add_to_entities", player_node, entities_root)
	# --- END FIX ---
	
	orbit_anchor.set_process(false)


# --- NEW DEFERRED FUNCTION ---
func _deferred_add_to_entities(player_node: Node2D, entities_root: Node) -> void:
	if is_instance_valid(entities_root):
		entities_root.add_child(player_node)
	else:
		push_error("[Planet] entities_root became invalid before deferred add.")


# ===== Helpers: visuals & names =====
func _apply_radius() -> void:
	if not is_instance_valid(sprite):
		return

	sprite.texture = texture
	
	if sprite.texture == null:
		return
	var w: float = float(sprite.texture.get_width())
	if w <= 0.0:
		return
	var desired_diameter: float = float(radius_px) * 2.0
	var scale_factor: float = desired_diameter / w
	sprite.scale = Vector2(scale_factor, scale_factor)
	
	if is_instance_valid(orbit_trigger_shape):
		if orbit_trigger_shape.shape == null:
			orbit_trigger_shape.shape = CircleShape2D.new()
		(orbit_trigger_shape.shape as CircleShape2D).radius = float(radius_px) + 20.0

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
	if not is_inside_tree():
		return null
		
	if target_override != NodePath():
		var n: Node = get_node_or_null(target_override)
		if n is Node2D:
			return n
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

	if _path_node == null or not is_instance_valid(_path_node):
		
		if ORBIT_PATH_SCRIPT:
			_path_node = ORBIT_PATH_SCRIPT.new() as Node2D
		else:
			push_warning("ORBIT_PATH_SCRIPT is null. Cannot draw orbit path.")
			return 
			
		_target.add_child(_path_node)
		_path_node.position = Vector2.ZERO
		if Engine.is_editor_hint():
			var root: Node = get_tree().edited_scene_root
			if root != null:
				_path_node.owner = root

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
