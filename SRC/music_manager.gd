# res://SRC/MusicManager.gd
extends Node

var menu_music_player: AudioStreamPlayer = null 
var gameplay_music_player: AudioStreamPlayer = null 
var docked_music_player: AudioStreamPlayer = null # <-- ADD THIS
var hover_player: AudioStreamPlayer = null

const FADE_TIME: float = 0.5

# Tween trackers for each music player
var _menu_tween: Tween = null
var _gameplay_tween: Tween = null 
var _docked_tween: Tween = null # <-- ADD THIS


func _ready() -> void:
	# --- THIS IS THE PAUSE FIX ---
	# Make this node (and its children) ignore the pause state
	process_mode = Node.PROCESS_MODE_ALWAYS
	# --- END FIX ---
	
	# --- 1. Get our audio players ---
	menu_music_player = $MenuMusicPlayer
	gameplay_music_player = $GameplayMusicPlayer 
	docked_music_player = $DockedMusicPlayer # <-- ADD THIS
	hover_player = $HoverPlayer
	
	if not is_instance_valid(menu_music_player):
		push_error("[MusicManager] CRITICAL: Could not find $MenuMusicPlayer node.")
	if not is_instance_valid(gameplay_music_player): 
		push_error("[MusicManager] CRITICAL: Could not find $GameplayMusicPlayer node.")
	if not is_instance_valid(docked_music_player): # <-- ADD THIS BLOCK
		push_error("[MusicManager] CRITICAL: Could not find $DockedMusicPlayer node.")
	if not is_instance_valid(hover_player):
		push_error("[MusicManager] CRITICAL: Could not find $HoverPlayer node.")

	# --- 2. Button hover sound logic (unchanged) ---
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.mouse_entered.connect(_on_button_mouse_entered.bind(node))

func _on_button_mouse_entered(button_node: BaseButton) -> void:
	var current = button_node
	while is_instance_valid(current):
		if current is GalaxyHUD:
			return
		current = current.get_parent()
	play_hover_sound()

func play_hover_sound() -> void:
	if is_instance_valid(hover_player):
		hover_player.play()

# --- 3. Music Control Functions ---

func play_menu_music() -> void:
	stop_gameplay_music()
	stop_docked_music() # <-- ADD THIS
	
	if not is_instance_valid(menu_music_player):
		push_warning("[MusicManager] MenuMusicPlayer node not found.")
		return
		
	if menu_music_player.is_playing():
		return
		
	if is_instance_valid(_menu_tween):
		_menu_tween.kill()
		_menu_tween = null
	
	menu_music_player.stop()
	menu_music_player.volume_db = -80.0
	menu_music_player.play()
	
	_menu_tween = create_tween()
	_menu_tween.tween_property(menu_music_player, "volume_db", 0.0, FADE_TIME).from_current()
	_menu_tween.finished.connect(func(): _menu_tween = null)

func stop_menu_music() -> void:
	if not is_instance_valid(menu_music_player):
		return
		
	if not menu_music_player.is_playing() and menu_music_player.volume_db < -70.0:
		return

	if is_instance_valid(_menu_tween):
		_menu_tween.kill()
		_menu_tween = null

	_menu_tween = create_tween()
	_menu_tween.tween_property(menu_music_player, "volume_db", -80.0, FADE_TIME).from_current()
	_menu_tween.tween_callback(menu_music_player.stop)
	_menu_tween.tween_callback(func(): menu_music_player.volume_db = 0.0) 
	_menu_tween.finished.connect(func(): _menu_tween = null)


# --- Gameplay Music Functions ---

func play_gameplay_music(fade_duration: float = -1.0) -> void:
	stop_menu_music()
	stop_docked_music() # <-- ADD THIS

	if not is_instance_valid(gameplay_music_player):
		push_warning("[MusicManager] GameplayMusicPlayer node not found.")
		return

	if gameplay_music_player.is_playing():
		return

	if is_instance_valid(_gameplay_tween):
		_gameplay_tween.kill()
		_gameplay_tween = null

	gameplay_music_player.stop()
	gameplay_music_player.volume_db = -80.0
	gameplay_music_player.play()

	var duration = FADE_TIME if fade_duration < 0.0 else fade_duration

	_gameplay_tween = create_tween()
	_gameplay_tween.tween_property(gameplay_music_player, "volume_db", 0.0, duration).from_current()
	_gameplay_tween.finished.connect(func(): _gameplay_tween = null)

func stop_gameplay_music() -> void:
	if not is_instance_valid(gameplay_music_player):
		return

	if not gameplay_music_player.is_playing() and gameplay_music_player.volume_db < -70.0:
		return

	if is_instance_valid(_gameplay_tween):
		_gameplay_tween.kill()
		_gameplay_tween = null

	_gameplay_tween = create_tween()
	_gameplay_tween.tween_property(gameplay_music_player, "volume_db", -80.0, FADE_TIME).from_current()
	_gameplay_tween.tween_callback(gameplay_music_player.stop)
	_gameplay_tween.tween_callback(func(): gameplay_music_player.volume_db = 0.0)
	_gameplay_tween.finished.connect(func(): _gameplay_tween = null)


# --- ADD THESE NEW FUNCTIONS ---

func play_docked_music(fade_duration: float = -1.0) -> void:
	stop_menu_music()
	stop_gameplay_music()

	if not is_instance_valid(docked_music_player):
		push_warning("[MusicManager] DockedMusicPlayer node not found.")
		return

	if docked_music_player.is_playing():
		return

	if is_instance_valid(_docked_tween):
		_docked_tween.kill()
		_docked_tween = null

	docked_music_player.stop()
	docked_music_player.volume_db = -80.0
	docked_music_player.play()

	var duration = FADE_TIME if fade_duration < 0.0 else fade_duration

	_docked_tween = create_tween()
	_docked_tween.tween_property(docked_music_player, "volume_db", 0.0, duration).from_current()
	_docked_tween.finished.connect(func(): _docked_tween = null)

func stop_docked_music() -> void:
	if not is_instance_valid(docked_music_player):
		return

	if not docked_music_player.is_playing() and docked_music_player.volume_db < -70.0:
		return

	if is_instance_valid(_docked_tween):
		_docked_tween.kill()
		_docked_tween = null

	_docked_tween = create_tween()
	_docked_tween.tween_property(docked_music_player, "volume_db", -80.0, FADE_TIME).from_current()
	_docked_tween.tween_callback(docked_music_player.stop)
	_docked_tween.tween_callback(func(): docked_music_player.volume_db = 0.0)
	_docked_tween.finished.connect(func(): _docked_tween = null)

# --- END ADD ---
