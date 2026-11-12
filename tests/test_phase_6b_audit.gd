@tool
extends McpTestSuite
func suite_name() -> String:
	return "phase6b_audit"
func test_inspect_export_environment() -> void:
	var editor_settings = EditorInterface.get_editor_settings()
	var data := {"godot_executable":OS.get_executable_path(),"version":Engine.get_version_info(),"processor":OS.get_processor_name(),"logical_cpus":OS.get_processor_count(),"memory":OS.get_memory_info(),"os":OS.get_distribution_name()+" "+OS.get_version(),"rcedit":editor_settings.get_setting("export/windows/rcedit") if editor_settings.has_setting("export/windows/rcedit") else "","main_scene":ProjectSettings.get_setting("application/run/main_scene")}
	FileAccess.open("res://tests/phase_6b_environment.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	assert_true(data.version.string.begins_with("4.6.3"))
