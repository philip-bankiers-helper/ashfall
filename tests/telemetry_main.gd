extends "res://tests/integration.gd"

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		quit(2)
		return
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	main.new_campaign()
	stop_audio(main)
	main.field_menu.set_open(true)
	main._process(0.01)
	var before: Dictionary = main.telemetry.snapshot()
	var play_before: float = main.play_time
	main._process(0.25)
	var after: Dictionary = main.telemetry.snapshot()
	check(is_equal_approx(after.observation_seconds-before.observation_seconds,0.25), "main telemetry observes real callback duration while game menu paused")
	check(after.frame_callbacks == before.frame_callbacks+1 and main.play_time == play_before, "paused gameplay clock stops while telemetry callback count advances")
	check(after.focus_seconds == 0 and after.both_controllers_ready_while_focused_seconds == 0, "desktop main cannot accumulate XR focus or controller-ready duration")
	check(after.viewport_gpu_render_time.observed_count == 0, "headless main does not manufacture viewport GPU samples")
	print("TELEMETRY_OUTPUT_PATH ",ProjectSettings.globalize_path(main.telemetry.get_output_path()))
	print("TELEMETRY_MAIN_RESULT passes=",passed," failures=",failures.size()," synthetic=true headset_tested=false")
	await main._quit_game(0 if failures.is_empty() else 1, "test_complete")
