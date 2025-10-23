extends Control
class_name DockedUI

## Emitted when the "UnDockBTN" is pressed.
signal undock_requested

# --- Node Caches ---
# We'll find these in _ready based on your screenshot
@onready var undock_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/UnDockBTN
# FIXED: Changed type from Label to RichTextLabel to match scene node
@onready var planet_name_label: RichTextLabel = $MarginContainer/VBoxContainer/PlanetName
@onready var faction_label: Label = $MarginContainer/VBoxContainer/VBoxContainer/OwnedFaction
@onready var shipyard_label: Label = $MarginContainer/VBoxContainer/VBoxContainer/HasShipyard
@onready var wilderness_label: Label = $MarginContainer/VBoxContainer/VBoxContainer/HasWilderness

var _current_planet: Node2D = null

func _ready() -> void:
	print("[DockedUI] _ready(). Finding nodes...")
	
	# --- Validate Nodes ---
	# Check if the paths from your screenshot are correct.
	if not is_instance_valid(undock_button):
		# FIXED: Convert NodePath to String using str() for concatenation
		push_error("[DockedUI] 'UnDockBTN' not found. Check path: " + str($MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/UnDockBTN.get_path()))
		return
	if not is_instance_valid(planet_name_label):
		push_warning("[DockedUI] 'PlanetName' label not found.")
	if not is_instance_valid(faction_label):
		push_warning("[DockedUI] 'OwnedFaction' label not found.")
	if not is_instance_valid(shipyard_label):
		push_warning("[DockedUI] 'HasShipyard' label not found.")
	if not is_instance_valid(wilderness_label):
		push_warning("[DockedUI] 'HasWilderness' label not found.")

	# --- Connect Signal ---
	if not undock_button.is_connected("pressed", Callable(self, "_on_undock_button_pressed")):
		undock_button.connect("pressed", Callable(self, "_on_undock_button_pressed"))
		print("[DockedUI] Connected UnDockBTN 'pressed' signal.")
		
	# Start invisible, UIManager will fade it in
	modulate.a = 0.0

## This is called by UIManager.gd
func set_from_planet(planet: Node2D) -> void:
	_current_planet = planet
	print("[DockedUI] set_from_planet(): ", planet.name)
	
	var pdata: PlanetData = planet.get("data")
	if not is_instance_valid(pdata):
		push_error("[DockedUI] PlanetData is null!")
		return
		
	if is_instance_valid(planet_name_label):
		planet_name_label.text = pdata.name
		
	if is_instance_valid(faction_label):
		faction_label.text = "Faction: " + pdata.faction
		
	if is_instance_valid(shipyard_label):
		shipyard_label.text = "Shipyard: " + ("Yes" if pdata.has_shipyard else "No")
		
	if is_instance_valid(wilderness_label):
		wilderness_label.text = "Wilderness: " + ("Yes" if pdata.has_wilderness else "No")
		
	# Fade in the UI
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3) # Quick fade in

## Public function for UIManager to call
func fade_out(duration: float) -> void:
	print("[DockedUI] fade_out() called.")
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "modulate:a", 0.0, duration)
	await tw.finished
	print("[DockedUI] Fade out finished.")

## Internal signal handler
func _on_undock_button_pressed() -> void:
	print("[DockedUI] Undock button pressed. Emitting 'undock_requested'.")
	# Disable the button to prevent double-clicks
	if is_instance_valid(undock_button):
		undock_button.disabled = true
	emit_signal("undock_requested")
