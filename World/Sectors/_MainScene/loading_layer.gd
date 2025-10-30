# res://World/Sectors/_MainScene/loading_layer.gd
extends Control
class_name LoadingLayer

## Fades a self-contained, instanced loading screen.

@export var fade_speed: float = 3.0
@export var loading_screen_scene: PackedScene # This is where you slot LoadingScreen.tscn

var _loading_screen_instance: Control = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

# --- NEW: Helper for instant-on ---
func show_overlay_instant() -> void:
	# Ensure we have a screen to show
	if not is_instance_valid(_loading_screen_instance):
		_instance_screen()
		
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 1.0

func show_overlay(block_input: bool = true) -> void:
	# Ensure we have a screen to show
	if not is_instance_valid(_loading_screen_instance):
		_instance_screen()
		
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP if block_input else Control.MOUSE_FILTER_PASS
	_fade_in()

func hide_overlay() -> void:
	_fade_out()

# --- Internal Fade Animations ---
func _fade_in() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0 / fade_speed)

func _fade_out() -> void:
	var tween := get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0 / fade_speed)
	tween.finished.connect(_on_fade_out_finished)

func _on_fade_out_finished() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# --- NEW: Clean up the instance ---
	if is_instance_valid(_loading_screen_instance):
		_loading_screen_instance.queue_free()
		_loading_screen_instance = null

# --- NEW: Instancing function ---
func _instance_screen() -> void:
	if is_instance_valid(_loading_screen_instance):
		return # Already exists
		
	if loading_screen_scene:
		_loading_screen_instance = loading_screen_scene.instantiate()
		add_child(_loading_screen_instance)
	else:
		push_warning("LoadingLayer: loading_screen_scene is not set!")
