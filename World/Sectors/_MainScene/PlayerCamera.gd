extends Camera2D
# Optional: class_name PlayerCamera

@export var search_by_group: bool = true           # find first node in "players" group
@export var player_path: NodePath                  # explicit path to Player (overrides group search if set)
@export var enable_rotation_follow: bool = false   # usually false for space shooters
@export var zoom_at_play: Vector2 = Vector2.ONE
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 8.0           # <- different name than built-in property

var _target: Node2D = null

func _ready() -> void:
	enabled = true                                  # replaces 'current = true' in Godot 4
	zoom = zoom_at_play
	position_smoothing_enabled = smoothing_enabled
	self.position_smoothing_speed = smoothing_speed # assign to built-in property

	_resolve_target()
	get_tree().node_added.connect(_on_node_added)   # rebind if Player is added later

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_target):
		return
	global_position = _target.global_position
	if enable_rotation_follow:
		rotation = _target.global_rotation

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
