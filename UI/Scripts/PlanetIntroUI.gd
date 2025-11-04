# res://UI/Scripts/PlanetIntroUI.gd
extends Control
class_name PlanetIntroUI

@export var display_time: float = 2.0
@export var fade_out_time: float = 1.0
@export var blackout_fade_in_time: float = 1.0
@export var text_fade_in_time: float = 0.5
@export var text_delay: float = 0.2

# --- ADD THIS ---
var _is_docking: bool = false
# --- END ADD ---

@onready var blackout: Control = %Blackout
@onready var vbox_parent: VBoxContainer = $VBoxParent
@onready var planet_name_label: RichTextLabel = %PlanetName
@onready var planet_type_label: RichTextLabel = %PlanetType
@onready var planet_image: TextureRect = %PlanetImage

func _ready() -> void:
	if is_instance_valid(blackout):
		blackout.modulate.a = 0.0
	else:
		push_error("PlanetIntroUI: Could not find @onready node %Blackout")
		
	if is_instance_valid(vbox_parent):
		vbox_parent.modulate.a = 0.0
	else:
		push_error("PlanetIntroUI: Could not find $VBoxParent!")
	
	for n in [planet_name_label, planet_type_label, planet_image]:
		if is_instance_valid(n):
			n.modulate.a = 0.0
		else:
			push_error("PlanetIntroUI: Missing a required UI node.")

func fade_in_blackout(on_complete: Callable) -> void:
	if not is_instance_valid(blackout):
		on_complete.call()
		return

	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(blackout, "modulate:a", 1.0, blackout_fade_in_time)
	tween.tween_callback(on_complete)

func show_with_data(data: Variant) -> void:
	# 1. Populate data
	if data is SectorData:
		_is_docking = false # --- ADD THIS ---
		if is_instance_valid(planet_name_label):
			planet_name_label.text = data.sector_name
		if is_instance_valid(planet_type_label):
			planet_type_label.text = data.controlling_faction
		if is_instance_valid(planet_image):
			planet_image.visible = false
	
	elif data is PlanetData:
		_is_docking = true # --- ADD THIS ---
		if is_instance_valid(planet_name_label):
			planet_name_label.text = data.planet_name
		if is_instance_valid(planet_type_label):
			planet_type_label.text = "Type: %s | Faction: %s" % [data.planet_type, data.planet_faction]
		
		if is_instance_valid(planet_image):
			if data.texture:
				planet_image.texture = data.texture
				planet_image.visible = true
			else:
				planet_image.visible = false
			
	else:
		_is_docking = false # --- ADD THIS ---
		if is_instance_valid(planet_name_label):
			planet_name_label.text = "Unknown Destination"
		if is_instance_valid(planet_type_label):
			planet_type_label.text = "Uncharted"
		if is_instance_valid(planet_image):
			planet_image.visible = false
	
	# 2. Ensure labels are invisible and their parent is visible
	for n in [planet_name_label, planet_type_label, planet_image]:
		if is_instance_valid(n):
			n.modulate.a = 0.0
	if is_instance_valid(vbox_parent):
		vbox_parent.modulate.a = 1.0

	# 3. Start the sequential fade-in part
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	
	tween.tween_property(planet_name_label, "modulate:a", 1.0, text_fade_in_time)
	tween.tween_interval(text_delay)
	
	tween.tween_property(planet_type_label, "modulate:a", 1.0, text_fade_in_time)
	tween.tween_interval(text_delay)

	if is_instance_valid(planet_image) and planet_image.visible:
		tween.tween_property(planet_image, "modulate:a", 1.0, text_fade_in_time)
	
	tween.tween_interval(display_time)
	tween.finished.connect(_start_parallel_fade_out)


func _start_parallel_fade_out() -> void:
	# --- MODIFY THIS LINE ---
	if MusicManager and not _is_docking:
	# --- END MODIFY ---
		MusicManager.play_gameplay_music(fade_out_time)
	
	var parallel_tween := create_tween().set_parallel(true)
	
	parallel_tween.tween_property(blackout, "modulate:a", 0.0, fade_out_time)
	parallel_tween.tween_property(vbox_parent, "modulate:a", 0.0, fade_out_time)
	
	parallel_tween.finished.connect(queue_free)
	parallel_tween.finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	EventBus.sector_intro_complete.emit()
