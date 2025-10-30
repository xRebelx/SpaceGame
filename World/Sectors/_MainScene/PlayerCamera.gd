extends Camera2D
# Optional: class_name PlayerCamera

@export var search_by_group: bool = true           # find first node in "players" group
@export var player_path: NodePath                  # explicit path to Player (overrides group search if set)
@export var enable_rotation_follow: bool = false   # usually false for space shooters
@export var zoom_at_play: Vector2 = Vector2.ONE
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 8.0           # <- different name than built-in property

var _target: Node2D = null
var _player_target: Node2D = null # --- NEW: Permanent reference to player
var _current_tween: Tween = null # --- NEW: Tween reference

func _ready() -> void:
	enabled = true
	zoom = zoom_at_play
	position_smoothing_enabled = smoothing_enabled
	self.position_smoothing_speed = smoothing_speed

	_resolve_target()
	_player_target = _target # --- NEW: Store player reference
	get_tree().node_added.connect(_on_node_added)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_target):
		return
	
	# --- NEW: Don't follow if a tween is moving the camera
	if _current_tween and _current_tween.is_running():
		return
		
	global_position = _target.global_position
	if enable_rotation_follow:
		rotation = _target.global_rotation

# --- MODIFIED: Public function for smooth transition ---
func set_follow_target(new_target: Node2D, new_zoom: Vector2, duration: float = 0.0) -> Tween:
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()

	_target = new_target # Set target immediately
	
	if duration > 0.0:
		# Disable built-in smoothing so it doesn't fight the tween
		position_smoothing_enabled = false
		
		_current_tween = create_tween()
		_current_tween.set_parallel(true)
		_current_tween.tween_property(self, "global_position", new_target.global_position, duration).set_trans(Tween.TRANS_SINE)
		_current_tween.tween_property(self, "zoom", new_zoom, duration).set_trans(Tween.TRANS_SINE)
		# When tween finishes, re-enable smoothing if it was on
		_current_tween.finished.connect(func(): position_smoothing_enabled = smoothing_enabled)
	else:
		# Snap immediately
		global_position = new_target.global_position
		zoom = new_zoom
		_current_tween = null

	# --- NEW: Return the tween so other scripts can await it
	return _current_tween

# --- MODIFIED: Public function to return to player ---
func reset_to_player(duration: float = 0.0) -> Tween:
	if not is_instance_valid(_player_target):
		push_warning("[PlayerCamera] No player target to reset to!")
		return null
		
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()

	_target = _player_target # Set target back to player
	
	if duration > 0.0:
		# Disable smoothing during transition
		position_smoothing_enabled = false
		
		_current_tween = create_tween()
		_current_tween.set_parallel(true)
		# We tween to the player's *current* position
		_current_tween.tween_property(self, "global_position", _player_target.global_position, duration).set_trans(Tween.TRANS_SINE)
		_current_tween.tween_property(self, "zoom", zoom_at_play, duration).set_trans(Tween.TRANS_SINE)
		# Re-enable smoothing when done
		_current_tween.finished.connect(func(): position_smoothing_enabled = smoothing_enabled)
	else:
		# Snap immediately
		global_position = _player_target.global_position
		zoom = zoom_at_play
		position_smoothing_enabled = smoothing_enabled # Ensure it's reset
		_current_tween = null
	
	# --- NEW: Return the tween so other scripts can await it
	return _current_tween


func _resolve_target() -> void:
	# 1) Explicit path wins
	if player_path != NodePath():
		var n := get_node_or_null(player_path)
		if n is Node2D:
			_target = n
			return

	# 2) Group search
	if search_by_group:
		var first := get_tree().get_first_node_in_group("players")
		if first is Node2D:
			_target = first
			return

	# 3) Fallback by name
	var main := get_tree().get_current_scene()
	if main:
		var p := main.find_child("Player", true, false)
		if p is Node2D:
			_target = p

func _on_node_added(n: Node) -> void:
	if _target and is_instance_valid(_target):
		return
	if search_by_group and n.is_in_group("players") and n is Node2D:
		_target = n
		if not is_instance_valid(_player_target):
			_player_target = n # --- NEW: Grab player ref if it spawns later
