extends Control

# This script is attached to OrbitUI.tscn
# Its only job is to emit a signal when the "Leave Orbit" button is pressed.

# --- FIX: Changed node name to match .tscn ---
@onready var leave_button: Button = %LeaveButton

func _ready() -> void:
	if not is_instance_valid(leave_button):
		push_warning("[OrbitUI] %LeaveButton not found!")
		return
	
	leave_button.pressed.connect(_on_leave_orbit_pressed)

func _on_leave_orbit_pressed() -> void:
	# Fire the global signal that the Player script will be listening for.
	EventBus.player_leave_orbit.emit()
