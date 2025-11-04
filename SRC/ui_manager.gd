# SRC/ui_manager.gd
extends Node

# --- MODIFIED: Preload Planet intro screen ---
const PlanetIntroScreen = preload("res://UI/UI Scenes/PlanetIntroUI.tscn")

# ------------------------------
# CONFIG / STATE
# ------------------------------
var _screen_registry: Dictionary = {}
var _current_screen: Control = null
var _hud: Control = null
var _popup_root: Control = null

# --- MODIFIED: Tracker for the intro screen ---
var _current_intro_screen: Control = null # Use base Control type


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
	
	if not EventBus.is_connected("request_show_screen", Callable(self, "_on_request_show_screen")):
		EventBus.request_show_screen.connect(_on_request_show_screen)
	if not EventBus.is_connected("request_close_screen", Callable(self, "_on_request_close_screen")):
		EventBus.request_close_screen.connect(_on_request_close_screen)

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

# --- ADD THIS ENTIRE NEW FUNCTION ---
func preload_screen_under_intro(screen_name: String, data: Variant = null) -> Control:
	"""
	Loads a screen and places it *under* the current intro screen.
	This is used to pre-load the DockedUI during a black screen.
	"""
	if not is_instance_valid(_popup_root):
		push_error("[UIManager] preload_screen_under_intro: popup_root is invalid.")
		return null
	if not _screen_registry.has(screen_name):
		push_warning("[UIManager] Unknown screen: %s" % screen_name)
		return null
	if not is_instance_valid(_current_intro_screen):
		push_warning("[UIManager] preload_screen_under_intro: No intro screen is active.")
		return null

	# If there's already a main screen, close it.
	if is_instance_valid(_current_screen):
		close_current_screen()

	# Load the new screen
	var scene_path: String = _screen_registry[screen_name]
	var ps: PackedScene = load(scene_path)
	if ps == null:
		push_warning("[UIManager] Could not load scene for '%s' at %s" % [screen_name, scene_path])
		return null

	var inst: Node = ps.instantiate()
	inst.name = screen_name
	
	if inst is Control:
		var c := inst as Control
		c.process_mode = Node.PROCESS_MODE_ALWAYS
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		
		# This is the magic:
		# 1. Add the new screen (it goes on top by default)
		_popup_root.add_child(c)
		# 2. Move it to the intro screen's index (pushing the intro screen up)
		_popup_root.move_child(c, _current_intro_screen.get_index())
		
		_current_screen = c # It is now the main screen
	else:
		add_child(inst) # Fallback for non-Control nodes

	if data != null and "apply_data" in inst:
		inst.apply_data(data)

	return _current_screen
# --- END NEW FUNCTION ---


func _on_request_show_screen(screen_name: String, payload: Variant) -> void:
	show_screen(screen_name, payload)

func _on_request_close_screen(screen_name: String) -> void:
	print("[UIManager] Received request_close_screen for: ", screen_name)
	
	if is_instance_valid(_current_screen) and _current_screen.name == screen_name:
		print("[UIManager] Closing current screen: ", _current_screen.name)
		close_current_screen()
	else:
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

	if is_instance_valid(_current_screen):
		close_current_screen()

	var scene_path: String = _screen_registry[screen_name]
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		push_warning("[UIManager] Could not load scene for '%s' at %s" % [screen_name, scene_path])
		return null

	var inst: Node = ps.instantiate()
	
	inst.name = screen_name
	
	if inst is Control:
		var c := inst as Control
		c.process_mode = Node.PROCESS_MODE_ALWAYS
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		_popup_root.add_child(c)
		_current_screen = c
	else:
		add_child(inst)
		_current_screen = null 

	if data != null and "apply_data" in inst:
		inst.apply_data(data)

	return _current_screen

func close_current_screen() -> void:
	if is_instance_valid(_current_screen):
		_current_screen.queue_free()
		_current_screen = null

# ------------------------------
# --- MODIFIED: ORBIT STATE HANDLERS ---
# ------------------------------

func _on_player_entered_orbit(_planet_node: Node) -> void:
	# --- ADDED THIS LOGIC ---
	var data = null
	if _planet_node.has_method("get") and _planet_node.get("planet_data"):
		data = _planet_node.get("planet_data")
	# --- END ADD ---
	
	print("[UIManager] Player entered orbit. Hiding HUD, showing OrbitUI.")
	hide_hud()
	show_screen("OrbitUI", data) # <-- PASS DATA HERE

func _on_player_leave_orbit() -> void:
	print("[UIManager] Player left orbit. Closing screen, showing HUD.")
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
	node.name = "GalaxyHUD"
	var ctrl: Control = node as Control
	if ctrl == null:
		push_warning("[UIManager] GalaxyHUD root must be a Control.")
		return null

	ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_popup_root.add_child(ctrl)
	
	# --- THIS IS THE FIX ---
	# Move the HUD to the back (index 0) so all other screens
	# (transitions, options, etc.) render on top of it.
	_popup_root.move_child(ctrl, 0)
	# --- END FIX ---
	
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

	# --- MODIFIED: Use PlanetIntroScreen ---
	if PlanetIntroScreen and is_instance_valid(_popup_root):
		_current_intro_screen = PlanetIntroScreen.instantiate()
		_popup_root.add_child(_current_intro_screen)
		
		var on_complete := Callable(self, "_on_blackout_fade_complete")
		if _current_intro_screen.has_method("fade_in_blackout"):
			_current_intro_screen.fade_in_blackout(on_complete)
		else:
			push_error("[UIManager] PlanetIntroUI is missing fade_in_blackout() method!")
			on_complete.call()
	else:
		push_error("[UIManager] PlanetIntroScreen or _popup_root is invalid!")
		_on_blackout_fade_complete()
		
func _on_blackout_fade_complete() -> void:
	"""
	Internal callback.
	Fires the global signal so main.gd knows it's safe to swap.
	"""
	EventBus.blackout_complete.emit()
	
func show_sector_intro(data: Variant) -> void: # <-- MODIFIED: Use Variant
	"""
	Called by main.gd after the sector swap is complete.
	Tells the intro screen to play its text animations.
	"""
	if is_instance_valid(_current_intro_screen):
		if _current_intro_screen.has_method("show_with_data"):
			_current_intro_screen.show_with_data(data)
		else:
			push_error("[UIManager] PlanetIntroUI is missing show_with_data() method!")
			_on_animation_finished() # Fail-safe
	else:
		push_warning("[UIManager] _current_intro_screen was invalid, cannot show sector intro.")
		_on_animation_finished()

func _on_animation_finished() -> void:
	# This function is now called by the PlanetIntroUI script when it finishes
	# We just need to null our reference and emit the signal
	_current_intro_screen = null
	EventBus.sector_intro_complete.emit()
		
func _on_sector_intro_complete() -> void:
	"""
	Called by EventBus when the IntroUI is finished and has freed itself.
	We just need to null our reference to it so the *next* warp works.
	"""
	_current_intro_screen = null
