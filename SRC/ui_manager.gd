# res://src/ui_manager.gd
extends Node

var _popup_root: Control = null
var screens: Dictionary[String, Control] = {}

func init(popup_root: Control) -> void:
	_popup_root = popup_root
	print("[UIManager] Initialized with PopupRoot: ", _popup_root.name)

func show_screen(screen_name: String, scene_path: String, payload: Variant = null) -> void:
	if _popup_root == null:
		push_error("[UIManager] init(popup_root) not called or Popup root missing.")
		return
	if screens.has(screen_name):
		return

	var packed_scene := load(scene_path) as PackedScene
	var inst := packed_scene.instantiate()
	if not (inst is Control):
		push_error("[UIManager] '%s' root must be Control, got %s" % [scene_path, inst.get_class()])
		return

	_popup_root.add_child(inst)
	inst.name = screen_name
	screens[screen_name] = inst
	print("[UIManager] Added screen: ", screen_name, " to ", _popup_root.name)

	if inst.has_method("receive_payload"):
		inst.call("receive_payload", payload)

func close_screen(screen_name: String) -> void:
	if not screens.has(screen_name):
		return
	var inst: Control = screens[screen_name]
	inst.queue_free()
	screens.erase(screen_name)
	print("[UIManager] Closed screen: ", screen_name)
