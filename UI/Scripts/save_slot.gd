# Filename: save_slot.gd
# Attach to the root MarginContainer of your SaveSlot.tscn scene

extends MarginContainer 
class_name SaveSlot

# This signal tells the parent (LoadGame or SaveGame)
# that this slot was clicked.
signal slot_selected(slot_instance: SaveSlot)

# --- Unique Node References (from your .tscn file) ---
@onready var screenshot_rect = $%ScreenshotRect
@onready var timestamp_label = $%TimestampLabel
@onready var select_button: Button = $%SelectButton # Finds your internal button

# This variable will hold the full path, e.g., "user://saves/save_1.dat"
var save_file_path: String

func _ready():
	# Connect to the internal button's pressed signal
	select_button.pressed.connect(_on_select_button_pressed)
	# Ensure we start in the deselected state
	set_selected(false)

# --- Function for visual feedback ---
func set_selected(is_selected: bool):
	# Modulate the button itself to show selection, not the whole container
	if is_selected:
		select_button.modulate = Color("add8e6") # A light blue highlight
	else:
		select_button.modulate = Color.WHITE

# This function is called by the parent screen to set this slot's info
func set_data(path: String, metadata: Dictionary):
	save_file_path = path
	
	# Set the labels
	var save_name = metadata.get("save_name", "Save File")
	var save_time = metadata.get("timestamp", "---")
	
	# Combine name and time into your single label
	timestamp_label.text = "%s\n%s" % [save_name, save_time]
	
	# Load the screenshot
	var png_path = metadata.get("screenshot_path", "")
	if png_path != "" and FileAccess.file_exists(png_path):
		var img = Image.load_from_file(png_path)
		var tex = ImageTexture.create_from_image(img)
		screenshot_rect.texture = tex
	else:
		screenshot_rect.texture = null # Or preload a default image

func _on_select_button_pressed():
	# Tell the parent "I was clicked!" and pass ourselves
	emit_signal("slot_selected", self)
