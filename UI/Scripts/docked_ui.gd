# res://UI/Scripts/docked_ui.gd
extends Control

@onready var undock_button: Button = %UnDockBTN
# --- ADD THESE LINES ---
@onready var planet_name_label: Label = %PlanetName
@onready var planet_type_label: Label = %PlanetType
@onready var planet_faction_label: Label = %PlanetFaction
# --- END ADD ---

func _ready() -> void:
	if is_instance_valid(undock_button):
		undock_button.pressed.connect(_on_undock_pressed)
	else:
		push_error("[DockedUI] %UnDockBTN node not found!")
	
	# --- ADD THIS ---
	# Clear labels in case data isn't passed
	_set_labels("No Data", "N/A", "N/A")
	# --- END ADD ---

# --- ADD THIS FUNCTION ---
func apply_data(data: Variant) -> void:
	if data is PlanetData:
		var planet_data: PlanetData = data
		_set_labels(planet_data.planet_name, planet_data.planet_type, planet_data.planet_faction)
# --- END ADD ---

# --- ADD THIS FUNCTION ---
func _set_labels(p_name: String, p_type: String, p_faction: String) -> void:
	if is_instance_valid(planet_name_label):
		planet_name_label.text = p_name
	if is_instance_valid(planet_type_label):
		planet_type_label.text = "Type: %s" % p_type
	if is_instance_valid(planet_faction_label):
		planet_faction_label.text = "Faction: %s" % p_faction
# --- END ADD ---

func _on_undock_pressed() -> void:
	# Tell the system the player wants to undock.
	EventBus.player_initiated_undock.emit()
