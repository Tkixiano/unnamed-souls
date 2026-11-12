extends "res://scripts/systems/menu_screen.gd"
func _ready() -> void:
	configure(str(ProjectSettings.get_setting("application/config/name","Soul game")).to_upper(),[[&"new_game","Nueva partida"],[&"options","Opciones"],[&"quit","Salir"]],"Prototipo de exposición · Fantasía medieval oscura")
	chosen.connect(get_node("/root/GameMenus").handle_choice)
