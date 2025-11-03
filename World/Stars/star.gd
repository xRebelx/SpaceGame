@tool
extends Node2D
class_name Star

# Identity
@export var id: String = "star_generic":
	set(value):
		id = value
		_apply_node_name()

@export var display_name: String = "Star":
	set(value):
		display_name = value
		_apply_node_name()

# Visuals
@export var texture: Texture2D:
	set(value):
		texture = value
		_apply_sprite() # Keep for in-editor updates

@export_range(4.0, 4096.0, 1.0, "or_greater") var radius_px: float = 96.0:
	set(value):
		radius_px = value
		_apply_sprite() # Keep for in-editor updates

@onready var _sprite: Sprite2D = $Sprite2D

func _enter_tree() -> void:
	add_to_group("stars")
	# --- MODIFIED: Removed _apply_sprite() from here ---
	_apply_node_name()

# --- NEW: Add _ready() function ---
func _ready() -> void:
	# If exported texture is null, grab it from the sprite
	if texture == null:
		if is_instance_valid(_sprite) and _sprite.texture != null:
			texture = _sprite.texture
			
	# Now, apply the correct texture and scale
	_apply_sprite()


func _apply_node_name() -> void:
	var label: String = display_name.strip_edges()
	if label == "":
		label = id
	if label != "":
		name = StringName(label)

func _apply_sprite() -> void:
	if not is_instance_valid(_sprite):
		return
	
	# --- MODIFIED: Always set texture from the exported var ---
	_sprite.texture = texture
	
	if _sprite.texture == null:
		return
	var w: float = float(_sprite.texture.get_width())
	if w <= 0.0:
		return
	var desired_diameter: float = radius_px * 2.0
	var scale_factor: float = desired_diameter / w
	_sprite.scale = Vector2(scale_factor, scale_factor)
