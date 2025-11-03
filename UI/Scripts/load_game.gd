# res://UI/Scripts/load_game.gd
extends Control
signal canceled # Emitted when the user presses "Back" or ESC

# ==============================================================================
# 1. EXPORTS & NODE REFERENCES
# ==============================================================================

# !!! MUST be assigned in the Godot Inspector. !!!
@export var save_slot_scene: PackedScene
@export var captain_slot_scene: PackedScene # <-- This is the new export

# --- Scene Node References ---
# These must use unique names (%) in the LoadGame.tscn file.
@onready var captain_container: Node = $%CaptainInfoContainer
@onready var save_slot_container: Node = $%SaveSlotContainer
@onready var load_button: Button = $%LoadButton
@onready var delete_button: Button = $%DeleteButton
@onready var cancel_button: Button = $%BackButton

# References for the "Confirm Delete" modal
@onready var confirmation_dialog: Control = $%ConfirmationDialogue
@onready var cancel_delete_button: Button = $%CancelDelete
@onready var confirm_delete_button: Button = $%ConfirmDelete

# The big preview image shown on the side
@onready var save_image: TextureRect = $%SaveImage

# --- State ---
# Dictionary to hold all save data, grouped by captain name
var _all_saves_by_captain: Dictionary = {}
# Tracks the currently selected UI slots
var _currently_selected_captain_slot: CaptainSlot = null
var _currently_selected_save_slot: SaveSlot = null


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

	# --- FIX: REMOVED THIS LINE ---
	# Safety net: Always unpause if this UI is closed for any reason.
	# tree_exited.connect(_on_overlay_closed)
	# --- END FIX ---
	
	# Initial population of the UI
	_build_grouped_ui()
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

# Clears and rebuilds the entire UI from scratch
func _build_grouped_ui() -> void:
	# 1. Process all save files into a grouped dictionary
	_process_and_group_saves()
	
	# 2. Populate the left column (Captains)
	_populate_captain_list()
	
	# 3. Clear the right column (Saves)
	_clear_save_list()
	
	# 4. Select the first captain by default, if one exists
	if not _all_saves_by_captain.is_empty():
		if captain_container.get_child_count() > 0:
			var first_captain_slot = captain_container.get_child(0) as CaptainSlot
			if first_captain_slot:
				_on_captain_selected(first_captain_slot)

# Reads all save metadata and organizes it by captain name
func _process_and_group_saves() -> void:
	_all_saves_by_captain.clear()
	var save_files: Array = PersistenceManager.get_save_files_with_metadata()
	
	for save_item in save_files:
		var metadata: Dictionary = save_item.metadata
		var captain_name: String = metadata.get("save_name", "Unknown Captain")
		
		# If this is the first save for this captain, create an entry
		if not _all_saves_by_captain.has(captain_name):
			_all_saves_by_captain[captain_name] = {
				"class_str": metadata.get("class_id", ""),
				"saves": []
			}
		
		# Add this save file to this captain's list
		_all_saves_by_captain[captain_name].saves.append(save_item)

# Populates the left column with captain slots
func _populate_captain_list() -> void:
	# Clear existing captain slots
	for child in captain_container.get_children():
		child.queue_free()
		
	if not is_instance_valid(captain_slot_scene):
		push_error("[LoadGame] 'Captain Slot Scene' is not assigned in the Inspector!")
		return

	# Create a slot for each captain
	for captain_name in _all_saves_by_captain.keys():
		var captain_data = _all_saves_by_captain[captain_name]
		
		var slot: CaptainSlot = captain_slot_scene.instantiate()
		slot.captain_selected.connect(_on_captain_selected)
		captain_container.add_child(slot)
		
		# TODO: Pass level data when you implement it
		slot.set_data(captain_name, captain_data.class_str, 1)

# Populates the right column with save files for the chosen captain
func _populate_save_list_for_captain(captain_name: String) -> void:
	_clear_save_list()
	
	if not _all_saves_by_captain.has(captain_name):
		push_warning("[LoadGame] No save data found for captain: " + captain_name)
		return
		
	if not is_instance_valid(save_slot_scene):
		push_error("[LoadGame] 'Save Slot Scene' is not assigned in the Inspector!")
		return

	var save_items: Array = _all_saves_by_captain[captain_name].saves
	for item in save_items:
		var slot: SaveSlot = save_slot_scene.instantiate()
		slot.slot_selected.connect(_on_save_slot_selected) # Listen for clicks
		save_slot_container.add_child(slot)
		slot.set_data(item.path, item.metadata) # Pass data

# Empties the right column (save slots)
func _clear_save_list() -> void:
	for child in save_slot_container.get_children():
		child.queue_free()
	_currently_selected_save_slot = null
	_set_preview_texture(null)
	_update_buttons()

# Updates the 'disabled' state of buttons based on current selection.
func _update_buttons() -> void:
	var is_save_selected = (_currently_selected_save_slot != null)
	load_button.disabled = not is_save_selected
	delete_button.disabled = not is_save_selected


# ==============================================================================
# 4. UI SIGNAL CALLBACKS
# ==============================================================================

# --- COLUMN 1 (CAPTAIN) ---
# Called when a CaptainSlot instance emits its 'captain_selected' signal.
func _on_captain_selected(slot_instance: CaptainSlot) -> void:
	if _currently_selected_captain_slot == slot_instance:
		return # Already selected

	# Deselect old captain slot
	if is_instance_valid(_currently_selected_captain_slot):
		_currently_selected_captain_slot.set_selected(false)
		
	# Select new captain slot
	_currently_selected_captain_slot = slot_instance
	_currently_selected_captain_slot.set_selected(true)
	
	# Populate the save list for this captain
	_populate_save_list_for_captain(slot_instance.captain_name)

# --- COLUMN 2 (SAVES) ---
# Called when a SaveSlot instance emits its 'slot_selected' signal.
func _on_save_slot_selected(slot_instance: SaveSlot) -> void:
	if _currently_selected_save_slot == slot_instance:
		# Clicked the same slot again: deselect it.
		slot_instance.set_selected(false)
		_currently_selected_save_slot = null
		_set_preview_texture(null)
	else:
		# Clicked a new slot: deselect old, select new.
		if is_instance_valid(_currently_selected_save_slot):
			_currently_selected_save_slot.set_selected(false)
		slot_instance.set_selected(true)
		_currently_selected_save_slot = slot_instance

		# Update the big preview image
		var tex: Texture2D = _get_preview_for_slot(slot_instance)
		_set_preview_texture(tex)
	
	_update_buttons()

# --- MAIN BUTTONS ---
# Main "Load" button.
func _on_load_button_pressed() -> void:
	if _currently_selected_save_slot != null:
		# 1. Unpause the game (loading will take over).
		PauseManager.unpause_game()
		# 2. Tell PersistenceManager to load this file path.
		PersistenceManager.load_game(_currently_selected_save_slot.save_file_path)
		# 3. Close this screen.
		queue_free()

# Main "Delete" button.
func _on_delete_button_pressed() -> void:
	if _currently_selected_save_slot != null:
		# Show the confirmation modal.
		var tex: Texture2D = _get_preview_for_slot(_currently_selected_save_slot)
		_set_preview_texture(tex) # Use the main preview image for the modal
		confirmation_dialog.show()

# Main "Back" or "Cancel" button.
func _on_cancel_button_pressed() -> void:
	# CRITICAL: Always unpause the game when leaving this screen.
	PauseManager.unpause_game()
	canceled.emit() # For MainMenu, if it's listening
	queue_free() # Close this UI screen.
	
# --- MODAL DIALOG CALLBACKS ---
# "Cancel" button inside the delete modal.
func _on_cancel_delete_pressed() -> void:
	confirmation_dialog.hide()

# "Delete" button inside the delete modal.
func _on_confirm_delete_pressed() -> void:
	confirmation_dialog.hide()
	if not is_instance_valid(_currently_selected_save_slot):
		return
	if not is_instance_valid(_currently_selected_captain_slot):
		return
		
	var captain_name: String = _currently_selected_captain_slot.captain_name
	var save_path_to_delete: String = _currently_selected_save_slot.save_file_path

	# 1. Tell PersistenceManager to delete the files.
	PersistenceManager.delete_save(save_path_to_delete)
	
	# 2. Remove the save from our internal dictionary
	var captain_data = _all_saves_by_captain[captain_name]
	for i in range(captain_data.saves.size() - 1, -1, -1): # Iterate backwards
		var save_item = captain_data.saves[i]
		if save_item.path == save_path_to_delete:
			captain_data.saves.remove_at(i)
			break
			
	# 3. If that was the last save for this captain, remove the captain
	if captain_data.saves.is_empty():
		_all_saves_by_captain.erase(captain_name)
		_build_grouped_ui() # Rebuild everything
	else:
		# 4. Just refresh the save list for the current captain
		_populate_save_list_for_captain(captain_name)
		
	# 5. Reset state
	_currently_selected_save_slot = null
	_set_preview_texture(null)
	_update_buttons()


# --- FIX: REMOVED THIS ENTIRE FUNCTION ---
# Safety net attached to 'tree_exited'.
# func _on_overlay_closed() -> void:
# 	# This ensures if queue_free() is called from anywhere,
# 	# we *always* unpause the game.
# 	PauseManager.unpause_game()
# --- END FIX ---


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
	var meta: Dictionary = {}
	if slot.has_method("get_metadata"):
		var maybe_meta: Variant = slot.call("get_metadata")
		if typeof(maybe_meta) == TYPE_DICTIONARY:
			meta = maybe_meta as Dictionary

	# 3. Resolve and load the texture from disk using the metadata.
	return _resolve_preview_texture(slot.save_file_path, meta)

# Tries to pull the texture *directly from the SaveSlot scene's nodes*.
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
