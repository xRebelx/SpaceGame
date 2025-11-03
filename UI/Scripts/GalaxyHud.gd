# UI/Scripts/GalaxyHud.gd
class_name GalaxyHUD
extends Control

const SectorManager = preload("res://SRC/SectorManager.gd")

# --- UI Node Refs ---
@onready var lbl_sector:   Label = %LblSectorName
@onready var lbl_faction:  Label = %LblFaction
@onready var lbl_security: Label = %LblSecurity
@onready var lbl_pirates:  Label = %LblPirate
@onready var lbl_credits:  Label = %LblCredits
@onready var lbl_hull:    Label = %LblHullValue
@onready var lbl_shield:  Label = %LblShieldValue
@onready var lbl_weapon:  Label = %LblWeapon
@onready var save_notify: Label = %SaveNotify

@onready var btn_sector_info: Button = %BtnSectorInfo
@onready var sector_info_dropdown: Control = %SectorInfoDropdown

# --- System Menu Refs ---
@onready var btn_system_menu: Button = %BtnSystemMenu
@onready var system_menu_popup: Control = %SystemMenuPopup
@onready var btn_save: Button = %BtnSave
@onready var btn_load: Button = %BtnLoad
@onready var btn_options: Button = %BtnOptions
@onready var btn_exit: Button = %BtnExit

var _captain_profile: CaptainProfile = null
var _ship_data: ShipData = null


func _ready() -> void:
	print("[GalaxyHUD] _ready() path=", get_path())
	set_anchors_preset(Control.PRESET_FULL_RECT, true)
	_set_labels("—", "", "", "")
	
	connect_to_player_resources()
	update_all_player_labels()
	
	if is_instance_valid(btn_sector_info):
		btn_sector_info.pressed.connect(_on_toggle_sector_info)
	else:
		push_warning("[GalaxyHUD] %BtnSectorInfo node not found.")
	
	if is_instance_valid(sector_info_dropdown):
		sector_info_dropdown.visible = false # Hide by default
	else:
		push_warning("[GalaxyHUD] %SectorInfoDropdown node not found.")
	
	# --- Connect System Menu Buttons ---
	if is_instance_valid(btn_system_menu):
		btn_system_menu.pressed.connect(_on_toggle_system_menu)
		btn_save.pressed.connect(_on_save_pressed)
		btn_load.pressed.connect(_on_load_pressed)
		btn_options.pressed.connect(_on_options_pressed)
		btn_exit.pressed.connect(_on_exit_pressed)
	else:
		push_warning("[GalaxyHUD] System menu nodes not found.")
	
	system_menu_popup.visible = false
	
	if is_instance_valid(save_notify):
		EventBus.game_save_successful.connect(_on_game_save_successful)
		save_notify.visible = false
	else:
		push_warning("[GalaxyHUD] %SaveNotify node not found.")
	
	EventBus.current_sector_changed.connect(_on_current_sector_changed)
	print("[GalaxyHUD] ready; visible=", visible)


func _exit_tree() -> void:
	_disconnect_from_player_resources()
	
	if EventBus.is_connected("game_save_successful", Callable(self, "_on_game_save_successful")):
		EventBus.game_save_successful.disconnect(Callable(self, "_on_game_save_successful"))
	
	if EventBus.is_connected("current_sector_changed", Callable(self, "_on_current_sector_changed")):
		EventBus.current_sector_changed.disconnect(Callable(self, "_on_current_sector_changed"))


func connect_to_player_resources() -> void:
	_disconnect_from_player_resources()
	if not PlayerManager:
		push_warning("[GalaxyHUD] PlayerManager singleton not found.")
		return
	_captain_profile = PlayerManager.captain_profile
	_ship_data = PlayerManager.ship_data
	if is_instance_valid(_captain_profile):
		if not _captain_profile.is_connected("credits_changed", Callable(self, "_on_credits_changed")):
			_captain_profile.credits_changed.connect(_on_credits_changed)
	else:
		push_warning("[GalaxyHUD] CaptainProfile is null.")
	if is_instance_valid(_ship_data):
		if not _ship_data.is_connected("ship_stats_changed", Callable(self, "_on_ship_stats_changed")):
			_ship_data.ship_stats_changed.connect(_on_ship_stats_changed)
		if not _ship_data.is_connected("weapon_changed", Callable(self, "_on_weapon_changed")):
			_ship_data.weapon_changed.connect(_on_weapon_changed)
	else:
		push_warning("[GalaxyHUD] ShipData is null.")

func _disconnect_from_player_resources() -> void:
	if is_instance_valid(_captain_profile):
		if _captain_profile.is_connected("credits_changed", Callable(self, "_on_credits_changed")):
			_captain_profile.credits_changed.disconnect(Callable(self, "_on_credits_changed"))
	if is_instance_valid(_ship_data):
		if _ship_data.is_connected("ship_stats_changed", Callable(self, "_on_ship_stats_changed")):
			_ship_data.ship_stats_changed.disconnect(Callable(self, "_on_ship_stats_changed"))
		if _ship_data.is_connected("weapon_changed", Callable(self, "_on_weapon_changed")):
			_ship_data.weapon_changed.disconnect(Callable(self, "_on_weapon_changed"))
	_captain_profile = null
	_ship_data = null

func update_all_player_labels() -> void:
	if is_instance_valid(_captain_profile):
		_on_credits_changed(_captain_profile.credits)
	else:
		_on_credits_changed(0)
	if is_instance_valid(_ship_data):
		_on_ship_stats_changed(_ship_data.current_hp, _ship_data.max_hp, _ship_data.current_shield, _ship_data.max_shield)
		_on_weapon_changed(_ship_data.weapon_name)
	else:
		_on_ship_stats_changed(0, 0, 0, 0)
		_on_weapon_changed("—")

func _on_credits_changed(new_credits: int) -> void:
	if is_instance_valid(lbl_credits):
		lbl_credits.text = "Credits: %d" % new_credits

func _on_ship_stats_changed(hull: float, max_hull: float, shield: float, max_shield: float) -> void:
	if is_instance_valid(lbl_hull):
		lbl_hull.text = "Hull: %d / %d" % [int(hull), int(max_hull)]
	if is_instance_valid(lbl_shield):
		lbl_shield.text = "Shield: %d / %d" % [int(shield), int(max_shield)]

func _on_weapon_changed(weapon_name: String) -> void:
	if is_instance_valid(lbl_weapon):
		lbl_weapon.text = "Weapon: %s" % weapon_name

func _on_current_sector_changed(sector_id: String) -> void:
	print("[GalaxyHUD] _on_current_sector_changed(): ", sector_id)

	if sector_id.is_empty():
		_set_labels("Unknown Sector", "", "", "")
		return

	var info: Dictionary = SectorManager.get_sector_info(sector_id)
	if info.is_empty():
		_set_labels("Unknown Sector", "", "", "")
		push_warning("[GalaxyHUD] SectorManager had no info for: " + sector_id)
		return

	var sector_title: String        = str(info.get("sector_name", sector_id))
	var controlling_faction: String = str(info.get("controlling_faction", info.get("faction", "")))
	var security_level: String      = str(info.get("security_level", ""))
	var pirate_activity: String     = str(info.get("pirate_activity", ""))

	_set_labels(sector_title, controlling_faction, security_level, pirate_activity)
	print("[GalaxyHUD] labels updated -> ", [sector_title, controlling_faction, security_level, pirate_activity])


func _set_labels(sector_title: String, faction: String, security: String, pirates: String) -> void:
	if is_instance_valid(lbl_sector):
		lbl_sector.text = "Sector: %s" % sector_title
	if is_instance_valid(lbl_faction):
		lbl_faction.text = "Faction: %s" % faction
	if is_instance_valid(lbl_security):
		lbl_security.text = "Security: %s" % security
	if is_instance_valid(lbl_pirates):
		lbl_pirates.text = "Pirates: %s" % pirates


func _on_toggle_sector_info() -> void:
	if is_instance_valid(sector_info_dropdown):
		sector_info_dropdown.visible = not sector_info_dropdown.visible


# --- System Menu Logic ---

func _on_toggle_system_menu() -> void:
	# --- This function NO LONGER pauses the game. ---
	system_menu_popup.visible = not system_menu_popup.visible

func _on_save_pressed() -> void:
	print("[GalaxyHUD] 'Save Game' button clicked.")
	# --- Pause the game, THEN show the screen ---
	PauseManager.pause_game()
	EventBus.request_show_screen.emit("SaveGame", null)
	system_menu_popup.visible = false # Hide this menu

func _on_load_pressed() -> void:
	print("[GalaxyHUD] 'Load Game' button clicked.")
	# --- Pause the game, THEN show the screen ---
	PauseManager.pause_game()
	EventBus.request_show_screen.emit("LoadGame", null)
	system_menu_popup.visible = false # Hide this menu

func _on_options_pressed() -> void:
	print("[GalaxyHUD] 'Options' button clicked.")
	# --- Pause the game, THEN show the screen ---
	PauseManager.pause_game()
	EventBus.request_show_screen.emit("Options", null)
	system_menu_popup.visible = false # Hide this menu

func _on_exit_pressed() -> void:
	print("[GalaxyHUD] 'Exit' button clicked.")
	# --- Ensure game is unpaused before reloading scene ---
	PauseManager.unpause_game()
	get_tree().reload_current_scene()

func _on_game_save_successful() -> void:
	if not is_instance_valid(save_notify):
		return
	save_notify.text = "Game Saved!"
	save_notify.modulate.a = 1.0
	save_notify.visible = true
	var tween = create_tween().set_parallel(false)
	tween.tween_interval(1.5)
	tween.tween_property(save_notify, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): save_notify.visible = false)
