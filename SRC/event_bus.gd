# res://SRC/event_bus.gd
@warning_ignore_start("UNUSED_SIGNAL")

extends Node

func _ready() -> void:
	print("--- [EventBus] _ready() HAS EXECUTED ---")

# ===== UI Screens =====
signal request_show_screen(screen_name, payload) # Assumed payload arg
signal request_show_popup(screen_name, payload)
signal request_close_screen(screen_name)
signal new_game_confirmed(profile)
signal request_start_game(sector_id, entry)
signal save_notify(message: String)
# ===== HUD =====
signal request_show_hud(visible)
signal current_sector_changed(sector_id: String)

# ===== Warp & Transitions =====
signal player_initiated_warp(target_sector_id, target_gate_name)
signal sector_intro_complete
signal blackout_complete

# ===== Persistence & System Menu =====
signal request_save_game
signal request_load_game
signal game_save_successful

# --- NEW: Orbiting ---
signal player_entered_orbit(planet_node)
signal player_leave_orbit

@warning_ignore_restore("UNUSED_SIGNAL")
