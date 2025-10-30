# res://Data/Factions/faction_data.gd
extends Resource
class_name FactionData

# This dictionary holds the state
@export var opinions: Dictionary = {}

func save_data() -> Dictionary:
	return { "opinions": opinions.duplicate(true) }

func load_data(data: Dictionary):
	opinions = data.get("opinions", {}).duplicate(true)
