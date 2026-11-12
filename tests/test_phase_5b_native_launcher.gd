@tool
extends McpTestSuite
## Godot AI MCP editor test launches this same project in a native game window.
## No editor preferences or embedding settings are modified.
func suite_name() -> String:
	return "phase5b_native"
func test_launch_native_game_validation() -> void:
	var args := PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/phase_5b_native_window.gd","--log-file",ProjectSettings.globalize_path("res://tests/phase_5b_native.log")])
	var process: int = OS.create_process(OS.get_executable_path(),args,false)
	assert_true(process > 0,"Native validation process starts")
	FileAccess.open("res://tests/phase_5b_native_launch.json",FileAccess.WRITE).store_string(JSON.stringify({"pid":process,"engine":Engine.get_version_info(),"purpose":"Repeat unchanged menu checks outside editor embedding","changed_editor_settings":false},"\t"))
