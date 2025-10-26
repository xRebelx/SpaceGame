extends Area2D
class_name BlackHoleGate

@export var target_sector_id: String = ""      # e.g. "MiningSector_1"
@export var target_gate_name: String = ""      # the gate node name in the target sector

# Bodies to ignore until they EXIT this area once
var _ignored: = {}  # Node -> bool

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	if _ignored.has(body):
		# Just arrived here; must leave and re-enter before we fire.
		return
	# Teleport to the target sector, spawning at the matching gate.
	if target_sector_id != "" and target_gate_name != "":
		UniverseManager.change_sector(target_sector_id, target_gate_name)

func _on_body_exited(body: Node) -> void:
	_ignored.erase(body)

# Called by UniverseManager after spawning the player here.
# This prevents immediate re-trigger until the player exits once.
func suppress_for(body: Node) -> void:
	_ignored[body] = true
