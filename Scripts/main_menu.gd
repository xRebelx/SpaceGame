# res://ui/main_menu.gd
extends Control

@onready var btn_new: Button     = %BtnNew
@onready var btn_load: Button    = %BtnLoad
@onready var btn_options: Button = %BtnOptions
@onready var btn_quit: Button    = %BtnQuit

func _ready() -> void:
	if not (btn_new and btn_load and btn_options and btn_quit):
		push_error("[MainMenu] Missing unique buttons. Ensure BtnNew, BtnLoad, BtnOptions, BtnQuit exist.")
		return

	btn_new.pressed.connect(_on_new_pressed)
	btn_load.pressed.connect(_on_load_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	btn_load.disabled = not PersistenceManager.has_save()
	print("[MainMenu] Ready, UI connected.")

func _on_new_pressed() -> void:
	print("[MainMenu] New Game pressed")
	EventBus.request_show_screen.emit("CharacterCreate", null)

func _on_load_pressed() -> void:
	print("[MainMenu] Load pressed")
	if not PersistenceManager.has_save():
		print("[MainMenu] No save data found.")
		return
	PersistenceManager.load_game()
	EventBus.request_close_screen.emit("MainMenu")

func _on_options_pressed() -> void:
	print("[MainMenu] Options pressed (feature coming soon)")

func _on_quit_pressed() -> void:
	print("[MainMenu] Quit pressed")
	get_tree().quit()
