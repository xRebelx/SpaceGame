# res://SRC/faction_manager.gd
extends Node

# Load the single source of truth
const FACTION_DATA_PATH = "res://Data/Factions/faction_data.tres"
var faction_data: FactionData = null

func _ready():
	if ResourceLoader.exists(FACTION_DATA_PATH):
		faction_data = load(FACTION_DATA_PATH)
	else:
		push_error("[FactionManager] FactionData resource not found!")
		faction_data = FactionData.new() # Fallback

# All functions now operate on the resource
func set_opinion(faction_id: String, value: int) -> void:
	faction_data.opinions[faction_id] = value

func get_opinion(faction_id: String) -> int:
	return faction_data.opinions.get(faction_id, 0)

func add_opinion(faction_id: String, delta: int) -> void:
	set_opinion(faction_id, get_opinion(faction_id) + delta)
