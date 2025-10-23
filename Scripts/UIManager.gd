extends CanvasLayer
class_name UIManager

# -----------------------------------------------------------
#   Scene paths (preloaded; no Inspector wiring needed)
# -----------------------------------------------------------
const PLANET_INTRO_SCENE: PackedScene = preload("res://Scenes/UI Scenes/PlanetIntroUI.tscn")
const DOCKED_UI_SCENE: PackedScene    = preload("res://Scenes/UI Scenes/DockedUI.tscn")

# Draw above the blackout (FadeOverlay is layer 4)
@export var ui_layer: int = 5

# --- Per-element fade controls (seconds) ---
@export var name_fade_in: float  = 0.8
@export var type_fade_in: float  = 0.8
@export var image_fade_in: float = 0.8

# Stagger the reveals (seconds)
@export var name_delay: float  = 0.00
@export var type_delay: float  = 0.20
@export var image_delay: float = 0.40

# How long the whole intro stays on screen before fading out
@export var show_duration: float = 3.0

# Fade-out time for all elements
@export var fade_out_time: float = 0.8

# --- ADDED: Undock fade time ---
@export var undock_ui_fade_time: float = 0.6

# Safety clamps
const MIN_FADE: float = 0.05
const MIN_SHOW: float = 0.05

# --- ADDED: State variables ---
var _current_planet: Node2D = null
var _current_docked_ui: Control = null


func _ready() -> void:
	layer = ui_layer
	print("[UI] UIManager _ready. layer=", layer)

# Called by PlanetDockManager when fade-to-black completes
func on_dock_fade_complete(planet: Node2D) -> void:
	print("[UI] on_dock_fade_complete received for planet: ", planet.name)
	await _show_planet_intro_for_planet(planet)
	_show_docked_ui(planet)

func _show_planet_intro_for_planet(planet: Node2D) -> void:
	print("[UI] Showing PlanetIntroUI for planet: ", planet.name)
	var card: Control = PLANET_INTRO_SCENE.instantiate() as Control
	if card == null:
		push_warning("UIManager: failed to instance PlanetIntroUI.")
		return

	add_child(card)
	card.top_level = true

	# Feed planet data to the card
	if card.has_method("set_from_planet"):
		card.set_from_planet(planet)

	# ----- Find elements by name (matches your current scene names) -----
	var name_node: CanvasItem  = card.find_child("Planet Name RTL", true, false) as CanvasItem
	var type_node: CanvasItem  = card.find_child("Planet Type RTL", true, false) as CanvasItem
	var image_node: CanvasItem = card.find_child("PlanetImage TR", true, false) as CanvasItem

	# Initialize alpha/visibility
	_set_alpha(name_node, 0.0);  _set_visible(name_node, true)
	_set_alpha(type_node, 0.0);  _set_visible(type_node, true)
	_set_alpha(image_node, 0.0); _set_visible(image_node, true)

	await get_tree().process_frame

	# Timings (typed)
	var n_in: float  = max(MIN_FADE, name_fade_in)
	var t_in: float  = max(MIN_FADE, type_fade_in)
	var i_in: float  = max(MIN_FADE, image_fade_in)
	var n_dly: float = max(0.0, name_delay)
	var t_dly: float = max(0.0, type_delay)
	var i_dly: float = max(0.0, image_delay)
	var hold: float  = max(MIN_SHOW, show_duration)
	var out_t: float = max(MIN_FADE, fade_out_time)

	# Fade IN (staggered)
	var tweens: Array[Tween] = []
	if name_node:
		var tw_n: Tween = name_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_n.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_n.tween_interval(n_dly)
		tw_n.tween_property(name_node, "modulate:a", 1.0, n_in)
		tweens.append(tw_n)
	if type_node:
		var tw_t: Tween = type_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_t.tween_interval(t_dly)
		tw_t.tween_property(type_node, "modulate:a", 1.0, t_in)
		tweens.append(tw_t)
	if image_node:
		var tw_i: Tween = image_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw_i.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_i.tween_interval(i_dly)
		tw_i.tween_property(image_node, "modulate:a", 1.0, i_in)
		tweens.append(tw_i)

	# --- Check if tweens are valid before awaiting ---
	for tw in tweens:
		if is_instance_valid(tw):
			await tw.finished

	# Hold
	await get_tree().create_timer(hold).timeout

	# --- Check if card is still valid before fading out ---
	if not is_instance_valid(card):
		print("[UI] PlanetIntroUI card was freed early. Skipping fade out.")
		return

	# Fade OUT (parallel)
	var out_tw: Array[Tween] = []
	if name_node:
		var o1: Tween = name_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		o1.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		o1.tween_property(name_node, "modulate:a", 0.0, out_t)
		out_tw.append(o1)
	if type_node:
		var o2: Tween = type_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		o2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		o2.tween_property(type_node, "modulate:a", 0.0, out_t)
		out_tw.append(o2)
	if image_node:
		var o3: Tween = image_node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		o3.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		o3.tween_property(image_node, "modulate:a", 0.0, out_t)
		out_tw.append(o3)

	for tw_out in out_tw:
		if is_instance_valid(tw_out):
			await tw_out.finished
	
	if is_instance_valid(card):
		card.queue_free()

func _show_docked_ui(planet: Node2D) -> void:
	# --- ADDED: Clear old UI if it exists ---
	if is_instance_valid(_current_docked_ui):
		_current_docked_ui.queue_free()
		_current_docked_ui = null
		
	var ui: Control = DOCKED_UI_SCENE.instantiate() as Control
	if ui == null:
		push_warning("UIManager: failed to instance DockedUI.")
		return
	
	# --- ADDED: Store state ---
	_current_planet = planet
	_current_docked_ui = ui
	print("[UI] Stored _current_planet: ", _current_planet.name)
	print("[UI] Stored _current_docked_ui: ", _current_docked_ui)

	add_child(ui)
	ui.top_level = true

	# 🔗 Pass the planet so DockedUI can pull its data
	if ui.has_method("set_from_planet"):
		ui.set_from_planet(planet)

	# --- MODIFIED: Listen for undock ---
	if ui.has_signal("undock_requested"):
		if not ui.is_connected("undock_requested", Callable(self, "_on_undock_requested")):
			ui.connect("undock_requested", Callable(self, "_on_undock_requested"))
			print("[UI] Connected to DockedUI 'undock_requested' signal.")
	else:
		push_warning("[UI] DockedUI scene is missing 'undock_requested' signal.")

# --- ADDED: Undock handler ---
func _on_undock_requested() -> void:
	print("[UI] _on_undock_requested received.")
	
	# 1. Fade out the DockedUI
	if is_instance_valid(_current_docked_ui) and _current_docked_ui.has_method("fade_out"):
		print("[UI] Fading out DockedUI...")
		await _current_docked_ui.fade_out(max(MIN_FADE, undock_ui_fade_time))
		print("[UI] DockedUI fade out complete.")
	
	if is_instance_valid(_current_docked_ui):
		_current_docked_ui.queue_free()
		_current_docked_ui = null
		print("[UI] Freed DockedUI.")

	# 2. Get the PlanetDockManager from the stored planet
	if not is_instance_valid(_current_planet):
		push_error("[UI] _current_planet is invalid! Cannot undock.")
		return
		
	var dm: Node = _current_planet.get_node_or_null("PlanetDockManager")
	if not is_instance_valid(dm):
		push_error("[UI] Could not find PlanetDockManager on planet: " + _current_planet.name)
		return
		
	# 3. Call start_undocking()
	if dm.has_method("start_undocking"):
		print("[UI] Calling start_undocking() on PlanetDockManager...")
		dm.start_undocking()
	else:
		push_error("[UI] PlanetDockManager is missing the 'start_undocking' function!")

# ------------------ helpers ------------------
func _set_alpha(node: CanvasItem, a: float) -> void:
	if node != null:
		var c: Color = node.modulate
		node.modulate = Color(c.r, c.g, c.b, clamp(a, 0.0, 1.0))

func _set_visible(node: CanvasItem, v: bool) -> void:
	if node != null:
		node.visible = v
