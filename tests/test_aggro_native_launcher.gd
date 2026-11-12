@tool
extends McpTestSuite
func suite_name() -> String:
	return "aggro_native"
func test_launch_native_regressions() -> void:
	var args := PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/aggro_native_window.gd","--log-file",ProjectSettings.globalize_path("res://tests/aggro_native.log")])
	assert_true(OS.create_process(OS.get_executable_path(),args,false) > 0,"Native audio/menu regressions start via Godot AI MCP")
