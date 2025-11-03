# res://UI/Scripts/save_game.gd
extends Control
signal canceled # Emitted when the user presses "Back" or ESC

# ==============================================================================
# 1. EXPORTS & NODE REFERENCES
# ==============================================================================

# !!! MUST be assigned in the Godot Inspector. !!!
@export var save_slot_scene: PackedScene
@export var captain_slot_scene: PackedScene # <-- This must be assigned

# --- Scene Node References ---
@onready var captain_container: Node = $%CaptainInfoContainer # <-- Must be empty in the editor
@onready var slot_container: Node = $%SaveSlotContainer
@onready var save_button: Button = $%SaveButton
@onready var delete_button: Button = $%DeleteButton
@onready var cancel_button: Button = $%BackButton

# References for the "Confirm Delete" modal
@onready var confirmation_dialog: Control = $%ConfirmationDialogue
@onready var cancel_delete_button: Button = $%CancelDelete
@onready var confirm_delete_button: Button = $%ConfirmDelete

# The big preview image shown on the side
@onready var save_image: TextureRect = $%SaveImage

# --- State ---
var currently_selected_slot: SaveSlot = null


# ==============================================================================
# 1. GODOT LIFECYCLE & INITIALIZATION
# ==============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_dialog.hide()

	save_button.pressed.connect(_on_save_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	cancel_delete_button.pressed.connect(_on_cancel_delete_pressed)
	confirm_delete_button.pressed.connect(_on_confirm_delete_pressed)

	# --- FIX: REMOVED THIS LINE ---
	# tree_exited.connect(_on_overlay_closed)
	# --- END FIX ---

	# Deferring these is still the correct way to ensure
	# PlayerManager is ready.
	call_deferred("_populate_captain_info")
	call_deferred("populate_save_slots")
	call_deferred("_update_buttons")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


# ==============================================================================
# 2. CORE LOGIC & LIST MANAGEMENT
# ==============================================================================

# Populates the captain info container with the CURRENTLY active captain
func _populate_captain_info() -> void:
	if not is_instance_valid(captain_container):
		push_error("[SaveGame] Missing %CaptainInfoContainer node!")
		return
		
	if not is_instance_valid(captain_slot_scene):
		push_error("[SaveGame] 'Captain Slot Scene' is not assigned in the Inspector!")
		return
		
	if not PlayerManager or not is_instance_valid(PlayerManager.captain_profile):
		push_error("[SaveGame] PlayerManager or CaptainProfile is not valid. Cannot display info.")
		return

	# Clear any placeholders
	for child in captain_container.get_children():
		child.queue_free()

	var profile: CaptainProfile = PlayerManager.captain_profile
	
	var cap_name: String = profile.captain_name
	var class_str: String = profile.class_id.capitalize()
	# var cap_level: int = 1 # TODO: Get this from the profile when ready

	var slot: CaptainSlot = captain_slot_scene.instantiate()
	
	captain_container.add_child(slot) 
	
	slot.set_data(cap_name, class_str, 1)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- MODIFIED: Clears and rebuilds the list of save slots from PersistenceManager ---
func populate_save_slots() -> void:
	# Clear existing slots
	for c in slot_container.get_children():
		c.queue_free()

	# --- NEW: Filter saves by current captain ---
	var all_save_files: Array = PersistenceManager.get_save_files_with_metadata()
	var current_captain_name: String = ""
	
	if PlayerManager and is_instance_valid(PlayerManager.captain_profile):
		current_captain_name = PlayerManager.captain_profile.captain_name
	
	if current_captain_name.is_empty():
		push_error("[SaveGame] Could not get current captain name! Aborting slot population.")
		return
	
	print("[SaveGame] Populating saves for captain: ", current_captain_name)
	
	var filtered_saves: Array = []
	for item in all_save_files:
		var metadata: Dictionary = item.get("metadata", {})
		var save_name: String = metadata.get("save_name", "")
		# Only add saves that match the currently active captain
		if save_name == current_captain_name:
			filtered_saves.append(item)
	# --- END OF NEW LOGIC ---

	# Now, iterate over the *filtered* list
	for item in filtered_saves:
		var slot: SaveSlot = save_slot_scene.instantiate()
		slot.slot_selected.connect(_on_slot_selected)
		slot_container.add_child(slot)
		slot.set_data(item.path, item.metadata)

	currently_selected_slot = null
	_set_preview_texture(null)
	_update_buttons()


# ==============================================================================
# 3. UI SIGNAL CALLBACKS
# ==============================================================================

func _on_save_pressed() -> void:
	if EventBus and EventBus.has_signal("save_notify"):
		EventBus.save_notify.emit("Saving Game...")

	save_button.disabled = true
	delete_button.disabled = true
	
	var saved_path: String = ""

	if currently_selected_slot != null:
		if not PersistenceManager.has_method("save_game"):
			push_error("[SaveGame] PersistenceManager.save_game(save_path) not found.")
			if EventBus and EventBus.has_signal("save_notify"):
				EventBus.save_notify.emit("Save Failed")
			_update_buttons()
			return
			
		saved_path = currently_selected_slot.save_file_path
		
		await PersistenceManager.save_game(saved_path)
		
	else:
		if not PersistenceManager.has_method("create_new_save"):
			push_error("[SaveGame] create_new_save() missing on PersistenceManager.")
			if EventBus and EventBus.has_signal("save_notify"):
				EventBus.save_notify.emit("Save Failed")
			_update_buttons()
			return
		
		saved_path = await PersistenceManager.create_new_save()
		
		if saved_path.is_empty():
			push_error("[SaveGame] Could not detect new save path.")
			
	populate_save_slots()
	
	_reselect_slot_by_path(saved_path)

	var new_slot_node := _find_slot_by_path(saved_path)
	if new_slot_node and new_slot_node is SaveSlot:
		_set_preview_texture(_get_preview_for_slot(new_slot_node as SaveSlot))

	if EventBus and EventBus.has_signal("save_notify"):
		EventBus.save_notify.emit("Game Saved!")
	
	_update_buttons()

func _on_slot_selected(slot_instance: SaveSlot) -> void:
	if currently_selected_slot == slot_instance:
		slot_instance.set_selected(false)
		currently_selected_slot = null
		_set_preview_texture(null)
	else:
		if currently_selected_slot:
			currently_selected_slot.set_selected(false)
		slot_instance.set_selected(true)
		currently_selected_slot = slot_instance

		var tex: Texture2D = _get_preview_for_slot(slot_instance)
		_set_preview_texture(tex)

	_update_buttons()

func _on_delete_pressed() -> void:
	if currently_selected_slot == null:
		return
	var tex: Texture2D = _get_preview_for_slot(currently_selected_slot)
	_set_preview_texture(tex)
	confirmation_dialog.show()

func _on_cancel_delete_pressed() -> void:
	confirmation_dialog.hide()

func _on_confirm_delete_pressed() -> void:
	confirmation_dialog.hide()
	if currently_selected_slot:
		PersistenceManager.delete_save(currently_selected_slot.save_file_path)
		currently_selected_slot.queue_free()
		currently_selected_slot = null
		_set_preview_texture(null)
	_update_buttons()

func _on_cancel_pressed() -> void:
	PauseManager.unpause_game()
	
	# --- FIX FOR C++ ERROR ---
	# We defer the signal emission and the queue_free
	# to prevent a race condition with unpausing.
	# This is the correct Godot 4 syntax
	canceled.emit.call_deferred()
	call_deferred("queue_free")
	# --- END FIX ---

# --- FIX: REMOVED THIS ENTIRE FUNCTION ---
# func _on_overlay_closed() -> void:
# 	PauseManager.unpause_game()
# --- END FIX ---


# ==============================================================================
# 4. INTERNAL HELPER FUNCTIONS
# ==============================================================================

func _update_buttons() -> void:
	if currently_selected_slot != null:
		save_button.text = "Overwrite"
		save_button.disabled = false
		delete_button.disabled = false
	else:
		save_button.text = "Save New"
		
		var can_new := PersistenceManager and PersistenceManager.has_method("create_new_save")
		save_button.disabled = not can_new
		
		delete_button.disabled = true

func _set_preview_texture(tex: Texture2D) -> void:
	if not is_instance_valid(save_image):
		return
	save_image.texture = tex
	save_image.visible = (tex != null)

func _find_slot_by_path(path: String) -> Node:
	for c in slot_container.get_children():
		if "save_file_path" in c and c.save_file_path == path:
			return c
	return null

func _reselect_slot_by_path(path: String) -> void:
	var slot := _find_slot_by_path(path)
	if slot and slot is SaveSlot:
		if currently_selected_slot and is_instance_valid(currently_selected_slot):
			currently_selected_slot.set_selected(false)
		(slot as SaveSlot).set_selected(true)
		currently_selected_slot = slot
	_update_buttons()

func _get_preview_for_slot(slot: SaveSlot) -> Texture2D:
	if slot == null:
		return null

	var tex_from_slot: Texture2D = _extract_texture_from_slot(slot)
	if tex_from_slot:
		return tex_from_slot

	var meta: Dictionary = {}
	if slot.has_method("get_metadata"):
		var maybe_meta: Variant = slot.call("get_metadata")
		if typeof(maybe_meta) == TYPE_DICTIONARY:
			meta = maybe_meta as Dictionary

	return _resolve_preview_texture(slot.save_file_path, meta)

func _extract_texture_from_slot(slot: Node) -> Texture2D:
	if slot.has_method("get_preview_texture"):
		var t_any: Variant = slot.call("get_preview_texture")
		if t_any is Texture2D and t_any != null:
			return t_any as Texture2D

	var tr_unique: Node = slot.get_node_or_null("%SaveImage")
	if not tr_unique:
		tr_unique = slot.get_node_or_null("%ScreenshotRect")
		
	if tr_unique and tr_unique is TextureRect:
		var tex0: Texture2D = (tr_unique as TextureRect).texture
		if tex0:
			return tex0

	var candidates: PackedStringArray = ["Image", "Icon", "Thumbnail", "Preview"]
	for name_hint in candidates:
		var tr_hint: Node = slot.get_node_or_null(name_hint)
		if tr_hint and tr_hint is TextureRect:
			var tex1: Texture2D = (tr_hint as TextureRect).texture
			if tex1:
				return tex1

	for child in slot.get_children():
		if child is TextureRect:
			var tex2: Texture2D = (child as TextureRect).texture
			if tex2:
				return tex2
		if child is Control:
			for g in (child as Control).get_children():
				if g is TextureRect:
					var tex3: Texture2D = (g as TextureRect).texture
					if tex3:
						return tex3
	return null

func _resolve_preview_texture(save_path: String, metadata: Dictionary) -> Texture2D:
	var path_keys: PackedStringArray = ["screenshot_path", "thumbnail_path", "screenshot", "thumbnail", "image", "preview"]
	for k in path_keys:
		if metadata.has(k):
			var p: String = str(metadata[k])
			var tex_from_meta: Texture2D = _load_texture_from_path(p)
			if tex_from_meta:
				return tex_from_meta

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
