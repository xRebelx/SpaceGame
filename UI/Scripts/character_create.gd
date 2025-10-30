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

@onready var name_edit: LineEdit          = %NameEdit
@onready var name_warning: Label          = %NameWarning
@onready var class_list: OptionButton     = %ClassList
@onready var stats_preview: RichTextLabel = %StatsPreview
@onready var btn_back: Button             = %BtnBack
@onready var btn_start: Button            = %BtnStart

var _selected_class: Resource = null
const NAME_MAX_LENGTH: int = 15
var VALID_NAME_REGEX := RegEx.new()  # <-- was const; must be var

func _ready() -> void:
	# Prepare regex: only letters, numbers, and spaces
	var err := VALID_NAME_REGEX.compile("^[A-Za-z0-9 ]+$")
	if err != OK:
		push_error("[CharacterCreate] Failed to compile name regex.")

	if not (name_edit and name_warning and class_list and stats_preview and btn_back and btn_start):
		push_error("[CharacterCreate] Missing unique controls.")
		return

	for n in CLASS_PATHS.keys():
		class_list.add_item(n)

	class_list.item_selected.connect(_on_class_selected)
	btn_back.pressed.connect(_on_back_pressed)
	btn_start.pressed.connect(_on_start_pressed)

	# Enter submits (LineEdit is single-line by design)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.text_changed.connect(_on_name_changed)

	name_warning.visible = false
	class_list.select(0)
	_on_class_selected(0)
	_update_preview()
	print("[CharacterCreate] Ready and initialized.")

# === UI events ===
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
		stats_preview.text = "No class selected."
		return

	var display_name: String = _selected_class.get("display_name")
	var base_stats: Dictionary = _selected_class.get("base_stats")

	var lines: Array[String] = [display_name, ""]
	for k in base_stats.keys():
		lines.append("%s: %d" % [String(k), int(base_stats[k])])
	stats_preview.text = "\n".join(lines)

# === Name handling ===
func _on_name_submitted(new_text: String) -> void:
	# Trigger validation when Enter is pressed
	if _validate_name(new_text):
		btn_start.emit_signal("pressed")  # optional: auto-continue on Enter

func _on_name_changed(_new_text: String) -> void:
	# Hide warning while typing
	name_warning.visible = false

func _validate_name(name_text: String) -> bool:
	name_text = name_text.strip_edges()

	if name_text.is_empty():
		name_warning.text = "Please enter a name."
		name_warning.visible = true
		return false

	if name_text.length() > NAME_MAX_LENGTH:
		name_warning.text = "Name too long (max %d characters)." % NAME_MAX_LENGTH
		name_warning.visible = true
		return false

	# Allow only letters, numbers, spaces
	if VALID_NAME_REGEX.search(name_text) == null:
		name_warning.text = "Use letters, numbers, and spaces only."
		name_warning.visible = true
		return false

	name_warning.visible = false
	return true

# === Start game flow ===
func _on_start_pressed() -> void:
	var cap_name: String = name_edit.text.strip_edges()
	if not _validate_name(cap_name):
		return

	var profile := CaptainProfile.new()
	profile.captain_name = cap_name
	profile.class_id = String(_selected_class.get("id"))

	var base_stats: Dictionary = _selected_class.get("base_stats")
	var final_stats: Dictionary = {}
	for k in base_stats.keys():
		final_stats[String(k)] = max(1, int(base_stats[k]))
	profile.stats = final_stats

	PersistenceManager.set_pending_new_profile(profile)
	print("[CharacterCreate] Confirmed valid name '%s' and emitting new_game_confirmed." % cap_name)
	EventBus.new_game_confirmed.emit(profile)
