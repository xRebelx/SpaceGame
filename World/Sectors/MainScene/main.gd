# res://world/main.gd
extends Node2D

@export var DEV_AUTO_START: bool = false

@onready var world_root: Node = $WorldRoot
@onready var entities_root: Node = $Entities
@onready var player: Node2D = $Entities/Player
@onready var ui_layer: CanvasLayer = $UILayer

func _ready() -> void:
	print("[Main] _ready() called")

	# === Initialize Universe Manager ===
	UniverseManager.init(world_root, entities_root)
	UniverseManager.set_player(player)
	player.visible = false  # hide player until game starts
	print("[Main] UniverseManager initialized")

	# === Locate Popup Layer for UI ===
	var popup_root: Control = ui_layer.get_node_or_null("PopupLayer")
	if popup_root == null:
		popup_root = ui_layer.get_node_or_null("HUDRoot/PopupLayer")

	if popup_root == null:
		push_error("[Main] PopupLayer not found. Expected UILayer/PopupLayer or UILayer/HUDRoot/PopupLayer.")
		return

	UIManager.init(popup_root)
	print("[Main] UIManager initialized using PopupLayer: ", popup_root.name)

	# === Register sectors ===
	UniverseManager.register_sector("HomeSector_1", "res://world/sectors/HomeSector_1.tscn")
	UniverseManager.register_sector("MiningSector_1", "res://world/sectors/MiningSector_1.tscn")

	# === Connect Events ===
	EventBus.request_show_screen.connect(_on_request_show_screen)
	EventBus.request_close_screen.connect(_on_request_close_screen)
	EventBus.request_start_game.connect(_on_request_start_game)
	print("[Main] EventBus connections complete")

	# === Game Flow ===
	if DEV_AUTO_START:
		print("[Main] DEV_AUTO_START enabled — jumping directly into sector")
		player.visible = true
		UniverseManager.change_sector("HomeSector_1")
	else:
		print("[Main] Showing Main Menu")
		_on_request_show_screen("MainMenu", null)


# === UI Flow ===
func _on_request_show_screen(screen_name: String, payload: Variant) -> void:
	print("[Main] Showing screen: ", screen_name)
	match screen_name:
		"MainMenu":
			UIManager.show_screen("MainMenu", "res://ui/MainMenu.tscn")
		"CharacterCreate":
			UIManager.show_screen("CharacterCreate", "res://ui/CharacterCreate.tscn", payload)


func _on_request_close_screen(screen_name: String) -> void:
	print("[Main] Closing screen: ", screen_name)
	UIManager.close_screen(screen_name)


func _on_request_start_game(sector_id: String, entry: String) -> void:
	print("[Main] Starting game -> ", sector_id)
	UIManager.close_screen("CharacterCreate")
	UIManager.close_screen("MainMenu")

	player.visible = true
	UniverseManager.change_sector(sector_id, entry)
