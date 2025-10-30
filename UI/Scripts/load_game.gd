# LoadGame.gd
# This is the main UI screen for loading a game.
# It's nearly identical to SaveGame.gd but its primary action is loading.
# It's designed to run while the game is paused (process_mode = ALWAYS).
extends Control
signal canceled # Emitted when the user presses "Back" or ESC

# ==============================================================================
# 1. EXPORTS & NODE REFERENCES
# ==============================================================================

# This is the scene for a single save slot row.
# !!! MUST be assigned in the Godot Inspector. !!!
@export var save_slot_scene: PackedScene

# --- Scene Node References ---
# These must use unique names (%) in the LoadGame.tscn file.
@onready var slot_container: Node          = $%SaveSlotContainer
@onready var load_button: Button           = $%LoadButton
@onready var delete_button: Button         = $%DeleteButton
@onready var cancel_button: Button         = $%BackButton

# References for the "Confirm Delete" modal
@onready var confirmation_dialog: Control  = $%ConfirmationDialogue
@onready var cancel_delete_button: Button  = $%CancelDelete
@onready var confirm_delete_button: Button = $%ConfirmDelete

# The big preview image shown on the side
@onready var save_image: TextureRect       = $%SaveImage

# --- State ---
var currently_selected_slot: SaveSlot = null


# ==============================================================================
# 2. GODOT LIFECYCLE & INITIALIZATION
# ==============================================================================

func _ready() -> void:
	# Set to "Always" so this UI runs even when the game tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Add to this group so the snapshot-taker in PersistenceManager hides us.
	add_to_group("ui_hide_on_snapshot")
	
	# Block clicks from passing through to the game world behind this screen.
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_dialog.hide()

	# --- Connect primary UI signals ---
	load_button.pressed.connect(_on_load_button_pressed)
	delete_button.pressed.connect(_on_delete_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	# --- Connect modal dialog signals ---
	cancel_delete_button.pressed.connect(_on_cancel_delete_pressed)
	confirm_delete_button.pressed.connect(_on_confirm_delete_pressed)

	# Safety net: Always unpause if this UI is closed for any reason.
	tree_exited.connect(_on_overlay_closed)
	
	# Initial population of the save slot list.
	populate_save_slots()
	_update_buttons() # Start with buttons disabled

# Handle keyboard input for ESC and ENTER (in modal).
func _unhandled_input(event: InputEvent) -> void:
	if confirmation_dialog.visible:
		# If modal is open, ENTER = Confirm Delete
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			_on_confirm_delete_pressed()
			get_viewport().set_input_as_handled()
			return
	
	# If modal is closed (or open), ESC = Cancel
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel_button_pressed()
		get_viewport().set_input_as_handled()


# ==============================================================================
# 3. CORE LOGIC & LIST MANAGEMENT
# ==============================================================================

# Clears and rebuilds the list of save slots from PersistenceManager.
func populate_save_slots() -> void:
	# Clear all existing slots first.
	for child in slot_container.get_children():
		child.queue_free()

	# Get all save files and create a slot instance for each.
	var save_files: Array = PersistenceManager.get_save_files_with_metadata()
	for item in save_files:
		# This is where 'save_slot_scene' (set in Inspector) is used.
		var slot: SaveSlot = save_slot_scene.instantiate()
		slot.slot_selected.connect(_on_slot_selected) # Listen for clicks *from* the slot
		slot_container.add_child(slot)
		slot.set_data(item.path, item.metadata) # Pass data *to* the slot

# Updates the 'disabled' state of buttons based on current selection.
func _update_buttons() -> void:
	var is_slot_selected = (currently_selected_slot != null)
	load_button.disabled = not is_slot_selected
	delete_button.disabled = not is_slot_selected


# ==============================================================================
# 4. UI SIGNAL CALLBACKS
# ==============================================================================

# Called when a SaveSlot instance emits its 'slot_selected' signal.
func _on_slot_selected(slot_instance: SaveSlot) -> void:
	if currently_selected_slot == slot_instance:
		# Clicked the same slot again: deselect it.
		slot_instance.set_selected(false)
		currently_selected_slot = null
		_set_preview_texture(null)
	else:
		# Clicked a new slot: deselect old, select new.
		if currently_selected_slot != null:
			currently_selected_slot.set_selected(false)
		slot_instance.set_selected(true)
		currently_selected_slot = slot_instance

		# Update the big preview image
		var tex: Texture2D = _get_preview_for_slot(slot_instance)
		_set_preview_texture(tex)
	
	_update_buttons()

# Main "Load" button.
func _on_load_button_pressed() -> void:
	if currently_selected_slot != null:
		# 1. Unpause the game (loading will take over).
		PauseManager.unpause_game()
		# 2. Tell PersistenceManager to load this file path.
		PersistenceManager.load_game(currently_selected_slot.save_file_path)
		# 3. Close this screen.
		queue_free()

# Main "Delete" button.
func _on_delete_button_pressed() -> void:
	if currently_selected_slot != null:
		# Show the confirmation modal.
		var tex: Texture2D = _get_preview_for_slot(currently_selected_slot)
		_set_preview_texture(tex) # Use the main preview image for the modal
		confirmation_dialog.show()

# Main "Back" or "Cancel" button.
func _on_cancel_button_pressed() -> void:
	# CRITICAL: Always unpause the game when leaving this screen.
	PauseManager.unpause_game()
	canceled.emit() # For MainMenu, if it's listening
	queue_free() # Close this UI screen.

# --- Modal Dialog Callbacks ---

# "Cancel" button inside the delete modal.
func _on_cancel_delete_pressed() -> void:
	confirmation_dialog.hide()

# "Delete" button inside the delete modal.
func _on_confirm_delete_pressed() -> void:
	confirmation_dialog.hide()
	if currently_selected_slot != null:
		# 1. Tell PersistenceManager to delete the files.
		PersistenceManager.delete_save(currently_selected_slot.save_file_path)
		# 2. Remove the UI slot.
		currently_selected_slot.queue_free()
		# 3. Reset state.
		currently_selected_slot = null
		_set_preview_texture(null)
		_update_buttons()

# Safety net attached to 'tree_exited'.
func _on_overlay_closed() -> void:
	# This ensures if queue_free() is called from anywhere,
	# we *always* unpause the game.
	PauseManager.unpause_game()


# ==============================================================================
# 5. PREVIEW IMAGE HELPER FUNCTIONS
# ==============================================================================

# Main function to get a texture for a given slot.
func _get_preview_for_slot(slot: SaveSlot) -> Texture2D:
	if slot == null:
		return null

	# 1. Try to get the texture *already loaded* by the slot itself.
	var tex_from_slot: Texture2D = _extract_texture_from_slot(slot)
	if tex_from_slot:
		return tex_from_slot

	# 2. If that fails, get the metadata from the slot.
	# (SaveSlot.gd would need a 'get_metadata()' func for this to work)
	var meta: Dictionary = {}
	if slot.has_method("get_metadata"):
		var maybe_meta: Variant = slot.call("get_metadata")
		if typeof(maybe_meta) == TYPE_DICTIONARY:
			meta = maybe_meta as Dictionary

	# 3. Resolve and load the texture from disk using the metadata.
	return _resolve_preview_texture(slot.save_file_path, meta)

# Tries to pull the texture *directly from the SaveSlot scene's nodes*.
# This is a bit "hacky" but fast, as it avoids reloading from disk.
func _extract_texture_from_slot(slot: Node) -> Texture2D:
	# Best case: the slot has a dedicated getter.
	if slot.has_method("get_preview_texture"):
		var t_any: Variant = slot.call("get_preview_texture")
		if t_any is Texture2D and t_any != null:
			return t_any as Texture2D

	# Second best: find the %SaveImage or %ScreenshotRect node inside the slot.
	var tr_unique: Node = slot.get_node_or_null("%SaveImage")
	if not tr_unique:
		# Check for the name used in SaveSlot.tscn
		tr_unique = slot.get_node_or_null("%ScreenshotRect")
		
	if tr_unique and tr_unique is TextureRect:
		var tex0: Texture2D = (tr_unique as TextureRect).texture
		if tex0:
			return tex0

	# Third best: guess common names.
	var candidates: PackedStringArray = ["Image", "Icon", "Thumbnail", "Preview"]
	for name_hint in candidates:
		var tr_hint: Node = slot.get_node_or_null(name_hint)
		if tr_hint and tr_hint is TextureRect:
			var tex1: Texture2D = (tr_hint as TextureRect).texture
			if tex1:
				return tex1

	# Last resort: just find the first TextureRect with a texture.
	for child in slot.get_children():
		if child is TextureRect:
			var tex2: Texture2D = (child as TextureRect).texture
			if tex2:
				return tex2
		if child is Control: # Check one level deeper
			for g in (child as Control).get_children():
				if g is TextureRect:
					var tex3: Texture2D = (g as TextureRect).texture
					if tex3:
						return tex3
	return null

# Finds the texture path from metadata and tries to load it.
func _resolve_preview_texture(save_path: String, metadata: Dictionary) -> Texture2D:
	# 1. Try to find a path inside the metadata dictionary.
	var path_keys: PackedStringArray = ["screenshot_path", "thumbnail_path", "screenshot", "thumbnail", "image", "preview"]
	for k in path_keys:
		if metadata.has(k):
			var p: String = str(metadata[k])
			var tex_from_meta: Texture2D = _load_texture_from_path(p)
			if tex_from_meta:
				return tex_from_meta

	# 2. If no path in metadata, ask PersistenceManager (in case logic is complex).
	if PersistenceManager:
		if PersistenceManager.has_method("get_save_preview_texture"):
			var t: Texture2D = PersistenceManager.get_save_preview_texture(save_path)
			if t is Texture2D and t != null:
				return t
		if PersistenceManager.has_method("get_save_screenshot_path"):
			var pp: String = str(PersistenceManager.get_save_screenshot_path(save_path))
			var t2: Texture2D = _load_texture_from_path(pp)
			if t2:
				return t2
		if PersistenceManager.has_method("get_save_thumbnail_path"):
			var pp2: String = str(PersistenceManager.get_save_thumbnail_path(save_path))
			var t3: Texture2D = _load_texture_from_path(pp2)
			if t3:
				return t3

	return null

# The actual disk-loading function.
# IMPORTANT: This uses FileAccess/Image.load_from_file because
# ResourceLoader.load() is unreliable for 'user://' files created at runtime.
func _load_texture_from_path(p: String) -> Texture2D:
	if p.is_empty() or p == "null":
		return null
	
	if not FileAccess.file_exists(p):
		return null

	var img := Image.load_from_file(p)
	if img == null or img.is_empty():
		push_warning("[LoadGame] Failed to load image from: " + p)
		return null
	
	var tex := ImageTexture.create_from_image(img)
	return tex

# Sets the main preview image.
func _set_preview_texture(tex: Texture2D) -> void:
	if not is_instance_valid(save_image):
		return
	save_image.texture = tex
	save_image.visible = (tex != null)
