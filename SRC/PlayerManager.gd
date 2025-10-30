# SRC/PlayerManager.gd
extends Node

# These resources are the single source of truth
var captain_profile: CaptainProfile = null
var ship_data: ShipData = null

func _ready() -> void:
	# Create default resources on boot so the game doesn't crash if
	# loading fails or you are in a test scene.
	# A real game flow (New/Load) will overwrite these.
	if captain_profile == null:
		captain_profile = CaptainProfile.new()
		captain_profile.credits = 1000
	
	if ship_data == null:
		ship_data = ShipData.new()
		ship_data.initialize_stats(100.0, 50.0, 100.0, 50.0)
		# The default "---" from ship_data.gd will be used until
		# the real data is loaded by main.gd

# --- Accessors ---
func get_credits() -> int:
	if captain_profile:
		return captain_profile.credits
	return 0

func get_ship_stats() -> Dictionary:
	if ship_data:
		return ship_data.get_ship_stats_dict()
	return { "hull": 0, "max_hull": 0, "shield": 0, "max_shield": 0 }

func get_weapon_name() -> String:
	if ship_data:
		return ship_data.weapon_name
	return "—"

# --- Mutators (operations) ---
func add_credits(amount: int) -> void:
	if captain_profile:
		captain_profile.credits += amount

func set_ship_max(hull_max: float, shield_max: float) -> void:
	if ship_data:
		ship_data.max_hp = hull_max
		ship_data.max_shield = shield_max

func set_ship_current(hull: float, shield: float) -> void:
	if ship_data:
		ship_data.current_hp = hull
		ship_data.current_shield = shield

func apply_damage(amount: float) -> void:
	if ship_data:
		ship_data.apply_damage(amount)

func set_active_weapon_name(weapon_name: String) -> void:
	if ship_data:
		ship_data.weapon_name = weapon_name
