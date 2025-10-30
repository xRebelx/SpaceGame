# GalaxHUB.gd — HUD controller that owns the `%SaveNotify` Label
extends Control

@onready var save_notify: Label = $%SaveNotify

const FADE_TIME := 0.25
const HOLD_TIME := 1.5

var _tween: Tween

func _ready() -> void:
	if save_notify:
		save_notify.visible = false
		save_notify.modulate.a = 0.0
	EventBus.save_notify.connect(_on_save_notify)

func _on_save_notify(message: String) -> void:
	if not save_notify:
		return

	# Stop any previous tween so we can restart cleanly
	if _tween and _tween.is_running():
		_tween.kill()

	save_notify.text = message
	save_notify.visible = true

	if message == "Saving Game...":
		# Fade in and stay visible until the next message arrives
		_tween = create_tween()
		_tween.tween_property(save_notify, "modulate:a", 1.0, FADE_TIME)
		return

	# For "Game Saved!" (or any other final status): fade in, hold, then fade out
	_tween = create_tween()
	_tween.tween_property(save_notify, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(save_notify, "modulate:a", 0.0, FADE_TIME)
	_tween.finished.connect(func ():
		if is_equal_approx(save_notify.modulate.a, 0.0):
			save_notify.visible = false
	)
