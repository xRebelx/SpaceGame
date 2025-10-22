# res://Scenes/UI Scenes/DockedUI.gd
extends Control
class_name DockedUI

signal undock_requested

var planet_name_node: Control = null        # Label or RichTextLabel
var faction_label: Label = null
var has_shipyard_label: Label = null
var has_wilderness_label: Label = null
var undock_btn: Button = null

func _ready() -> void:
	# IMPORTANT: Don't put a CanvasLayer inside this scene.
	# Keep everything under this root Control; UIManager already sits on a CanvasLayer(5).
	mouse_filter = Control.MOUSE_FILTER_STOP

	planet_name_node     = find_child("PlanetName", true, false) as Control
	faction_label        = find_child("OwnedFaction", true, false) as Label
	has_shipyard_label   = find_child("HasShipyard", true, false) as Label
	has_wilderness_label = find_child("HasWilderness", true, false) as Label
	undock_btn           = find_child("UnDockBTN", true, false) as Button

	if undock_btn and not undock_btn.is_connected("pressed", Callable(self, "_on_undock_pressed")):
		undock_btn.pressed.connect(Callable(self, "_on_undock_pressed"))

func _on_undock_pressed() -> void:
	emit_signal("undock_requested")

# Called by UIManager.gd after instancing
func set_from_planet(planet: Node2D) -> void:
	var pdata: Resource = null
	if "data" in planet:
		pdata = planet.data as Resource
	elif planet.has_method("get"):
		pdata = planet.get("data") as Resource

	if pdata:
		_set_text(planet_name_node, str(pdata.get("name") if pdata.has_method("get") else pdata.name))
		if faction_label:
			faction_label.text = "Faction: " + str(pdata.get("faction") if pdata.has_method("get") else pdata.faction)
		if has_shipyard_label:
			var hs: bool = bool(pdata.get("has_shipyard") if pdata.has_method("get") else pdata.has_shipyard)
			has_shipyard_label.text = "Has Shipyard: " + _yes_no(hs)
		if has_wilderness_label:
			var hw: bool = bool(pdata.get("has_wilderness") if pdata.has_method("get") else pdata.has_wilderness)
			has_wilderness_label.text = "Has Wilderness: " + _yes_no(hw)
	else:
		_set_text(planet_name_node, "Unknown")
		if faction_label:        faction_label.text        = "Faction: —"
		if has_shipyard_label:   has_shipyard_label.text   = "Has Shipyard: —"
		if has_wilderness_label: has_wilderness_label.text = "Has Wilderness: —"

func _set_text(node: Control, text: String) -> void:
	if node == null:
		return
	if node is Label:
		(node as Label).text = text
	elif node is RichTextLabel:
		var rtl := node as RichTextLabel
		rtl.bbcode_enabled = false
		rtl.clear()
		rtl.append_text(text)

func _yes_no(b: bool) -> String:
	return "Yes" if b else "No"
