# res://Data/Persistence/SaveState.gd
extends Resource
class_name SaveState

# --- Data from PlayerManager ---
@export var player_profile: CaptainProfile
@export var ship_data: ShipData

# --- Data from FactionManager ---
@export var faction_opinions: Dictionary

# --- Data from UniverseManager ---
@export var current_sector_id: String
@export var player_position: Vector2 # <-- ADD THIS LINE

@export var planet_orbital_states: Dictionary = {} # { sector_id -> { planet_name -> { "angle": f, "period": f, "clockwise": b } } }
@export var audio_settings: Dictionary = {}
