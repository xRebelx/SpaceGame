# res://SRC/PauseManager.gd
extends Node

## Manages the game's pause state.
## UI elements that need to run while paused must have their
## Process Mode set to "Always" in the Inspector.

func _ready() -> void:
	# Ensure this node can run while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS


func pause_game() -> void:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		(ml as SceneTree).paused = true
	else:
		push_warning("[PauseManager] No SceneTree to pause.")

func unpause_game() -> void:
	var ml := Engine.get_main_loop()
	if ml is SceneTree:
		(ml as SceneTree).paused = false
	else:
		push_warning("[PauseManager] No SceneTree to unpause.")

func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	print("[PauseManager] Pause Toggled: ", get_tree().paused)
