# SectorRoot.gd
extends Node2D
class_name SectorRoot

@export var sector_data: Resource
@export var sector_id: String = ""

func _ready() -> void:
	if sector_id.is_empty():
		var scene_path: String = get_scene_file_path()
		if scene_path != "":
			sector_id = scene_path.get_file().get_basename()
		if sector_data and "sector_id" in sector_data and str(sector_data.sector_id) != "":
			sector_id = str(sector_data.sector_id)

	# --- FIX ---
	# This was the cause of the double-signal race condition.
	# The UniverseManager is responsible for emitting this signal *after*
	# the player is spawned, not the sector itself upon _ready().
	#
	# if "current_sector_changed" in EventBus:
	#	EventBus.current_sector_changed.emit(sector_id)
	# --- END FIX ---
