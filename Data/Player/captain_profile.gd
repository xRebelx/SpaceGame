# Data/Player/captain_profile.gd
extends Resource
class_name CaptainProfile

signal credits_changed(new_credits)

@export var captain_name: String = "Captain"
@export var class_id: String = ""
@export var stats: Dictionary = {}   # stat_name -> int

var _credits: int = 0
@export var credits: int:
	get:
		return _credits
	set(value):
		value = max(0, value)
		if _credits == value:
			return
		_credits = value
		credits_changed.emit(_credits)

# --- NEW: Save/Load Methods ---
func save_data() -> Dictionary:
	"""Returns a dictionary of this resource's data."""
	return {
		"captain_name": captain_name,
		"class_id": class_id,
		"stats": stats.duplicate(true),
		"credits": _credits
	}

func load_data(data: Dictionary):
	"""Populates this resource from a dictionary."""
	captain_name = data.get("captain_name", "Captain")
	class_id = data.get("class_id", "")
	stats = data.get("stats", {}).duplicate(true)
	# Use the setter to ensure signal emission
	self.credits = data.get("credits", 0)
