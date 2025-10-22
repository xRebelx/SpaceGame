@tool
extends EditorScript

# ScanForOldGameManager.gd — minimal, non-destructive
# Usage:
# 1) Put this at: res://Tools/ScanForOldGameManager.gd
# 2) Open Godot → Script Editor, open this file, click the "Run" (play) button in the script editor toolbar.
# 3) See the Output panel for any files/lines that reference res://Scripts/GameManager.gd
const TARGET := "res://Scripts/GameManager.gd"

func _run() -> void:
	print("[ScanForOldGameManager] Looking for: ", TARGET)
	_scan_dir("res://")

func _scan_dir(path:String) -> void:
	var d := DirAccess.open(path)
	if d == null: return
	d.list_dir_begin()
	while true:
		var f := d.get_next()
		if f == "": break
		if f.begins_with("."): continue
		var full := path.rstrip("/") + "/" + f
		if d.current_is_dir():
			_scan_dir(full)
		else:
			if full.ends_with(".tscn") or full.ends_with(".tres") or full.ends_with(".gd"):
				_check_file(full)
	d.list_dir_end()

func _check_file(p:String) -> void:
	var fa := FileAccess.open(p, FileAccess.READ)
	if fa == null: return
	var lines := fa.get_as_text().split("\n")
	fa.close()
	for i in lines.size():
		if TARGET in lines[i]:
			printerr("[MATCH] ", p, "  line ", i+1, ": ", lines[i])
