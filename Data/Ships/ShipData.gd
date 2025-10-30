# res://Data/Ships/ShipData.gd
extends Resource
class_name ShipData

signal ship_stats_changed(hull, max_hull, shield, max_shield)
signal weapon_changed(name)

@export var ship_id: String
@export var ship_name: String
@export var hull_template: Resource   # ShipHullData
@export var installed_components: Array[Resource] = []
@export var cargo: Array[Resource] = []

# --- FIX: Export the simple backing fields ---
@export var _current_hp: float = 100.0
@export var _max_hp: float = 100.0
@export var _current_shield: float = 0.0
@export var _max_shield: float = 0.0
@export var _weapon_name: String = "---"

# --- FIX: Do NOT export the properties ---
var current_hp: float:
	get: return _current_hp
	set(value):
		value = clamp(value, 0.0, _max_hp)
		if is_equal_approx(_current_hp, value): return
		_current_hp = value
		ship_stats_changed.emit(_current_hp, _max_hp, _current_shield, _max_shield)

var current_shield: float:
	get: return _current_shield
	set(value):
		value = clamp(value, 0.0, _max_shield)
		if is_equal_approx(_current_shield, value): return
		_current_shield = value
		ship_stats_changed.emit(_current_hp, _max_hp, _current_shield, _max_shield)

var max_hp: float:
	get: return _max_hp
	set(value):
		value = max(1.0, value)
		if is_equal_approx(_max_hp, value): return
		_max_hp = value
		if _current_hp > _max_hp:
			current_hp = _max_hp # This will trigger the signal
		else:
			ship_stats_changed.emit(_current_hp, _max_hp, _current_shield, _max_shield)

var max_shield: float:
	get: return _max_shield
	set(value):
		value = max(0.0, value)
		if is_equal_approx(_max_shield, value): return
		_max_shield = value
		if _current_shield > _max_shield:
			current_shield = _max_shield # This will trigger the signal
		else:
			ship_stats_changed.emit(_current_hp, _max_hp, _current_shield, _max_shield)

var weapon_name: String:
	get: return _weapon_name
	set(value):
		if _weapon_name == value: return
		_weapon_name = value
		weapon_changed.emit(_weapon_name)


# --- Helper Methods (Unchanged) ---
func initialize_stats(hp_max: float, sh_max: float, hp_current: float, sh_current: float) -> void:
	_max_hp = max(1.0, hp_max)
	_max_shield = max(0.0, sh_max)
	_current_hp = clamp(hp_current, 0.0, _max_hp)
	_current_shield = clamp(sh_current, 0.0, _max_shield)

func get_ship_stats_dict() -> Dictionary:
	return {
		"hull": _current_hp, "max_hull": _max_hp,
		"shield": _current_shield, "max_shield": _max_shield
	}

func apply_damage(amount: float) -> void:
	var remaining_damage := amount
	if _current_shield > 0.0:
		var damage_to_shield = min(_current_shield, remaining_damage)
		current_shield -= damage_to_shield # Use setter to trigger signal
		remaining_damage -= damage_to_shield
	
	if remaining_damage > 0.0:
		current_hp -= remaining_damage # Use setter to trigger signal

# --- NEW: Save/Load Methods ---
func save_data() -> Dictionary:
	"""Returns a dictionary of this resource's data."""
	# Save resource paths for sub-resources
	var hull_template_path = ""
	if hull_template:
		hull_template_path = hull_template.resource_path

	var components_paths = []
	for comp in installed_components:
		if comp:
			components_paths.append(comp.resource_path)

	var cargo_paths = []
	for item in cargo:
		if item:
			cargo_paths.append(item.resource_path)

	return {
		"ship_id": ship_id,
		"ship_name": ship_name,
		"_current_hp": _current_hp,
		"_max_hp": _max_hp,
		"_current_shield": _current_shield,
		"_max_shield": _max_shield,
		"_weapon_name": _weapon_name,
		"hull_template_path": hull_template_path,
		"components_paths": components_paths,
		"cargo_paths": cargo_paths
	}

func load_data(data: Dictionary):
	"""Populates this resource from a dictionary."""
	ship_id = data.get("ship_id", "")
	ship_name = data.get("ship_name", "")
	
	# We must use initialize_stats to set all values at once
	# to avoid signals firing with partial data
	var hp_max = data.get("_max_hp", 100.0)
	var sh_max = data.get("_max_shield", 50.0)
	var hp_current = data.get("_current_hp", 100.0)
	var sh_current = data.get("_current_shield", 50.0)
	initialize_stats(hp_max, sh_max, hp_current, sh_current)
	
	# Use setter for weapon name to fire signal
	self.weapon_name = data.get("_weapon_name", "---")

	# Load resources from saved paths
	var hull_path = data.get("hull_template_path", "")
	if not hull_path.is_empty():
		hull_template = load(hull_path)

	installed_components.clear()
	var comp_paths = data.get("components_paths", [])
	for path in comp_paths:
		if not path.is_empty():
			var comp = load(path)
			if comp:
				installed_components.append(comp)

	cargo.clear()
	var cargo_paths = data.get("cargo_paths", [])
	for path in cargo_paths:
		if not path.is_empty():
			var item = load(path)
			if item:
				cargo.append(item)

	# Manually fire signals just in case
	ship_stats_changed.emit(_current_hp, _max_hp, _current_shield, _max_shield)
	weapon_changed.emit(_weapon_name)
