## PlanetData.gd — data-only Resource for planet metadata
extends Resource
class_name PlanetData

@export var name: String = "Unnamed"
@export var planet_type: String = "Unknown"    # e.g. "Terran", "Desert", "Gas Giant"
@export var can_dock: bool = true

# Optional worldbuilding hooks (expand later)
@export var has_wilderness: bool = true
@export var sells_food_water: bool = false
@export var sells_industrial: bool = false
@export var has_shipyard: bool = false
@export var faction: String = "Neutral"
@export var danger: float = 0.0                 # 0..1
@export var economy: String = "Mixed"
@export var preview_texture: Texture2D          # optional image for UI
