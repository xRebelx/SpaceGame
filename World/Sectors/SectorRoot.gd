# World/Sectors/SectorRoot.gd
@tool
extends Node2D
class_name SectorRoot

@export var sector_data: Resource
@export var sector_id: String = ""

# --- NEW BOUNDS CONTROLS ---
@export var bounds_center_path: NodePath

@export var bounds_size: Vector2 = Vector2(100000, 100000):
	set(value):
		bounds_size = value
		_update_bounds_data()

# --- ADD THIS VARIABLE ---
@export var debug_draw_bounds: bool = false:
	set(value):
		debug_draw_bounds = value
		queue_redraw() # Redraw when this is toggled in the inspector
# --- END ADD ---

var world_bounds: Rect2 = Rect2() 

var _center_node: Node2D = null
var _last_center_pos: Vector2 = Vector2.INF


func _ready() -> void:
	_update_bounds_data()
	
	if Engine.is_editor_hint():
		queue_redraw() 

	if sector_id.is_empty():
		var scene_path: String = get_scene_file_path()
		if scene_path != "":
			sector_id = scene_path.get_file().get_basename()
		if sector_data and "sector_id" in sector_data and str(sector_data.sector_id) != "":
			sector_id = str(sector_data.sector_id)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if bounds_center_path.is_empty():
			return
		
		if not is_instance_valid(_center_node):
			_center_node = get_node_or_null(bounds_center_path)
			if not is_instance_valid(_center_node) or not _center_node is Node2D:
				_center_node = null 
				return
		
		if _center_node.global_position != _last_center_pos:
			_update_bounds_data()
			_last_center_pos = _center_node.global_position

func _update_bounds_data() -> void:
	var center_pos := Vector2.ZERO

	if bounds_center_path.is_empty():
		if Engine.is_editor_hint():
			push_warning("SectorRoot: 'Bounds Center Path' is not set.")
	else:
		if not is_instance_valid(_center_node):
			_center_node = get_node_or_null(bounds_center_path)
		
		if is_instance_valid(_center_node) and _center_node is Node2D:
			center_pos = _center_node.global_position
		elif Engine.is_editor_hint():
			push_warning("SectorRoot: 'Bounds Center Path' node is invalid or not a Node2D.")
	
	var top_left = center_pos - (bounds_size / 2.0)
	world_bounds = Rect2(top_left, bounds_size)
	
	queue_redraw() # Always redraw (in-game or editor) when data changes

# --- MODIFIED DRAW FUNCTION ---
func _draw() -> void:
	# Only draw if the debug flag is on
	if not debug_draw_bounds:
		return

	# Draw the red box (works in-game and in-editor)
	if world_bounds.has_area():
		draw_rect(world_bounds, Color.RED, false, 5.0)

	# Only draw the crosshair in the editor (it's not needed in-game)
	if Engine.is_editor_hint():
		if world_bounds.has_area():
			var center = world_bounds.position + (world_bounds.size / 2.0)
			draw_line(center + Vector2.LEFT * 50, center + Vector2.RIGHT * 50, Color.RED, 3.0)
			draw_line(center + Vector2.UP * 50, center + Vector2.DOWN * 50, Color.RED, 3.0)
# --- END MODIFY ---
