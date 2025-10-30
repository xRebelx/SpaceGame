# res://SRC/SectorManager.gd
extends Node

# --- THIS IS THE FIX ---
# We preload the resources directly. This forces the Godot
# exporter to see them and include them in the .pck file.
const SECTOR_RESOURCES: Dictionary[String, Resource] = {
	"HomeSector_1":  preload("res://Data/Sectors/HomeSector_1.tres"),
	"MiningSector_1": preload("res://Data/Sectors/MiningSector_1.tres"),
}
# --- END FIX ---


static func get_resource_path_for_id(sector_id: String) -> String:
	# We check the preloaded dictionary keys first
	if SECTOR_RESOURCES.has(sector_id):
		# Return the path from the preloaded resource
		return SECTOR_RESOURCES[sector_id].resource_path
		
	# Fallbacks if someone passed "HomeSector1" without underscore
	if sector_id == "HomeSector1":
		return "res://Data/Sectors/HomeSector_1.tres"
	if sector_id == "MiningSector1":
		return "res://Data/Sectors/MiningSector_1.tres"
	return ""  # signal not found


static func get_sector_info(sector_id: String) -> Dictionary:
	# --- THIS IS THE OTHER PART OF THE FIX ---
	# Instead of loading from a path, we get the preloaded resource
	var res: Resource = SECTOR_RESOURCES.get(sector_id)
	
	if res == null:
		# Fallback for the non-underscore versions
		if sector_id == "HomeSector1":
			res = SECTOR_RESOURCES.get("HomeSector_1")
		elif sector_id == "MiningSector1":
			res = SECTOR_RESOURCES.get("MiningSector_1")

	if res == null:
		push_warning("[SectorManager] Could not find preloaded sector data for: %s" % sector_id)
		return {}
	# --- END FIX ---

	var info: Dictionary = {}
	if "sector_name" in res: info["sector_name"] = res.sector_name
	if "controlling_faction" in res: info["controlling_faction"] = res.controlling_faction
	if "security_level" in res: info["security_level"] = res.security_level
	if "pirate_activity" in res: info["pirate_activity"] = res.pirate_activity
	return info
