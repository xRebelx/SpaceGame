# res://World/Sectors/_MainScene/main.gd
extends Node2D

# ---- Config ----
@export var DEV_AUTO_START: bool = false
@export var default_start_sector: String = "HomeSector_1"
@export var default_start_entry: String = "PlayerSpawn"
@export var default_player_ship_data: Resource = preload("res://Data/Ships/ShipData.tres")

const SectorManager = preload("res://SRC/SectorManager.gd")

# ---- Scene refs ----
@onready var world_root: Node = $WorldRoot
@onready var entities_root: Node = $Entities
@onready var player: Node2D = $Entities/Player
@onready var cam: Camera2D = $Entities/Camera2D
@onready var ui_layer: CanvasLayer = $UILayer
@onready var loading_layer: LoadingLayer = $UILayer/HUDRoot/LoadingLayer

# --- Pending warp trackers ---
var _pending_warp_sector_id: String = ""
var _pending_warp_gate_name: String = ""

# --- NEW: Pending dock tracker ---
var _pending_dock_data: PlanetData = null


func _ready() -> void:
	UniverseManager.init(world_root, entities_root)
	UniverseManager.set_player(player)

	# --- UIManager init logic ---
	var popup_root: Control = ui_layer.get_node_or_null("HUDRoot/PopupLayer")
	if popup_root == null:
		popup_root = ui_layer.get_node_or_null("PopupLayer") # Fallback
	
	if popup_root == null:
		push_error("[Main] PopupLayer not found. Expected UILayer/HUDRoot/PopupLayer.")
		return
	
	if "init" in UIManager:
		UIManager.init(popup_root)

	# Register sectors (scenes)
	UniverseManager.register_sector("HomeSector_1", "res://World/Sectors/HomeSector_1/HomeSector_1.tscn")
	UniverseManager.register_sector("MiningSector_1", "res://World/Sectors/MiningSector_1/MiningSector_1.tscn")

	# Register UI screens by name
	UIManager.register_screen("MainMenu", "res://UI/UI Scenes/MainMenu.tscn")
	UIManager.register_screen("CharacterCreate", "res://UI/UI Scenes/CharacterCreate.tscn")
	UIManager.register_screen("GalaxyHUD", "res://UI/UI Scenes/GalaxyHUD.tscn")
	UIManager.register_screen("SaveGame", "res://UI/UI Scenes/SaveGame.tscn")
	UIManager.register_screen("LoadGame", "res://UI/UI Scenes/LoadGame.tscn")
	UIManager.register_screen("OrbitUI", "res://UI/UI Scenes/OrbitUI.tscn")
	UIManager.register_screen("Options", "res://UI/UI Scenes/Options.tscn")
	UIManager.register_screen("DockedUI", "res://UI/UI Scenes/DockedUI.tscn")

	# --- ALL SIGNALS ---
	EventBus.request_show_screen.connect(_on_request_show_screen)
	EventBus.request_start_game.connect(_on_request_start_game)
	EventBus.new_game_confirmed.connect(_on_new_game_confirmed)
	
	EventBus.player_initiated_warp.connect(_on_player_initiated_warp)
	EventBus.blackout_complete.connect(_on_blackout_complete)
	UniverseManager.sector_swap_complete.connect(_on_sector_swap_complete)

	EventBus.player_initiated_dock.connect(_on_player_initiated_dock)
	EventBus.sector_intro_complete.connect(_on_intro_complete) # main.gd now listens for this
	EventBus.player_initiated_undock.connect(_on_player_initiated_undock)
	# --- END ALL SIGNALS ---

	# Boot flow
	if DEV_AUTO_START:
		var dev_profile := CaptainProfile.new()
		dev_profile.credits = 5000
		dev_profile.captain_name = "Dev Captain"
		var dev_ship := default_player_ship_data.duplicate() as ShipData
		
		if player.has_method("apply_captain_and_ship_data"):
			player.call("apply_captain_and_ship_data", dev_profile, dev_ship)
		
		EventBus.player_initiated_warp.emit(default_start_sector, default_start_entry)
	else:
		_enter_frontend_mode()
		_on_request_show_screen.call_deferred("MainMenu", null)

# ===== FRONTEND/GAMEPLAY =====
func _enter_frontend_mode() -> void:
	player.visible = false
	if "freeze" in player:
		player.freeze = true
	player.set_physics_process(false)
	player.set_process(false)
	if is_instance_valid(cam):
		cam.enabled = false
	UIManager.hide_hud()
	EventBus.request_show_hud.emit(false) 

func _enter_gameplay_mode() -> void:
	if "freeze" in player:
		player.freeze = false
	player.set_process(true)
	player.visible = true
	if is_instance_valid(cam):
		cam.enabled = true
		cam.make_current()
	
	UIManager.show_hud()
	EventBus.request_show_hud.emit(true)
	
	var hud: Control = UIManager.get_hud()
	if hud and hud.has_method("connect_to_player_resources"):
		hud.call("connect_to_player_resources")
		hud.call("update_all_player_labels")

# ===== UI Flow =====
func _on_request_show_screen(screen_name: String, payload: Variant) -> void:
	if payload == null:
		UIManager.show_screen(screen_name)
	else:
		UIManager.show_screen(screen_name, payload)


# ===== New Game chain =====
func _on_new_game_confirmed(profile: Resource) -> void:
	if profile != null and player != null and player.has_method("apply_captain_and_ship_data"):
		
		var new_ship_data: ShipData
		if default_player_ship_data:
			new_ship_data = default_player_ship_data.duplicate() as ShipData
		else:
			push_error("default_player_ship_data not set in main.gd")
			new_ship_data = ShipData.new() # fallback
		
		if profile.class_id == "merchant":
			profile.credits = 5000
		else:
			profile.credits = 1500
			
		player.call("apply_captain_and_ship_data", profile, new_ship_data)
		
	EventBus.request_start_game.emit(default_start_sector, default_start_entry)

func _on_request_start_game(sector_id: String, entry: String) -> void:
	if MusicManager:
		MusicManager.stop_menu_music()

	if is_instance_valid(loading_layer):
		loading_layer.show_overlay_instant()

	if "close_current_screen" in UIManager:
		UIManager.close_current_screen()
	
	EventBus.player_initiated_warp.emit(sector_id, entry)


# ===== MODIFIED TRANSITION LOGIC =====

func _on_player_initiated_warp(sector_id: String, gate_name: String) -> void:
	"""
	STEP 1 (WARP): Player hit a gate (or new game started).
	Store targets and tell UIManager to fade to black.
	"""
	if player.has_method("initiate_warp"):
		player.initiate_warp()

	_pending_warp_sector_id = sector_id
	_pending_warp_gate_name = gate_name
	
	UIManager.begin_warp_transition()

func _on_player_initiated_dock(planet_data: PlanetData) -> void:
	"""
	STEP 1 (DOCK): Player clicked "Dock" in OrbitUI.
	Store data, disable player, close OrbitUI, and fade to black.
	"""
	_pending_dock_data = planet_data # Store the data
	
	if player.has_method("initiate_warp"):
		player.initiate_warp()
	if player.has_method("set_state_docking"):
		player.set_state_docking() # Tell player it's docking
		
	EventBus.request_close_screen.emit("OrbitUI") # Close the old UI
	UIManager.begin_warp_transition() # Start fade to black

func _on_blackout_complete() -> void:
	"""
	STEP 2: Screen is black.
	Tell UniverseManager to swap (if warping) OR show intro (if docking).
	"""
	if _pending_dock_data != null:
		# --- THIS IS THE FIX (DOCKING) ---
		var data_to_show = _pending_dock_data
		_pending_dock_data = null
		
		if MusicManager:
			MusicManager.stop_gameplay_music()
			
		# 1. Pre-load the DockedUI underneath the black intro screen
		UIManager.preload_screen_under_intro("DockedUI", data_to_show)
		# 2. Tell the intro screen to play its animation
		UIManager.show_sector_intro(data_to_show)
		# --- END FIX ---
		
	elif not _pending_warp_sector_id.is_empty():
		# This is the original logic (WARPING)
		if not player.visible:
			_enter_gameplay_mode()
		UniverseManager.change_sector(_pending_warp_sector_id, _pending_warp_gate_name)

func _on_sector_swap_complete(data: SectorData) -> void:
	"""
	STEP 3 (WARP): Scene is swapped.
	Tell UIManager to show the text animations.
	"""
	if is_instance_valid(loading_layer):
		loading_layer.hide_overlay()

	UIManager.show_sector_intro(data)

func _on_intro_complete() -> void:
	"""
	STEP 4: The IntroUI has finished its animation.
	If we were docking, show the DockedUI.
	If we were warping, re-enable the player.
	"""
	# Check the player's *actual* state
	if player.has_method("get") and player.get("_state") == player.State.DOCKING:
		
		UIManager.hide_hud()
		
		# --- ADD THIS LINE ---
		# The DockedUI is now visible, play the docked music.
		if MusicManager:
			MusicManager.play_docked_music()
		# --- END ADD ---

	else:
		# This was a normal warp, tell the player to re-enable physics
		if player.has_method("_on_sector_intro_complete"):
			player._on_sector_intro_complete()

func _on_player_initiated_undock() -> void:
	"""
	Player clicked "Undock" in DockedUI.
	Set player state back to ORBITING and show the OrbitUI.
	"""
	if not (player.has_method("set_state_orbiting") and player.has_method("get_orbiting_planet")):
		push_error("[Main] Player is missing required functions for undocking.")
		return

	# 1. Set player state
	player.set_state_orbiting()

	# 2. Get the planet data to pass back to the OrbitUI
	var planet_node: Node2D = player.get_orbiting_planet()
	var planet_data: PlanetData = null
	
	if is_instance_valid(planet_node) and "planet_data" in planet_node:
		planet_data = planet_node.planet_data
	else:
		push_warning("[Main] Could not get planet data from player's orbiting planet.")

	# --- ADD THIS BLOCK ---
	# 3. Stop docked music and resume gameplay music
	if MusicManager:
		MusicManager.stop_docked_music()
		MusicManager.play_gameplay_music()
	# --- END ADD ---

	# 4. Swap the UI screens
	EventBus.request_close_screen.emit("DockedUI")
	EventBus.request_show_screen.emit("OrbitUI", planet_data)
