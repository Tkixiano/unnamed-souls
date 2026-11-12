@tool
extends McpTestSuite
func suite_name() -> String:
	return "hotfix_native"
func test_launch_regressions() -> void:
	var args := PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/hotfix/native_regressions.gd","--log-file",ProjectSettings.globalize_path("res://tests/hotfix/regressions_native.log")])
	assert_true(OS.create_process(OS.get_executable_path(),args,false)>0)
