# res://SRC/persistence_manager.gd
extends Node
# Autoload as "PersistenceManager" (no class_name to avoid singleton clash)

# -----------------
# Constants
# -----------------
const SAVE_DIR: String             = "user://saves/"
const SAVE_FILE_EXTENSION: String  = ".dat"     # JSON payload
const META_FILE_EXTENSION: String  = ".meta"
const SCREENSHOT_EXTENSION: String = ".png"
const MAX_SAVE_FILES: int          = 15
const SNAPSHOT_HIDE_GROUP: String  = "ui_hide_on_snapshot"  # UI group to hide during screenshots

# --- ADD THIS ---
const _BUS_NAMES := ["Music", "GameEffects", "MenuEffects"]
# --- END ADD ---

var _pending_new_profile: CaptainProfile = null


func _ready() -> void:
	# This node must run while paused to take snapshots
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# -----------------
# Public helpers
# -----------------
func has_save() -> bool:
	return !get_save_files_with_metadata().is_empty()


func set_pending_new_profile(p: CaptainProfile) -> void:
	_pending_new_profile = p


func consume_pending_new_profile() -> CaptainProfile:
	var p: CaptainProfile = _pending_new_profile
	_pending_new_profile = null
	return p


# Return full PNG path for a given save file path
func get_screenshot_path_for_save(save_path: String) -> String:
	return save_path.trim_suffix(SAVE_FILE_EXTENSION) + SCREENSHOT_EXTENSION


# -----------------
# Create / Save / Load
# -----------------
func create_new_save() -> String:
	var save_files: Array = get_save_files_with_metadata()
	if save_files.size() >= MAX_SAVE_FILES:
		var oldest_save: Dictionary = save_files.back()
		delete_save(String(oldest_save.path))

	var timestamp: int = int(Time.get_unix_time_from_system())
	var new_path: String = SAVE_DIR + "save_" + str(timestamp) + SAVE_FILE_EXTENSION
	
	# Await the save_game function
	# This ensures the snapshot is finished before we return
	await save_game(new_path)
	
	return new_path


func save_game(save_path: String) -> void:
	if not (PlayerManager and UniverseManager and FactionManager):
		push_error("[PersistenceManager] One or more managers not found. Aborting save.")
		return

	if not (PlayerManager.captain_profile and PlayerManager.ship_data):
		push_error("[PersistenceManager] Player data is null. Aborting save.")
		return

	# --- ADD THIS BLOCK: Gather Audio Settings ---
	var audio_settings := {}
	for bus_name in _BUS_NAMES:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx != -1:
			audio_settings[bus_name] = {
				"db": AudioServer.get_bus_volume_db(bus_idx),
				"mute": AudioServer.is_bus_mute(bus_idx)
			}
	# --- END ADD ---

	# 1) Gather data
	var save_data: Dictionary = {
		"player_profile_data": PlayerManager.captain_profile.save_data(),
		"ship_data_data": PlayerManager.ship_data.save_data(),
		
		"faction_data": FactionManager.faction_data.save_data(),

		"current_sector_id": UniverseManager.get_current_sector_id(),
		"player_position": {
			"x": UniverseManager.get_player_position().x,
			"y": UniverseManager.get_player_position().y
		},
		"planet_orbital_states": UniverseManager.get_planet_states(),
		
		"audio_settings": audio_settings # <-- ADD THIS LINE
	}

	# 2) Write JSON
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("[PersistenceManager] Failed to open save for write. Error: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(save_data, "  "))
	f.close()

	# 3) Write metadata
	var meta_path: String = save_path.trim_suffix(SAVE_FILE_EXTENSION) + META_FILE_EXTENSION
	var png_path: String  = get_screenshot_path_for_save(save_path)

	var metadata: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"save_name": PlayerManager.captain_profile.captain_name,
		"class_id": PlayerManager.captain_profile.class_id,
		"screenshot_path": png_path
	}

	var mf: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	if mf:
		mf.store_string(JSON.stringify(metadata, "  "))
		mf.close()

	# Await the async screenshot function
	# 4) Trigger async screenshot without UI
	await take_snapshot(png_path)

	# 5) Let listeners know a save was triggered
	EventBus.game_save_successful.emit()


func load_game(save_path: String) -> void:
	if not FileAccess.file_exists(save_path):
		push_warning("[PersistenceManager] No save file found at: %s" % save_path)
		return

	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		push_error("[PersistenceManager] Failed to open save for read. Error: %s" % FileAccess.get_open_error())
		return

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed == null:
		push_error("[PersistenceManager] Failed to parse save file: %s" % save_path)
		return
	var loaded: Dictionary = parsed

	if not (PlayerManager and UniverseManager and FactionManager):
		push_error("[PersistenceManager] Managers missing; aborting load.")
		return

	# --- ADD THIS BLOCK: Load Audio Settings FIRST ---
	var audio_settings = loaded.get("audio_settings", {})
	for bus_name in audio_settings.keys():
		var settings = audio_settings[bus_name]
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx != -1:
			AudioServer.set_bus_volume_db(bus_idx, settings.get("db", 0.0))
			AudioServer.set_bus_mute(bus_idx, settings.get("mute", false))
	# --- END ADD ---

	if not PlayerManager.captain_profile:
		PlayerManager.captain_profile = CaptainProfile.new()
	if not PlayerManager.ship_data:
		PlayerManager.ship_data = ShipData.new()

	PlayerManager.captain_profile.load_data(loaded.get("player_profile_data", {}))
	PlayerManager.ship_data.load_data(loaded.get("ship_data_data", {}))
	
	FactionManager.faction_data.load_data(loaded.get("faction_data", {}))
	
	UniverseManager.set_planet_states(loaded.get("planet_orbital_states", {}).duplicate(true))

	var sector: String = loaded.get("current_sector_id", "HomeSector_1")
	if sector.is_empty():
		sector = "HomeSector_1"

	var pos: Variant = loaded.get("player_position")
	if pos is Dictionary:
		UniverseManager.set_pending_position_override(Vector2(pos.x, pos.y))
	else:
		UniverseManager.set_pending_position_override(Vector2.ZERO)

	UniverseManager.set_is_loading_from_save(true)
	EventBus.request_start_game.emit(sector, "PlayerSpawn")


# -----------------
# Screenshot helper (UI hidden, resized to 320x180)
# -----------------
func take_snapshot(png_save_path: String) -> void:
	# Hide UI group for one rendered frame, capture, then restore.
	var to_hide: Array[Node] = []
	var prev_vis: Array[bool] = []

	for n in get_tree().get_nodes_in_group(SNAPSHOT_HIDE_GROUP):
		if "visible" in n:
			to_hide.append(n)
			prev_vis.append(n.visible)
			n.visible = false

	# One frame for the world to render without UI
	await get_tree().process_frame
	await get_tree().process_frame

	var tex: Texture2D = get_viewport().get_texture()
	if tex:
		var img: Image = tex.get_image()
		if img:
			# Restore the thumbnail size the SaveSlot expects
			img.resize(320, 180, Image.INTERPOLATE_LANCZOS)
			var err: int = img.save_png(png_save_path)
			if err != OK:
				push_warning("[PersistenceManager] Snapshot PNG save error: %s" % str(err))

	# Restore UI
	for i in to_hide.size():
		var node: Node = to_hide[i]
		if "visible" in node:
			node.visible = prev_vis[i]

	# One more frame so UI returns cleanly
	await get_tree().process_frame
	await get_tree().process_frame


# -----------------
# Listing & Deleting saves
# -----------------
func get_save_files_with_metadata() -> Array:
	var saves: Array = []
	var d: DirAccess = DirAccess.open(SAVE_DIR)
	if d == null:
		return saves

	d.list_dir_begin()
	var entry_name: String = d.get_next()
	while entry_name != "":
		if !d.current_is_dir() and entry_name.ends_with(SAVE_FILE_EXTENSION):
			var dat: String = SAVE_DIR + entry_name
			var meta: String = dat.trim_suffix(SAVE_FILE_EXTENSION) + META_FILE_EXTENSION

			var meta_dict: Dictionary = {}
			if FileAccess.file_exists(meta):
				var mf: FileAccess = FileAccess.open(meta, FileAccess.READ)
				if mf:
					var parsed: Variant = JSON.parse_string(mf.get_as_text())
					if parsed != null:
						meta_dict = parsed
					mf.close()

			saves.append({"path": dat, "metadata": meta_dict})
		entry_name = d.get_next()
	d.list_dir_end()

	saves.sort_custom(func(a, b):
		return a.metadata.get("timestamp", "0") > b.metadata.get("timestamp", "0")
	)
	return saves


func delete_save(dat_path: String) -> void:
	var meta_path: String = dat_path.trim_suffix(SAVE_FILE_EXTENSION) + META_FILE_EXTENSION
	var png_path: String  = dat_path.trim_suffix(SAVE_FILE_EXTENSION) + SCREENSHOT_EXTENSION
	for p in [dat_path, meta_path, png_path]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
