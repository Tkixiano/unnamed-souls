extends SceneTree
func _initialize() -> void:
	var text: String = Engine.get_license_text()+"\n\nTHIRD-PARTY LICENSE TEXTS\n"
	var licenses: Dictionary = Engine.get_license_info()
	for key in licenses:
		text += "\n"+str(key)+"\n"+str(licenses[key])+"\n"
	text += "\nCOPYRIGHT NOTICES\n"+JSON.stringify(Engine.get_copyright_info(),"\t")
	FileAccess.open("C:/JUEGOs 3D/soul-game/soulgameexported/Godot-License.txt",FileAccess.WRITE).store_string(text)
	quit()
