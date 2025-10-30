# SRC/ui_manager.gd
extends Node

# --- Preload the intro screen ---
const SectorIntroScreen = preload("res://UI/UI Scenes/SectorIntroUI.tscn")

# ------------------------------
# CONFIG / STATE
# ------------------------------
var _screen_registry: Dictionary[String, String] = {}
var _current_screen: Control = null
var _hud: Control = null
var _popup_root: Control = null

# --- Tracker for the intro screen ---
var _current_intro_screen: SectorIntroUI = null


# ------------------------------
# LIFECYCLE
# ------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_try_connect_eventbus()
	await get_tree().process_frame
	_try_connect_eventbus()
	
	if not EventBus.is_connected("sector_intro_complete", Callable(self, "_on_sector_intro_complete")):
		EventBus.sector_intro_complete.connect(_on_sector_intro_complete)
	
	# --- NEW: Connect screen signals ---
	if not EventBus.is_connected("request_show_screen", Callable(self, "_on_request_show_screen")):
		EventBus.request_show_screen.connect(_on_request_show_screen)
	if not EventBus.is_connected("request_close_screen", Callable(self, "_on_request_close_screen")):
		EventBus.request_close_screen.connect(_on_request_close_screen)

	# --- NEW: Connect to Player state signals ---
	if not EventBus.is_connected("player_entered_orbit", Callable(self, "_on_player_entered_orbit")):
		EventBus.player_entered_orbit.connect(_on_player_entered_orbit)
	if not EventBus.is_connected("player_leave_orbit", Callable(self, "_on_player_leave_orbit")):
		EventBus.player_leave_orbit.connect(_on_player_leave_orbit)


func init(popup_root: Control) -> void:
	if not is_instance_valid(popup_root):
		push_error("[UIManager] init() called with an invalid popup_root.")
		return
	_popup_root = popup_root
	_try_connect_eventbus()


# ------------------------------
# REGISTRY
# ------------------------------
func register_screen(screen_name: String, scene_path: String) -> void:
	_screen_registry[screen_name] = scene_path

# ------------------------------
# SCREENS (MODIFIED)
# ------------------------------

func _on_request_show_screen(screen_name: String, payload: Variant) -> void:
	show_screen(screen_name, payload)

func _on_request_close_screen(screen_name: String) -> void:
	# --- NEW: Debug Print ---
	print("[UIManager] Received request_close_screen for: ", screen_name)
	
	# Check if the screen to be closed is the current screen
	if is_instance_valid(_current_screen) and _current_screen.name == screen_name:
		print("[UIManager] Closing current screen: ", _current_screen.name)
		close_current_screen()
	else:
		# This handles cases where a non-modal popup might be closed by name
		# For now, we only support closing the *current* main screen.
		if is_instance_valid(_current_screen):
			print("[UIManager] Request to close '%s', but current screen is '%s'. Ignoring." % [screen_name, _current_screen.name])
		else:
			print("[UIManager] Request to close '%s', but no screen is open. Ignoring." % screen_name)

func show_screen(screen_name: String, data: Variant = null) -> Control:
	if not is_instance_valid(_popup_root):
		push_error("[UIManager] show_screen() called, but init() was never called or popup_root is invalid.")
		return null
		
	if not _screen_registry.has(screen_name):
		push_warning("[UIManager] Unknown screen: %s" % screen_name)
		return null

	# --- MODIFICATION: Allow opening a screen on top of another ---
	# This is for things like Save/Load menus.
	# We will only close the *previous* screen if it's NOT the HUD.
	# For your new OrbitUI, it will open *over* the (hidden) HUD.
	if is_instance_valid(_current_screen):
		# --- FIX: Call close_current_screen to properly clear state ---
		close_current_screen()

	var scene_path: String = _screen_registry[screen_name]
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		push_warning("[UIManager] Could not load scene for '%s' at %s" % [screen_name, scene_path])
		return null

	var inst: Node = ps.instantiate()
	
	# --- NEW: Set the node's name to the registered screen name ---
	# This allows `_on_request_close_screen` to work correctly
	inst.name = screen_name
	
	if inst is Control:
		var c := inst as Control
		c.process_mode = Node.PROCESS_MODE_ALWAYS
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_popup_root.add_child(c)
		_current_screen = c
	else:
		# This case should ideally not happen for "screens"
		add_child(inst)
		_current_screen = null # Can't track non-control nodes this way

	if data != null and "apply_data" in inst:
		inst.apply_data(data)

	return _current_screen

func close_current_screen() -> void:
	if is_instance_valid(_current_screen):
		_current_screen.queue_free()
		_current_screen = null

# ------------------------------
# --- NEW: ORBIT STATE HANDLERS ---
# ------------------------------

func _on_player_entered_orbit(_planet_node: Node) -> void:
	print("[UIManager] Player entered orbit. Hiding HUD, showing OrbitUI.")
	hide_hud()
	show_screen("OrbitUI")

func _on_player_leave_orbit() -> void:
	print("[UIManager] Player left orbit. Closing screen, showing HUD.")
	# We can just call close_current_screen() because
	# OrbitUI *should* be the current screen.
	close_current_screen() 
	show_hud()

		
# ------------------------------
# HUD
# ------------------------------
func _ensure_hud() -> Control:
	if is_instance_valid(_hud):
		return _hud
		
	if not is_instance_valid(_popup_root):
		push_error("[UIManager] _ensure_hud() called, but init() was never called or popup_root is invalid.")
		return null

	var configured_path: String = _screen_registry.get("GalaxyHUD", "")
	var default_path: String = "res://UI/UI Scenes/GalaxyHUD.tscn"
	var path_to_use: String = configured_path if configured_path != "" else default_path

	var ps: PackedScene = load(path_to_use) as PackedScene
	if ps == null:
		push_warning("[UIManager] GalaxyHUD scene not found at: %s" % path_to_use)
		return null

	var node: Node = ps.instantiate()
	node.name = "GalaxyHUD" # Give it its name
	var ctrl: Control = node as Control
	if ctrl == null:
		push_warning("[UIManager] GalaxyHUD root must be a Control.")
		return null

	ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_popup_root.add_child(ctrl)
	
	ctrl.hide()
	_hud = ctrl
	return _hud

func get_hud() -> Control:
	return _ensure_hud()

func show_hud() -> void:
	var hud := _ensure_hud()
	if hud != null:
		hud.show()
	else:
		push_warning("[UIManager]   HUD is null (failed to ensure)")

func hide_hud() -> void:
	if is_instance_valid(_hud):
		_hud.hide()

func _try_connect_eventbus() -> void:
	if not Engine.has_singleton("EventBus"):
		return
	if not EventBus.is_connected("request_show_hud", Callable(self, "_on_request_show_hud")):
		EventBus.request_show_hud.connect(_on_request_show_hud)

func _on_request_show_hud(visible: bool) -> void:
	# --- NEW: Debug Print ---
	print("[UIManager] Received request_show_hud: ", visible)
	
	if visible:
		show_hud()
	else:
		hide_hud()


# ------------------------------
# UPDATED: WARP TRANSITION LOGIC
# ------------------------------
func begin_warp_transition() -> void:
	"""
	Called by main.gd.
	Instantiates the intro screen and fades in the blackout.
	"""
	if is_instance_valid(_current_intro_screen):
		_current_intro_screen.queue_free()
		_current_intro_screen = null

	if SectorIntroScreen and is_instance_valid(_popup_root):
		_current_intro_screen = SectorIntroScreen.instantiate() as SectorIntroUI
		_popup_root.add_child(_current_intro_screen)
		
		var on_complete := Callable(self, "_on_blackout_fade_complete")
		_current_intro_screen.fade_in_blackout(on_complete)
	else:
		push_error("[UIManager] SectorIntroScreen or _popup_root is invalid!")
		_on_blackout_fade_complete()
func _on_blackout_fade_complete() -> void:
	"""
	Internal callback.
	Fires the global signal so main.gd knows it's safe to swap.
	"""
	EventBus.blackout_complete.emit()
func show_sector_intro(data: SectorData) -> void:
	"""
	Called by main.gd after the sector swap is complete.
	Tells the intro screen to play its text animations.
	"""
	if is_instance_valid(_current_intro_screen):
		_current_intro_screen.show_with_data(data)
	else:
		push_warning("[UIManager] _current_intro_screen was invalid, cannot show sector intro.")
		var listener := Callable(self, "_on_sector_intro_complete")
		if EventBus.is_connected("sector_intro_complete", listener):
			EventBus.sector_intro_complete.disconnect(listener)
		
		EventBus.sector_intro_complete.emit()
		EventBus.sector_intro_complete.connect(listener)
func _on_sector_intro_complete() -> void:
	"""
	Called by EventBus when the SectorIntroUI is finished and has freed itself.
	We just need to null our reference to it so the *next* warp works.
	"""
	_current_intro_screen = null
