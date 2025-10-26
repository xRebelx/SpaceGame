extends Node

var _pending_new_profile: CaptainProfile = null
var save_path := "user://savegame.res"

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

func set_pending_new_profile(p: CaptainProfile) -> void:
	_pending_new_profile = p

func consume_pending_new_profile() -> CaptainProfile:
	var p := _pending_new_profile
	_pending_new_profile = null
	return p

func save_game() -> void:
	# later: gather data into a SaveState Resource and save
	pass

func load_game() -> void:
	# later: load SaveState Resource and drive UniverseManager/UI
	pass
