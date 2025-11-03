# res://UI/Scripts/Options.gd
extends Control

# --- Preload Page Scenes ---
# This is the scene you just created (AudioOptions.tscn)
const AudioOptionsScene = preload("res://UI/UI Scenes/AudioOptions.tscn")
# Uncomment these when you create them:
#const GameplayOptionsScene = preload("res://UI/UI Scenes/GameplayOptions.tscn")
#const DisplayOptionsScene = preload("res://UI/UI Scenes/DisplayOptions.tscn")
#const ControlsOptionsScene = preload("res://UI/UI Scenes/ControlsOptions.tscn")

# --- Tab Buttons ---
@onready var btn_gameplay: Button = %BtnGameplay
@onready var btn_display: Button = %BtnDisplay
@onready var btn_audio: Button = %BtnAudio
@onready var btn_controls: Button = %BtnControls

# --- Page Container ---
# This is the MarginContainer (or other container) that holds the page
@onready var option_container: Container = %OptionContainer

# --- Bottom Buttons ---
@onready var btn_back: Button = %BtnBack
@onready var btn_apply: Button = %BtnApply 

# Store the currently spawned page
var _current_page: Node = null

func _ready() -> void:
	# Ensure this UI can run while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS

	# --- Connect Tab Buttons ---
	btn_gameplay.pressed.connect(_on_gameplay_pressed)
	btn_display.pressed.connect(_on_display_pressed)
	btn_audio.pressed.connect(_on_audio_pressed)
	btn_controls.pressed.connect(_on_controls_pressed)
	
	# --- Connect Bottom Buttons ---
	if is_instance_valid(btn_back):
		btn_back.pressed.connect(_on_back_pressed)
	else:
		push_error("[Options] %BtnBack node not found!")
		
	if is_instance_valid(btn_apply):
		btn_apply.pressed.connect(_on_apply_pressed)
		btn_apply.disabled = true # Start disabled
	else:
		push_error("[Options] %BtnApply node not found!")
	
	# Show the default audio tab on load
	_on_audio_pressed()

# --- Page Spawning Logic ---

func _spawn_page(scene: PackedScene) -> void:
	# Clear the old page
	if is_instance_valid(_current_page):
		_current_page.queue_free()
		_current_page = null
	
	# Disable apply button whenever we change pages
	if is_instance_valid(btn_apply):
		btn_apply.disabled = true
	
	if not is_instance_valid(option_container):
		push_error("[Options] %OptionContainer node not found!")
		return
	if scene == null:
		push_warning("[Options] Scene to spawn is null. Did you uncomment it?")
		return

	# Spawn and add the new page
	_current_page = scene.instantiate()
	
	# Connect to the page's signal
	if _current_page.has_signal("settings_changed"):
		_current_page.settings_changed.connect(_on_settings_changed)
	
	option_container.add_child(_current_page)


# --- Tab Button Callbacks ---

func _on_gameplay_pressed() -> void:
	print("[Options] Gameplay pressed")
	_spawn_page(null) # Placeholder. Uncomment line below when scene is ready
	#_spawn_page(GameplayOptionsScene)

func _on_display_pressed() -> void:
	print("[Options] Display pressed")
	_spawn_page(null) # Placeholder. Uncomment line below when scene is ready
	#_spawn_page(DisplayOptionsScene)

func _on_audio_pressed() -> void:
	print("[Options] Audio pressed")
	_spawn_page(AudioOptionsScene)

func _on_controls_pressed() -> void:
	print("[Options] Controls pressed")
	_spawn_page(null) # Placeholder. Uncomment line below when scene is ready
	#_spawn_page(ControlsOptionsScene)

# --- Signal Receiver ---

func _on_settings_changed() -> void:
	# This is called by the child page when a slider moves
	if is_instance_valid(btn_apply):
		btn_apply.disabled = false

# --- Bottom Button Logic ---

func _on_apply_pressed() -> void:
	# Tell the current page to apply its settings
	if is_instance_valid(_current_page) and _current_page.has_method("apply_settings"):
		_current_page.apply_settings()
	
	# Disable the apply button again
	if is_instance_valid(btn_apply):
		btn_apply.disabled = true

func _on_back_pressed() -> void:
	PauseManager.unpause_game()
	
	var player = get_tree().get_first_node_in_group("players")
	var is_in_main_menu = is_instance_valid(player) and not player.visible
	
	# --- FIX FOR C++ ERROR ---
	# Defer freeing the node and emitting the signal to prevent
	# a race condition with the unpause call.
	call_deferred("queue_free")
	
	if is_in_main_menu:
		# This is the corrected Godot 4 syntax
		EventBus.request_show_screen.emit.call_deferred("MainMenu", null)
	# --- END FIX ---
