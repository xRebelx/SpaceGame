# res://UI/Scripts/AudioOptions.gd
extends Control

# Signal to tell the parent (Options.tscn) that a value has changed
signal settings_changed

# --- Audio Sliders ---
# These names must match your scene's unique names
@onready var music_slider: HSlider = %MusicSlider
@onready var game_effects_slider: HSlider = %GameEffectsSlider
@onready var menu_effects_slider: HSlider = %MenuEffectsSlider

# Store bus indexes for quick lookup
var _music_bus_idx: int = -1
var _game_effects_bus_idx: int = -1
var _menu_effects_bus_idx: int = -1

func _ready() -> void:
	# Get bus indexes by name
	_music_bus_idx = AudioServer.get_bus_index("Music")
	_game_effects_bus_idx = AudioServer.get_bus_index("GameEffects")
	_menu_effects_bus_idx = AudioServer.get_bus_index("MenuEffects")
	
	# --- Connect Sliders ---
	if is_instance_valid(music_slider):
		music_slider.value_changed.connect(_on_any_slider_changed)
	else:
		push_error("[AudioOptions] %MusicSlider node not found!")
		
	if is_instance_valid(game_effects_slider):
		game_effects_slider.value_changed.connect(_on_any_slider_changed)
	else:
		push_error("[AudioOptions] %GameEffectsSlider node not found!")
		
	if is_instance_valid(menu_effects_slider):
		menu_effects_slider.value_changed.connect(_on_any_slider_changed)
	else:
		push_error("[AudioOptions] %MenuEffectsSlider node not found!")
	
	# Set the sliders to match the current audio state
	_initialize_slider_values()

# --- Audio Logic ---

func _initialize_slider_values() -> void:
	# Set sliders to match the current bus volume
	# Use set_value_no_signal to prevent "Apply" from enabling on load
	if is_instance_valid(music_slider):
		music_slider.set_value_no_signal(_get_linear_volume_from_bus(_music_bus_idx))
	if is_instance_valid(game_effects_slider):
		game_effects_slider.set_value_no_signal(_get_linear_volume_from_bus(_game_effects_bus_idx))
	if is_instance_valid(menu_effects_slider):
		menu_effects_slider.set_value_no_signal(_get_linear_volume_from_bus(_menu_effects_bus_idx))

# NEW: This function is called by Options.gd when "Apply" is pressed
func apply_settings() -> void:
	print("[AudioOptions] Applying new settings...")
	if is_instance_valid(music_slider):
		_set_bus_volume_from_linear(_music_bus_idx, music_slider.value)
	if is_instance_valid(game_effects_slider):
		_set_bus_volume_from_linear(_game_effects_bus_idx, game_effects_slider.value)
	if is_instance_valid(menu_effects_slider):
		_set_bus_volume_from_linear(_menu_effects_bus_idx, menu_effects_slider.value)

# --- Helper Functions (unchanged) ---

func _get_linear_volume_from_bus(bus_idx: int) -> float:
	if bus_idx == -1: return 100.0
	if AudioServer.is_bus_mute(bus_idx):
		return 0.0
	else:
		var db = AudioServer.get_bus_volume_db(bus_idx)
		return db_to_linear(db) * 100.0

func _set_bus_volume_from_linear(bus_idx: int, linear_value: float) -> void:
	if bus_idx == -1: return
	if linear_value == 0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var db = linear_to_db(linear_value / 100.0)
		AudioServer.set_bus_volume_db(bus_idx, db)

# --- Signal Callback ---

func _on_any_slider_changed(_value: float) -> void:
	# Just tell the parent "Options" screen that something changed
	emit_signal("settings_changed")
