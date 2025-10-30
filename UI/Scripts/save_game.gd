# SaveGame.gd
# This is the main UI screen for saving the game.
# It handles both creating new saves and overwriting existing ones.
# It's designed to run while the game is paused (process_mode = ALWAYS).
extends Control
signal canceled # Emitted when the user presses "Back" or ESC

# This is the scene for a single save slot row.
# !!! MUST be assigned in the Godot Inspector. !!!
@export var save_slot_scene: PackedScene

# --- Scene Node References ---
# These must use unique names (%) in the SaveGame.tscn file.
@onready var slot_container: Node          = $%SaveSlotContainer
@onready var save_button: Button           = $%SaveButton
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
# 1. GODOT LIFECYCLE & INITIALIZATION
# ==============================================================================

func _ready() -> void:
	# Set to "Always" so this UI runs even when the game tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Block clicks from passing through to the game world behind this screen.
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_dialog.hide()

	# --- Connect primary UI signals ---
	save_button.pressed.connect(_on_save_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# --- Connect modal dialog signals ---
	cancel_delete_button.pressed.connect(_on_cancel_delete_pressed)
	confirm_delete_button.pressed.connect(_on_confirm_delete_pressed)

	# Safety net: Always unpause if this UI is closed for any reason
	# (e.g., queue_free() called from another script).
	tree_exited.connect(_on_overlay_closed)

	# Initial population of the save slot list.
	populate_save_slots()
	_update_buttons()

# Allow the ESC key to function as the "Back" button.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


# ==============================================================================
# 2. CORE LOGIC & LIST MANAGEMENT
# ==============================================================================

# Clears and rebuilds the list of save slots from PersistenceManager.
func populate_save_slots() -> void:
	# Clear all existing slots first.
	for c in slot_container.get_children():
		c.queue_free()

	# Get all save files and create a slot instance for each.
	var save_files: Array = PersistenceManager.get_save_files_with_metadata()
	for item in save_files:
		# This is where 'save_slot_scene' (set in Inspector) is used.
		var slot: SaveSlot = save_slot_scene.instantiate()
		slot.slot_selected.connect(_on_slot_selected) # Listen for clicks *from* the slot
		slot_container.add_child(slot)
		slot.set_data(item.path, item.metadata) # Pass data *to* the slot

	# Reset selection state.
	currently_selected_slot = null
	_set_preview_texture(null)
	_update_buttons()


# ==============================================================================
# 3. UI SIGNAL CALLBACKS
# ==============================================================================

# This is the main save function. It's "async" (uses await) because it waits
# for PersistenceManager to finish writing files and taking a screenshot.
func _on_save_pressed() -> void:
	# 1. Give immediate feedback via the HUD (e.g., "Saving...").
	if EventBus and EventBus.has_signal("save_notify"):
		EventBus.save_notify.emit("Saving Game...")

	# 2. Disable buttons to prevent double-clicking while 'await' is running.
	save_button.disabled = true
	delete_button.disabled = true
	
	var saved_path: String = ""

	# 3. Check if we are overwriting or creating a new save.
	if currently_selected_slot != null:
		# --- OVERWRITE existing save ---
		if not PersistenceManager.has_method("save_game"):
			push_error("[SaveGame] PersistenceManager.save_game(save_path) not found.")
			if EventBus and EventBus.has_signal("save_notify"):
				EventBus.save_notify.emit("Save Failed")
			_update_buttons() # Re-enable buttons on fail
			return
			
		saved_path = currently_selected_slot.save_file_path
		
		# This is the magic! We wait here until the save is 100% done.
		await PersistenceManager.save_game(saved_path)
		
	else:
		# --- CREATE NEW save file ---
		if not PersistenceManager.has_method("create_new_save"):
			push_error("[SaveGame] create_new_save() missing on PersistenceManager.")
			if EventBus and EventBus.has_signal("save_notify"):
				EventBus.save_notify.emit("Save Failed")
			_update_buttons() # Re-enable buttons on fail
			return
		
		# We also wait for a new save to complete.
		saved_path = await PersistenceManager.create_new_save()
		
		if saved_path.is_empty():
			push_error("[SaveGame] Could not detect new save path.")
			# We'll just fall through and repopulate the list anyway.
	
	# --- THIS CODE RUNS *AFTER* THE 'await' IS COMPLETE ---
	
	# 4. Now that the await is done, the .dat and .png are on disk.
	#    We can safely repopulate the list to show the new/updated entry.
	populate_save_slots()
	
	# 5. Reselect the slot we just saved so the user sees it highlighted.
	_reselect_slot_by_path(saved_path)

	# 6. Update the big preview image with the new snapshot.
	var new_slot_node := _find_slot_by_path(saved_path)
	if new_slot_node and new_slot_node is SaveSlot:
		_set_preview_texture(_get_preview_for_slot(new_slot_node as SaveSlot))

	# 7. Send final "Game Saved!" message to the HUD.
	if EventBus and EventBus.has_signal("save_notify"):
		EventBus.save_notify.emit("Game Saved!")
	
	# 8. Re-enable buttons.
	_update_buttons()

# Called when a SaveSlot instance emits its 'slot_selected' signal.
func _on_slot_selected(slot_instance: SaveSlot) -> void:
	if currently_selected_slot == slot_instance:
		# Clicked the same slot again: deselect it.
		slot_instance.set_selected(false)
		currently_selected_slot = null
		_set_preview_texture(null)
	else:
		# Clicked a new slot: deselect old, select new.
		if currently_selected_slot:
			currently_selected_slot.set_selected(false)
		slot_instance.set_selected(true)
		currently_selected_slot = slot_instance

		# Update the big preview image
		var tex: Texture2D = _get_preview_for_slot(slot_instance)
		_set_preview_texture(tex)

	_update_buttons()

# Show the delete confirmation modal.
func _on_delete_pressed() -> void:
	if currently_selected_slot == null:
		return
	# Pre-fill the modal's preview image with the one we're about to delete
	var tex: Texture2D = _get_preview_for_slot(currently_selected_slot)
	_set_preview_texture(tex) # This sets the main preview, which is fine
	confirmation_dialog.show()

# Close the modal, do nothing.
func _on_cancel_delete_pressed() -> void:
	confirmation_dialog.hide()

# User confirmed deletion.
func _on_confirm_delete_pressed() -> void:
	confirmation_dialog.hide()
	if currently_selected_slot:
		# 1. Tell PersistenceManager to delete the .dat, .meta, and .png files
		PersistenceManager.delete_save(currently_selected_slot.save_file_path)
		# 2. Remove the UI slot from the list
		currently_selected_slot.queue_free()
		# 3. Reset state
		currently_selected_slot = null
		_set_preview_texture(null)
		_update_buttons()

# Main "Back" or "Cancel" button.
func _on_cancel_pressed() -> void:
	# CRITICAL: Always unpause the game when leaving this screen.
	PauseManager.unpause_game()
	canceled.emit() # For MainMenu, if it's listening
	queue_free() # Close this UI screen.

# Safety net attached to 'tree_exited'.
func _on_overlay_closed() -> void:
	# This ensures if queue_free() is called from anywhere,
	# we *always* unpause the game.
	PauseManager.unpause_game()


# ==============================================================================
# 4. INTERNAL HELPER FUNCTIONS
# ==============================================================================

# --- UI State Helpers ---

# Updates the 'disabled' state of buttons based on current selection.
func _update_buttons() -> void:
	if currently_selected_slot != null:
		# --- An existing slot IS selected ---
		save_button.text = "Overwrite"
		save_button.disabled = false
		delete_button.disabled = false
	else:
		# --- NO slot is selected (creating a new save) ---
		save_button.text = "Save New"
		
		# Check if the PersistenceManager can create new saves
		var can_new := PersistenceManager and PersistenceManager.has_method("create_new_save")
		save_button.disabled = not can_new
		
		# Can't delete if nothing is selected
		delete_button.disabled = true

# Sets the main preview image.
func _set_preview_texture(tex: Texture2D) -> void:
	if not is_instance_valid(save_image):
		return
	save_image.texture = tex
	save_image.visible = (tex != null)

# --- Slot Management Helpers ---

# Finds the instanced SaveSlot node that corresponds to a file path.
func _find_slot_by_path(path: String) -> Node:
	for c in slot_container.get_children():
		# This relies on SaveSlot.gd having a 'save_file_path' variable.
		if "save_file_path" in c and c.save_file_path == path:
			return c
	return null

# Finds and re-selects a specific slot, used after saving.
func _reselect_slot_by_path(path: String) -> void:
	var slot := _find_slot_by_path(path)
	if slot and slot is SaveSlot:
		if currently_selected_slot and is_instance_valid(currently_selected_slot):
			currently_selected_slot.set_selected(false)
		(slot as SaveSlot).set_selected(true)
		currently_selected_slot = slot
	_update_buttons() # Make sure buttons reflect this new selection

# --- Texture/Preview Loading Helpers ---

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
		tr_unique = slot.get_node_or_null("%ScreenshotRect") # common name in save_slot.gd
		
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
		push_warning("[SaveGame] Failed to load image from: " + p)
		return null
	
	var tex := ImageTexture.create_from_image(img)
	return tex
