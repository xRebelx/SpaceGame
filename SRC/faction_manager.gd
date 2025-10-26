extends Node

# Opinions: faction_id -> int (neg hostile, 0 neutral, pos friendly)
var opinions: Dictionary = {}  # default 0 for unknown

func set_opinion(faction_id: String, value: int) -> void:
	opinions[faction_id] = value

func get_opinion(faction_id: String) -> int:
	return opinions.get(faction_id, 0)

func add_opinion(faction_id: String, delta: int) -> void:
	set_opinion(faction_id, get_opinion(faction_id) + delta)
