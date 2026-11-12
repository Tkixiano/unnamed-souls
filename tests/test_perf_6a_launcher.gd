@tool
extends McpTestSuite
func suite_name() -> String:
	return "perf6a"
func test_launch_performance_capture() -> void:
	var variant: String = FileAccess.get_file_as_string("res://tests/perf_6a/request.txt").strip_edges()
	assert_true(variant in ["baseline","optimized"])
	var ready := "res://tests/perf_6a/"+variant+"_sampler_ready"
	if FileAccess.file_exists(ready): DirAccess.remove_absolute(ProjectSettings.globalize_path(ready))
	var args := PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/perf_6a/benchmark.gd","--log-file",ProjectSettings.globalize_path("res://tests/perf_6a/"+variant+".log"),"--",variant])
	assert_true(OS.create_process(OS.get_executable_path(),args,false)>0)
