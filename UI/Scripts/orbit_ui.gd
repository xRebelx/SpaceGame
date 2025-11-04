extends Control

@onready var leave_button: Button = %LeaveButton
@onready var dock_button: Button = %DockButton # <-- ADD THIS

var _planet_data: PlanetData # <-- ADD THIS

func _ready() -> void:
	if not is_instance_valid(leave_button):
		push_warning("[OrbitUI] %LeaveButton not found!")
	else:
		leave_button.pressed.connect(_on_leave_orbit_pressed)

	# --- ADD THIS BLOCK ---
	if not is_instance_valid(dock_button):
		push_warning("[OrbitUI] %DockButton not found!")
	else:
		dock_button.pressed.connect(_on_dock_pressed)
	# --- END ADD ---

# --- ADD THIS FUNCTION ---
# Called by UIManager when show_screen() is used
func apply_data(data: Variant):
	if data is PlanetData:
		_planet_data = data
	elif is_instance_valid(dock_button):
		# No data? Disable the dock button.
		dock_button.disabled = true

func _on_leave_orbit_pressed() -> void:
	EventBus.player_leave_orbit.emit()

# --- ADD THIS FUNCTION ---
func _on_dock_pressed() -> void:
	if _planet_data:
		EventBus.player_initiated_dock.emit(_planet_data)
