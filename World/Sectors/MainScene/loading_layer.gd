# res://ui/loading_layer.gd
extends Control

@export var z_on_top: int = 999  # ensure it draws above other UI when shown

func _ready() -> void:
	# Good defaults
	layout_mode_full_rect()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = z_on_top

func show_overlay(block_input: bool = true) -> void:
	visible = true
	mouse_filter = block_input ? Control.MOUSE_FILTER_STOP : Control.MOUSE_FILTER_PASS

func hide_overlay() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func layout_mode_full_rect() -> void:
	# Convenience: ensure it fills the screen (same as Layout -> Full Rect)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
