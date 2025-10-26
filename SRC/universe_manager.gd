extends Node

var _world_root: Node = null
var _entities_root: Node = null
var _player: Node2D = null

# sector_id -> scene path
var _sectors: Dictionary[String, String] = {}

func init(world_root: Node, entities_root: Node) -> void:
	_world_root = world_root
	_entities_root = entities_root

func set_player(player: Node2D) -> void:
	_player = player

func register_sector(id: String, scene_path: String) -> void:
	_sectors[id] = scene_path

# --- internal loader (coroutine) ---
func _load_sector(id: String) -> Node:
	assert(_world_root, "UniverseManager.init() not called yet.")
	var path: String = _sectors.get(id, "")
	assert(path != "", "Unknown sector id: %s" % id)

	# Clear old sectors
	for c in _world_root.get_children():
		c.queue_free()
	await get_tree().process_frame

	# Instance new sector
	var packed: PackedScene = load(path) as PackedScene
	assert(packed, "Failed to load sector scene: %s" % path)
	var sector: Node = packed.instantiate()
	_world_root.add_child(sector)
	sector.name = id
	return sector

# Teleport player to named entry in the sector. If it's a BlackHoleGate, suppress immediate retrigger.
func change_sector(id: String, entry_node_name: String = "PlayerSpawn") -> void:
	var sector: Node = await _load_sector(id)

	if not (_player and is_instance_valid(_player)):
		return

	var entry: Node = sector.get_node_or_null(entry_node_name)
	if entry and entry is Node2D:
		_player.global_position = (entry as Node2D).global_position
		_player.global_rotation = (entry as Node2D).global_rotation

		if "suppress_for" in entry:
			entry.call("suppress_for", _player)
	else:
		push_warning("No entry node '%s' in sector '%s'." % [entry_node_name, id])
