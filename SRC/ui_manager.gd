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
# ... (No changes in _ready or init) ...
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_try_connect_eventbus()
	await get_tree().process_frame
	_try_connect_eventbus()
	
	if not EventBus.is_connected("sector_intro_complete", Callable(self, "_on_sector_intro_complete")):
		EventBus.sector_intro_complete.connect(_on_sector_intro_complete)
func init(popup_root: Control) -> void:
	if not is_instance_valid(popup_root):
		push_error("[UIManager] init() called with an invalid popup_root.")
		return
	_popup_root = popup_root
	_try_connect_eventbus()


# ------------------------------
# REGISTRY
# ------------------------------
# ... (No changes in register_screen) ...
func register_screen(screen_name: String, scene_path: String) -> void:
	_screen_registry[screen_name] = scene_path

# ------------------------------
# SCREENS
# ------------------------------
# ... (No changes in show_screen or close_current_screen) ...
func show_screen(screen_name: String, data: Variant = null) -> Control:
	if not is_instance_valid(_popup_root):
		push_error("[UIManager] show_screen() called, but init() was never called or popup_root is invalid.")
		return null
		
	if not _screen_registry.has(screen_name):
		push_warning("[UIManager] Unknown screen: %s" % screen_name)
		return null

	if is_instance_valid(_current_screen):
		_current_screen.queue_free()
		_current_screen = null

	var scene_path: String = _screen_registry[screen_name]
	var ps: PackedScene = load(scene_path) as PackedScene
	if ps == null:
		push_warning("[UIManager] Could not load scene for '%s' at %s" % [screen_name, scene_path])
		return null

	var inst: Node = ps.instantiate()
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
# HUD
# ------------------------------
# ... (No changes in _ensure_hud, get_hud, show_hud, hide_hud, _try_connect_eventbus, _on_request_show_hud) ...
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
	if visible:
		show_hud()
	else:
		hide_hud()

# --- DELETED: This function is no longer needed ---
# func forward_sector_resource_to_hud(resource_path: String) -> void:
#	... (all of the old code is removed) ...


# ------------------------------
# UPDATED: WARP TRANSITION LOGIC
# ------------------------------
# ... (No changes in begin_warp_transition, _on_blackout_fade_complete, show_sector_intro, _on_sector_intro_complete) ...
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
