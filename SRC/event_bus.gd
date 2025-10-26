extends Node
signal request_show_screen(name: String, payload)
signal request_close_screen(name: String)
signal new_game_confirmed(profile: Resource)  # CaptainProfile
signal request_start_game(sector_id: String, entry: String)
