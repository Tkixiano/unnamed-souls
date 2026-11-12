@tool
extends McpTestSuite
func suite_name() -> String:
	return "hotfix_parse"
func test_hotfix_scripts_load() -> void:
	for path in ["res://scripts/bosses/guardian_brain.gd","res://scripts/player/dodge_controller.gd","res://scripts/player/lock_on_controller.gd","res://tests/hotfix/a_checks.gd","res://tests/hotfix/b_checks.gd","res://tests/hotfix/c_checks.gd","res://tests/hotfix/d_checks.gd","res://tests/hotfix/keyboard_checks.gd"]:
		assert_true(load(path) != null,path)
