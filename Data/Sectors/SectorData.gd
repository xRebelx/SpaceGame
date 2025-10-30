# /Data/Sectors/sector_data.gd
class_name SectorData
extends Resource

@export var sector_id: String
@export var sector_name: String
@export var controlling_faction: String
@export var security_level: String      # <-- ADD THIS
@export var pirate_activity: String   # <-- ADD THIS
@export var planets: Array[Resource] = []  # PlanetData
@export var neighbors: Array[StringName] = []
