@tool
extends McpTestSuite
func suite_name() -> String:
	return "phase5c_native"
func test_launch_native_menu_regression() -> void:
	var args := PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/phase_5c_native_window.gd","--log-file",ProjectSettings.globalize_path("res://tests/phase_5c_native.log")])
	var process: int = OS.create_process(OS.get_executable_path(),args,false)
	assert_true(process > 0,"Native 5B menu regression process starts via MCP")
