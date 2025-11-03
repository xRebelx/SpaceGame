# res://UI/Scripts/SectorIntroUI.gd
extends Control
class_name SectorIntroUI

@export var fade_in_time: float = 1.0
@export var display_time: float = 2.0
@export var fade_out_time: float = 1.0

# --- NEW: Animation timings ---
@export var blackout_fade_in_time: float = 1.0  # Time for black screen to fade in
@export var text_fade_in_time: float = 0.5     # Time for each label to fade in
@export var text_delay: float = 0.2            # Delay between labels fading in

# --- Node references ---
# Use % for unique names as requested
@onready var blackout: Control = %Blackout
@onready var vbox_parent: VBoxContainer = $CanvasLayer/VBoxParent # VBoxParent is not unique
@onready var sector_name_label: RichTextLabel = %SectorName
@onready var sector_faction_label: RichTextLabel = %SectorFaction

func _ready() -> void:
	# Ensure all elements are invisible on start
	if is_instance_valid(blackout):
		blackout.modulate.a = 0.0
	else:
		push_error("SectorIntroUI: Could not find @onready node %Blackout")
		
	if is_instance_valid(vbox_parent):
		vbox_parent.modulate.a = 0.0 # Hide parent container initially
	else:
		push_error("SectorIntroUI: Could not find $CanvasLayer/VBoxParent!")
	
	if is_instance_valid(sector_name_label):
		sector_name_label.modulate.a = 0.0
	else:
		push_error("SectorIntroUI: Could not find @onready node %SectorName")
		
	if is_instance_valid(sector_faction_label):
		sector_faction_label.modulate.a = 0.0
	else:
		push_error("SectorIntroUI: Could not find @onready node %SectorFaction")

func fade_in_blackout(on_complete: Callable) -> void:
	"""
	Called by main.gd BEFORE the scene swap.
	Fades in the blackout panel, then calls the on_complete callable.
	"""
	if not is_instance_valid(blackout):
		on_complete.call() # Fail safe, call immediately
		return

	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(blackout, "modulate:a", 1.0, blackout_fade_in_time)
	tween.tween_callback(on_complete)

func show_with_data(data: SectorData) -> void:
	"""
	Called by main.gd AFTER the scene swap.
	Screen is already black. Plays the text fade-in and full fade-out sequence.
	"""
	# 1. Populate data
	if data:
		if is_instance_valid(sector_name_label):
			sector_name_label.text = data.sector_name
		if is_instance_valid(sector_faction_label):
			sector_faction_label.text = data.controlling_faction
	else:
		# Fallback if data is missing
		if is_instance_valid(sector_name_label):
			sector_name_label.text = "Unknown Sector"
		if is_instance_valid(sector_faction_label):
			sector_faction_label.text = "Uncharted"
	
	# 2. Ensure labels are invisible and their parent is visible
	if is_instance_valid(sector_name_label):
		sector_name_label.modulate.a = 0.0
	if is_instance_valid(sector_faction_label):
		sector_faction_label.modulate.a = 0.0
	if is_instance_valid(vbox_parent):
		vbox_parent.modulate.a = 1.0 # Make parent container visible

	# 3. Start the sequential fade-in part
	# This first tween is sequential (set_parallel(false) is default)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	
	# Fade In SectorName
	tween.tween_property(sector_name_label, "modulate:a", 1.0, text_fade_in_time)
	tween.tween_interval(text_delay)
	
	# Fade In SectorFaction
	tween.tween_property(sector_faction_label, "modulate:a", 1.0, text_fade_in_time)
	
	# Wait
	tween.tween_interval(display_time)
	
	# --- FIX ---
	# When the sequential tween is finished, call the function
	# that will create and run the parallel fade-out tween.
	tween.finished.connect(_start_parallel_fade_out)
	# --- END FIX ---


func _start_parallel_fade_out() -> void:
	"""
	Creates and runs the parallel fade-out tween.
	"""
	
	# --- THIS IS THE FIX ---
	# Start the gameplay music and tell it to fade in over
	# the *exact same duration* as our visual fade-out.
	if MusicManager:
		MusicManager.play_gameplay_music(fade_out_time)
	# --- END OF FIX ---
	
	# This tween starts immediately
	var parallel_tween := create_tween().set_parallel(true)
	
	# Add fade-out properties
	parallel_tween.tween_property(blackout, "modulate:a", 0.0, fade_out_time)
	parallel_tween.tween_property(vbox_parent, "modulate:a", 0.0, fade_out_time)
	
	# 4. Free the entire scene and notify game when this tween is done
	parallel_tween.finished.connect(queue_free)
	parallel_tween.finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	EventBus.sector_intro_complete.emit()
