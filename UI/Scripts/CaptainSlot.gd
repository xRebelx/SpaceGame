# res://UI/Scripts/CaptainSlot.gd
# Attach to the root node of CaptainSlot.tscn
extends MarginContainer
class_name CaptainSlot

# Signal to tell the LoadGame screen "I was clicked"
signal captain_selected(captain_slot_instance) # <-- FIX: Removed the : CaptainSlot type hint

# --- Node References (Assumed from your description) ---
# Use unique names (%) in your CaptainSlot.tscn
@onready var name_label: Label = $%NameLabel
@onready var class_label: Label = $%ClassLabel
@onready var level_label: Label = $%LevelLabel
@onready var select_button: Button = $%SelectButton

var captain_name: String = ""
var captain_class: String = ""

func _ready() -> void:
	if not is_instance_valid(select_button):
		push_error("CaptainSlot: Missing %SelectButton")
		return
	select_button.pressed.connect(_on_select_button_pressed)
	set_selected(false)

# Function for visual feedback (similar to SaveSlot)
func set_selected(is_selected: bool) -> void:
	if is_selected:
		# Use the button's modulation to show selection
		select_button.modulate = Color("add8e6") # A light blue highlight
	else:
		select_button.modulate = Color.WHITE

# Called by LoadGame to populate this slot
func set_data(cap_name: String, cap_class_str: String, cap_level: int = 1) -> void:
	captain_name = cap_name
	captain_class = cap_class_str

	if is_instance_valid(name_label):
		name_label.text = captain_name
	
	if is_instance_valid(class_label):
		# Capitalize the first letter for display
		class_label.text = cap_class_str.capitalize()
		
	if is_instance_valid(level_label):
		# This is ready for when you implement levels
		level_label.text = "Lvl: %d" % cap_level

func _on_select_button_pressed() -> void:
	# Tell the parent (LoadGame) which slot was clicked
	emit_signal("captain_selected", self)
