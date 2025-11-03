# res://UI/Scripts/main_menu.gd
extends Control

@onready var btn_new: Button     = %BtnNew
@onready var btn_load: Button    = %BtnLoad
@onready var btn_options: Button = %BtnOptions
@onready var btn_quit: Button    = %BtnQuit

# Set this in the Inspector to: res://UI/UI Scenes/LoadGame.tscn
@export_file("*.tscn") var load_game_scene_path: String

var _overlay_open := false

func _ready() -> void:
	if not (btn_new and btn_load and btn_options and btn_quit):
		push_error("[MainMenu] Missing unique buttons. Ensure BtnNew, BtnLoad, BtnOptions, BtnQuit exist.")
		return
	btn_new.pressed.connect(_on_new_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	await get_tree().process_frame
	_update_load_button_state()
	
	# Tell the MusicManager to play the menu music
	# This will run every time the MainMenu scene is loaded
	if MusicManager:
		MusicManager.play_menu_music()
	
	print("[MainMenu] Ready, UI connected.")

func _update_load_button_state() -> void:
	if not is_instance_valid(btn_load):
		return
	if PersistenceManager:
		btn_load.disabled = not PersistenceManager.has_save()
	else:
		push_error("[MainMenu] PersistenceManager Autoload not found.")
		btn_load.disabled = true

func _on_new_pressed() -> void:
	print("[MainMenu] New Game pressed")
	EventBus.request_show_screen.emit("CharacterCreate", null)

func _on_load_pressed() -> void:
	print("[MainMenu] Load pressed")
	if not PersistenceManager.has_save():
		print("[MainMenu] No save data found.")
		return
	_open_load_overlay()

func _on_options_pressed() -> void:
	print("[MainMenu] Options pressed")
	EventBus.request_show_screen.emit("Options", null)

func _on_quit_pressed() -> void:
	print("[MainMenu] Quit pressed")
	get_tree().quit()

func _open_load_overlay() -> void:
	if _overlay_open:
		return
	if load_game_scene_path.is_empty():
		push_error("[MainMenu] load_game_scene_path is empty. Set it in the Inspector.")
		return
	if not ResourceLoader.exists(load_game_scene_path):
		push_error("[MainMenu] Scene not found at: %s" % load_game_scene_path)
		_debug_list_ui_scenes()
		return

	var packed := load(load_game_scene_path)
	if packed == null or not (packed is PackedScene):
		push_error("[MainMenu] Could not load: %s" % load_game_scene_path)
		return

	var dlg := (packed as PackedScene).instantiate()
	add_child(dlg)
	move_child(dlg, get_child_count() - 1) # ensure on top
	_overlay_open = true
	_set_menu_interactive(false)

	if dlg.has_signal("canceled"):
		dlg.connect("canceled", Callable(self, "_on_overlay_closed"))
	dlg.tree_exited.connect(_on_overlay_closed)

func _on_overlay_closed() -> void:
	_overlay_open = false
	_set_menu_interactive(true)
	_update_load_button_state()

func _set_menu_interactive(enabled: bool) -> void:
	for b in [btn_new, btn_load, btn_options, btn_quit]:
		if is_instance_valid(b):
			b.disabled = not enabled
	mouse_filter = Control.MOUSE_FILTER_PASS if enabled else Control.MOUSE_FILTER_IGNORE

# Handy helper to show you what's in the folder if the path is wrong
func _debug_list_ui_scenes() -> void:
	var dir_path := "res://UI/UI Scenes"
	var dir := DirAccess.open(dir_path)
	if dir:
		print("[MainMenu] Listing scenes in: ", dir_path)
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(".tscn"):
				print(" - ", entry)
			entry = dir.get_next()
		dir.list_dir_end()
	else:
		push_error("[MainMenu] Cannot open directory: %s" % dir_path)
