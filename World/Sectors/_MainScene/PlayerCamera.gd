extends Camera2D
# Optional: class_name PlayerCamera

@export var search_by_group: bool = true
@export var player_path: NodePath
@export var enable_rotation_follow: bool = false

@export var zoom_at_play: Vector2 = Vector2.ONE     # default zoom (closest allowed)
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 8.0

@export_group("Scroll Zoom")
@export var enable_scroll_zoom: bool = true
@export var zoom_speed: float = 0.1                 # per wheel tick
@export var zoom_smoothing: float = 8.0             # lerp factor
@export var max_zoom_out_factor: float = 3.0        # 3 => can zoom out to default/3

var _target: Node2D
var _player_target: Node2D
var _current_tween: Tween

var _target_zoom: Vector2 = Vector2.ONE

# Smaller = farther out in Camera2D
var _min_zoom_level: Vector2 = Vector2.ONE  # farthest out (smallest)
var _max_zoom_level: Vector2 = Vector2.ONE  # closest in (= default)

# Orbit lock state
var _zoom_locked := false
var _pre_orbit_zoom: Vector2 = Vector2.ONE
var _locked_zoom_level: Vector2 = Vector2.ONE  # default when locked

func _ready() -> void:
	enabled = true
	position_smoothing_enabled = smoothing_enabled
	position_smoothing_speed = smoothing_speed

	max_zoom_out_factor = maxf(max_zoom_out_factor, 1.0)

	# start at default
	zoom = zoom_at_play
	_max_zoom_level = zoom_at_play
	_min_zoom_level = zoom_at_play / max_zoom_out_factor
	_locked_zoom_level = _max_zoom_level

	_target_zoom = zoom_at_play
	_target_zoom.x = clampf(_target_zoom.x, _min_zoom_level.x, _max_zoom_level.x)
	_target_zoom.y = clampf(_target_zoom.y, _min_zoom_level.y, _max_zoom_level.y)

	_resolve_target()
	_player_target = _target
	get_tree().node_added.connect(_on_node_added)

# -------- ORBIT API --------
func lock_zoom_for_orbit(tween_time: float = 0.8) -> void:
	# store ACTUAL current zoom (not target)
	_pre_orbit_zoom = Vector2(zoom.x, zoom.y)
	_zoom_locked = true
	_start_zoom_tween(_locked_zoom_level, tween_time)

func unlock_zoom_after_orbit(tween_time: float = 0.8) -> void:
	_zoom_locked = false
	var restore := _pre_orbit_zoom
	restore.x = clampf(restore.x, _min_zoom_level.x, _max_zoom_level.x)
	restore.y = clampf(restore.y, _min_zoom_level.y, _max_zoom_level.y)
	_start_zoom_tween(restore, tween_time)

# -------- INPUT --------
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or get_tree().paused or not enable_scroll_zoom:
		return
	if _zoom_locked:
		return
	if _current_tween and _current_tween.is_running():
		return

	var step := Vector2(zoom_speed, zoom_speed)
	var handled := false

	# FLIPPED: Up = IN (toward default), Down = OUT (farther)
	if event.is_action_pressed("scroll_up"):
		_target_zoom += step
		handled = true
	if event.is_action_pressed("scroll_down"):
		_target_zoom -= step
		handled = true

	if handled:
		_target_zoom.x = clampf(_target_zoom.x, _min_zoom_level.x, _max_zoom_level.x)
		_target_zoom.y = clampf(_target_zoom.y, _min_zoom_level.y, _max_zoom_level.y)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _zoom_locked:
		_target_zoom = _locked_zoom_level
	if _current_tween and _current_tween.is_running():
		return
	zoom = zoom.lerp(_target_zoom, delta * zoom_smoothing)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_target):
		return
	if _current_tween and _current_tween.is_running():
		return
	global_position = _target.global_position
	if enable_rotation_follow:
		rotation = _target.global_rotation

# Follow helper (honors lock)
func set_follow_target(new_target: Node2D, new_zoom: Vector2, duration: float = 0.0) -> Tween:
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()

	_target = new_target
	if _zoom_locked:
		new_zoom = _locked_zoom_level
	else:
		new_zoom.x = clampf(new_zoom.x, _min_zoom_level.x, _max_zoom_level.x)
		new_zoom.y = clampf(new_zoom.y, _min_zoom_level.y, _max_zoom_level.y)
	_target_zoom = new_zoom

	if duration > 0.0:
		position_smoothing_enabled = false
		_current_tween = create_tween()
		_current_tween.set_parallel(true)
		_current_tween.tween_property(self, "global_position", new_target.global_position, duration).set_trans(Tween.TRANS_SINE)
		_current_tween.tween_property(self, "zoom", new_zoom, duration).set_trans(Tween.TRANS_SINE)
		_current_tween.finished.connect(func(): position_smoothing_enabled = smoothing_enabled)
	else:
		global_position = new_target.global_position
		zoom = new_zoom
		_current_tween = null
	return _current_tween

# Reset helper (honors lock) — no ternary
func reset_to_player(duration: float = 0.0) -> Tween:
	if not is_instance_valid(_player_target):
		push_warning("[PlayerCamera] No player target to reset to!")
		return null
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()

	_target = _player_target
	var z: Vector2 = _max_zoom_level
	if _zoom_locked:
		z = _locked_zoom_level
	_target_zoom = z

	if duration > 0.0:
		position_smoothing_enabled = false
		_current_tween = create_tween()
		_current_tween.set_parallel(true)
		_current_tween.tween_property(self, "global_position", _player_target.global_position, duration).set_trans(Tween.TRANS_SINE)
		_current_tween.tween_property(self, "zoom", z, duration).set_trans(Tween.TRANS_SINE)
		_current_tween.finished.connect(func(): position_smoothing_enabled = smoothing_enabled)
	else:
		global_position = _player_target.global_position
		zoom = z
		position_smoothing_enabled = smoothing_enabled
		_current_tween = null
	return _current_tween

# --- helpers ---
func _start_zoom_tween(target_zoom: Vector2, duration: float) -> void:
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()
	target_zoom.x = clampf(target_zoom.x, _min_zoom_level.x, _max_zoom_level.x)
	target_zoom.y = clampf(target_zoom.y, _min_zoom_level.y, _max_zoom_level.y)
	_target_zoom = target_zoom
	if duration <= 0.0:
		zoom = target_zoom
		return
	_current_tween = create_tween()
	_current_tween.tween_property(self, "zoom", target_zoom, duration).set_trans(Tween.TRANS_SINE)

func _resolve_target() -> void:
	if player_path != NodePath():
		var n := get_node_or_null(player_path)
		if n is Node2D:
			_target = n
			return
	if search_by_group:
		var first := get_tree().get_first_node_in_group("players")
		if first is Node2D:
			_target = first
			return
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
			_player_target = n
