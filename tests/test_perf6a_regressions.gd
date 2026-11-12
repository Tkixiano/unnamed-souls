@tool
extends McpTestSuite
func suite_name() -> String:
	return "perf6a_regressions"
func test_launch_native_regressions() -> void:
	var args := PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/perf_6a/native_regressions.gd","--log-file",ProjectSettings.globalize_path("res://tests/perf_6a/regressions_native.log")])
	assert_true(OS.create_process(OS.get_executable_path(),args,false)>0)
