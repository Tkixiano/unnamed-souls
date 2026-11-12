extends RefCounted
const BUSES = [&"Music", &"SFX", &"Ambient"]
static func ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0: continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count-1
		AudioServer.set_bus_name(index,bus)
		AudioServer.set_bus_send(index,"Master")
