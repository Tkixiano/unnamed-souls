extends RefCounted
## Labels describe the mapping advertised by Godot, not a verified hardware model.
static func profile_for_device(device_name: String, mapped: bool, vendor: int = 0) -> String:
	if not mapped: return "generic"
	var lowered: String = device_name.to_lower()
	if vendor == 0x054c or "dualsense" in lowered or "dualshock" in lowered or "ps4 controller" in lowered or "ps5 controller" in lowered:
		return "playstation"
	if vendor == 0x045e or "xbox" in lowered: return "xbox"
	return "generic"

static func profile_for_id(device: int) -> String:
	if device not in Input.get_connected_joypads(): return "generic"
	var info: Dictionary = Input.get_joy_info(device) if Input.has_method("get_joy_info") else {}
	return profile_for_device(Input.get_joy_name(device),Input.is_joy_known(device),int(info.get("vendor_id",0)))

static func labels(profile: String) -> Dictionary:
	if profile == "keyboard":
		return {"move":"WASD", "camera":"flechas o arrastrar con clic derecho", "interact":"F", "lock":"Q / clic de rueda", "light":"clic izquierdo / J", "heavy":"Shift / K", "block":"mantener Ctrl", "dodge":"dirección + toque y soltar Espacio", "estus":"E", "grip":"R"}
	if profile == "xbox":
		return {"move":"stick izquierdo", "camera":"stick derecho", "interact":"A", "lock":"R3", "light":"RB", "heavy":"RT", "block":"mantener LB", "dodge":"dirección + toque y soltar B", "estus":"X", "grip":"Y"}
	if profile == "playstation":
		return {"move":"stick izquierdo", "camera":"stick derecho", "interact":"Cruz", "lock":"R3", "light":"R1", "heavy":"R2", "block":"mantener L1", "dodge":"dirección + toque y soltar Círculo", "estus":"Cuadrado", "grip":"Triángulo"}
	return {"move":"control de movimiento", "camera":"control de cámara", "interact":"botón de interacción", "lock":"botón de fijación", "light":"botón de ataque ligero", "heavy":"botón de ataque fuerte", "block":"mantener el botón de bloqueo", "dodge":"dirección + toque y soltar el botón de esquiva", "estus":"botón de usar objeto", "grip":"botón de empuñadura"}
