extends Control
class_name PlanetIntroUI

var name_label: RichTextLabel
var type_label: RichTextLabel
var preview_texture: TextureRect

func _ready() -> void:
	# Fullscreen and start transparent (UIManager fades modulate.a)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0

	# Your current names (from screenshot)
	# If you rename them later, just update these lookups or switch to %UniqueName.
	name_label = find_child("Planet Name RTL", true, false) as RichTextLabel
	type_label = find_child("Planet Type RTL", true, false) as RichTextLabel
	preview_texture = find_child("PlanetImage TR", true, false) as TextureRect

func set_from_planet(planet: Node2D) -> void:
	var pdata: Resource = null
	if planet.has_method("get"):
		# Your Planet.gd exports the Resource as `data`
		pdata = planet.get("data") if planet.has_method("get") else null
	if pdata == null and "data" in planet:
		pdata = planet.data

	if pdata:
		if name_label: name_label.text = str(pdata.get("name") if pdata.has_method("get") else pdata.name)
		if type_label: type_label.text = str(pdata.get("planet_type") if pdata.has_method("get") else pdata.planet_type)
		if preview_texture:
			preview_texture.texture = (pdata.get("preview_texture") if pdata.has_method("get") else pdata.preview_texture)
	else:
		if name_label: name_label.text = "Unknown"
		if type_label: type_label.text = ""
		if preview_texture: preview_texture.texture = null
