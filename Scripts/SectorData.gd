## SectorData.gd — data-only Resource for a sector/region of space
##
## This script defines the *template* for a sector.
## To create a new sector:
## 1. Right-click in the FileSystem dock.
## 2. Choose "New..." -> "Resource...".
## 3. Search for and select "SectorData".
## 4. Save it as a .tres file (e.g., "res://Sectors/AlphaSector.tres").
## 5. Fill in the exported fields in the Inspector.

extends Resource
class_name SectorData

# ----- Basic Info -----
@export_group("Sector Info")
@export var name: String = "Unknown Sector"
@export var sector_type: String = "Neutral Space"
@export var controlling_faction: String = "Unclaimed"

# ----- Gameplay Modifiers -----
@export_group("Gameplay")
## How dangerous this sector is (0.0 = safe, 1.0 = high threat)
@export_range(0.0, 1.0, 0.01) var danger_level: float = 0.0
## Current faction hostility towards the player
## (-1.0 = Allied, 0.0 = Neutral, 1.0 = Hostile)
@export_range(-1.0, 1.0, 0.01) var player_hostility: float = 0.0

# ----- Map & Travel -----
@export_group("Map & Travel")
## The icon to display on the galaxy map
@export var map_icon: Texture2D
## The scene that will be loaded when warping to this sector
@export var sector_scene: PackedScene
