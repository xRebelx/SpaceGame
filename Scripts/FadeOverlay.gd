# FadeOverlay.gd
extends ColorRect

@export var start_visible := false
@export_range(0.0, 1.0, 0.01) var start_alpha := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = start_visible
	modulate.a = start_alpha  # Control/ColorRect supports "modulate"

func fade_in(duration: float = 0.6) -> void:
	visible = true
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "modulate:a", 1.0, duration)
	await t.finished

func fade_out(duration: float = 0.6) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "modulate:a", 0.0, duration)
	await t.finished
	visible = false
