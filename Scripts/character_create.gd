# res://ui/character_create.gd
extends Control

const CLASS_PATHS: Dictionary[String, String] = {
	"Pirate":    "res://Data/Classes/pirate.tres",
	"Merchant":  "res://Data/Classes/merchant.tres",
	"Soldier":   "res://Data/Classes/soldier.tres",
	"Explorer":  "res://Data/Classes/explorer.tres",
	"Spy":       "res://Data/Classes/spy.tres",
	"Smuggler":  "res://Data/Classes/smuggler.tres",
	"Scout":     "res://Data/Classes/scout.tres",
}

@onready var name_edit: LineEdit       = %NameEdit
@onready var class_list: OptionButton  = %ClassList
@onready var stats_preview: RichTextLabel = %StatsPreview
@onready var btn_back: Button          = %BtnBack
@onready var btn_start: Button         = %BtnStart

var _selected_class: Resource = null

func _ready() -> void:
	if not (name_edit and class_list and stats_preview and btn_back and btn_start):
		push_error("[CharacterCreate] Missing unique controls.")
		return

	for n in CLASS_PATHS.keys():
		class_list.add_item(n)
	class_list.item_selected.connect(_on_class_selected)
	btn_back.pressed.connect(_on_back_pressed)
	btn_start.pressed.connect(_on_start_pressed)

	class_list.select(0)
	_on_class_selected(0)
	_update_preview()
	print("[CharacterCreate] Ready and initialized.")

func _on_back_pressed() -> void:
	EventBus.request_close_screen.emit("CharacterCreate")
	EventBus.request_show_screen.emit("MainMenu", null)

func _on_class_selected(index: int) -> void:
	var label: String = class_list.get_item_text(index)
	var path: String = CLASS_PATHS.get(label, "")
	_selected_class = load(path)
	_update_preview()

func _update_preview() -> void:
	if _selected_class == null:
		stats_preview.text = "[i]No class selected.[/i]"
		return

	var display_name: String = _selected_class.get("display_name")
	var base_stats: Dictionary = _selected_class.get("base_stats")
	var lines: Array[String] = ["[b]%s[/b]" % display_name, ""]
	for k in base_stats.keys():
		lines.append("%s: %d" % [String(k), int(base_stats[k])])
	stats_preview.text = "\n".join(lines)

func _on_start_pressed() -> void:
	var cap_name: String = name_edit.text.strip_edges()
	if cap_name.is_empty():
		cap_name = "Captain"
	if cap_name.length() > 15:
		cap_name = cap_name.substr(0, 15)

	var profile := CaptainProfile.new()
	profile.captain_name = cap_name
	profile.class_id = String(_selected_class.get("id"))

	var base_stats: Dictionary = _selected_class.get("base_stats")
	var final_stats: Dictionary = {}
	for k in base_stats.keys():
		final_stats[String(k)] = max(1, int(base_stats[k]))
	profile.stats = final_stats

	PersistenceManager.set_pending_new_profile(profile)
	print("[CharacterCreate] Start pressed. Launching HomeSector_1...")
	EventBus.request_start_game.emit("HomeSector_1", "PlayerSpawn")
