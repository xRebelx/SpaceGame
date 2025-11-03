# res://SRC/universe_manager.gd
extends Node

signal sector_swap_complete(sector_data)

var _world_root: Node
var _entities_root: Node
var _player: Node2D
var _sectors: Dictionary[String, String] = {}   # id -> scene path

var _current_sector_id: String = ""
var _target_entry: String = ""
var _loading_path: String = ""
var _loading_progress: Array = []
var _is_loading: bool = false

# --- For loading a saved position ---
var _pending_position_override: Vector2 = Vector2.INF

# --- Planet persistence dictionary ---
# { sector_id -> { planet_name -> { "angle": f, "period": f, "clockwise": b } } }
var _planet_states: Dictionary = {}

# --- Flag to prevent re-saving state during a load operation ---
var _is_loading_from_save: bool = false


func init(world_root: Node, entities_root: Node) -> void:
	_world_root = world_root
	_entities_root = entities_root

func set_player(player: Node2D) -> void:
	_player = player

func register_sector(id: String, scene_path: String) -> void:
	_sectors[id] = scene_path

func get_current_sector_id() -> String:
	return _current_sector_id

# --- Getter for save game logic ---
func get_player_position() -> Vector2:
	if is_instance_valid(_player):
		return _player.global_position
	return Vector2.ZERO

# --- Setter for load game logic ---
func set_pending_position_override(pos: Vector2) -> void:
	_pending_position_override = pos

func set_is_loading_from_save(is_loading: bool) -> void:
	_is_loading_from_save = is_loading

# --- Getter/Setter for save/load logic ---

func get_planet_states() -> Dictionary:
	"""
	Called by PersistenceManager on save.
	Persists the *current* frame's angles for the active sector before saving.
	"""
	_persist_current_planet_states()
	return _planet_states.duplicate(true) # Return deep copy

func set_planet_states(states: Dictionary) -> void:
	"""Called by PersistenceManager on load."""
	# We must duplicate the dictionary.
	_planet_states = states.duplicate(true)


func _process(_delta: float) -> void:
	if not _is_loading:
		# --- Simulate data for unloaded sectors ---
		_simulate_unloaded_planets(_delta)
		return

	var status = ResourceLoader.load_threaded_get_status(_loading_path, _loading_progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_is_loading = false
			call_deferred("_complete_sector_swap")
			
		ResourceLoader.THREAD_LOAD_FAILED:
			_is_loading = false
			push_error("[UniverseManager] Failed to load sector: %s" % _loading_path)
				
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_is_loading = false
			push_error("[UniverseManager] Invalid resource path: %s" % _loading_path)

func change_sector(id: String, entry_node_name: String = "PlayerSpawn") -> void:
	if _is_loading:
		push_warning("[UniverseManager] Already loading a sector.")
		return
		
	print("[UniverseManager] change_sector() called for id: %s, entry: %s" % [id, entry_node_name])
	
	# If this is a normal warp (not a load), save the state of the sector we are leaving.
	if not _is_loading_from_save:
		_persist_current_planet_states()
	
	# This was a load operation. Consume the flag so the *next* warp is normal.
	_is_loading_from_save = false
	
	_current_sector_id = id
	_target_entry = entry_node_name
	_loading_path = _sectors.get(id, "")
	
	if _loading_path.is_empty():
		push_error("[UniverseManager] Unknown sector id: %s" % id)
		return

	var err = ResourceLoader.load_threaded_request(_loading_path)
	if err != OK:
		push_error("[UniverseManager] Failed to start threaded load: %s" % err)
		return
		
	_is_loading = true

# --- HELPER FUNCTIONS ---

func _simulate_unloaded_planets(delta: float) -> void:
	"""
	Updates the orbital angle for all planets in all sectors
	EXCEPT the currently loaded one.
	"""
	for sector_id in _planet_states.keys():
		if sector_id == _current_sector_id:
			continue # Skip the active, loaded sector
		
		var planets_in_sector = _planet_states[sector_id]
		for state in planets_in_sector.values():
			var period = state.get("period", 0.0)
			if period <= 0.0001:
				continue
			
			var dir: float = -1.0 if state.get("clockwise", false) else 1.0
			var delta_angle: float = dir * (TAU / max(0.0001, period)) * delta
			state["angle"] = fmod(state.get("angle", 0.0) + delta_angle, TAU)

func _persist_current_planet_states() -> void:
	"""
	Finds all Planet nodes in the currently loaded sector
	and saves their final state into _planet_states.
	"""
	if _current_sector_id.is_empty():
		return
	
	var current_sector_node: Node = null
	if _world_root.get_child_count() > 0:
		current_sector_node = _world_root.get_child(0)
		if not is_instance_valid(current_sector_node) or current_sector_node.name != _current_sector_id:
			print("[UniverseManager] Persist state: Node name mismatch. Node: %s, ID: %s" % [current_sector_node.name, _current_sector_id])
			return
	else:
		return

	if not _planet_states.has(_current_sector_id):
		_planet_states[_current_sector_id] = {}
	
	var sector_states = _planet_states[_current_sector_id]
	
	for planet in current_sector_node.find_children("", "Planet", true, false):
		var planet_name = planet.name
		if not sector_states.has(planet_name):
			sector_states[planet_name] = {}
		
		var state = sector_states[planet_name]
		state["angle"] = planet.get_current_angle()
		state["period"] = planet.orbital_period_sec
		state["clockwise"] = planet.clockwise

func _apply_planet_states(sector_node: Node) -> void:
	"""
	Finds all Planet nodes in the newly loaded sector
	and injects their saved state.
	"""
	var sector_id = sector_node.name
	var states = _planet_states.get(sector_id)

	# --- MODIFIED: This function is now much simpler ---
	
	if states == null:
		# This is its first-ever load. Capture default state.
		var old_id = _current_sector_id
		_current_sector_id = sector_id
		_persist_current_planet_states()
		_current_sector_id = old_id
		# ...and fall through to initialize them
	else:
		# Apply saved states
		for planet in sector_node.find_children("", "Planet", true, false):
			if states.has(planet.name):
				planet.set_current_angle(states[planet.name]["angle"])
			else:
				# This is a new planet added to the sector? Capture its default state.
				_persist_current_planet_states()

	# --- FIX: After setting angles, tell all planets to snap to position ---
	# This sets their visual position before _process() runs.
	for planet in sector_node.find_children("", "Planet", true, false):
		planet.initialize_position()
	# --- END FIX ---

# --- END HELPER FUNCTIONS ---


func _complete_sector_swap() -> void:
	print("[UniverseManager] Completing sector swap...")
	
	var packed := ResourceLoader.load_threaded_get(_loading_path) as PackedScene
	if not packed:
		push_error("[UniverseManager] Failed to get loaded resource: %s" % _loading_path)
		return

	for c in _world_root.get_children():
		c.queue_free()
	await get_tree().process_frame

	var sector := packed.instantiate()
	_world_root.add_child(sector)
	sector.name = _current_sector_id
	
	# --- ADD THIS BLOCK ---
	# Pass the sector's bounds to the player
	if is_instance_valid(_player) and "set_world_bounds" in _player:
		if "world_bounds" in sector:
			_player.set_world_bounds(sector.world_bounds)
		else:
			# Clear bounds if the new sector doesn't have one defined
			_player.set_world_bounds(Rect2()) 
	# --- END ADD ---

	# --- Apply loaded state to the sector we are ENTERING ---
	_apply_planet_states(sector)
	
	# --- THIS IS THE "JAR" ---
	var entry: Node = sector.get_node_or_null(_target_entry)
	if _player and is_instance_valid(_player):
		
		if _pending_position_override != Vector2.INF:
			_player.global_position = _pending_position_override
			_player.global_rotation = 0.0
			_pending_position_override = Vector2.INF
			
		elif entry and entry is Node2D:
			_player.global_position = (entry as Node2D).global_position
			_player.global_rotation = (entry as Node2D).global_rotation
			
			var gate_node: Node = entry
			if (gate_node == null or not gate_node.has_method("suppress_for")) and entry.get_parent():
				var p := entry.get_parent()
				if p and p.has_method("suppress_for"):
					gate_node = p
					
			if gate_node and gate_node.has_method("suppress_for"):
				gate_node.call("suppress_for", _player)

		elif not entry:
			print("[UniverseManager] WARNING: Could not find entry node '%s' in new sector." % _target_entry)
	
	var sector_data: SectorData = null
	if "sector_data" in sector:
		sector_data = sector.sector_data
	
	sector_swap_complete.emit(sector_data)
	EventBus.current_sector_changed.emit(_current_sector_id)
