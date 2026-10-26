extends SceneTree
const Player = preload("res://scripts/player.gd")
const Menu = preload("res://scripts/menu.gd")
var passes := 0
var failures := 0
var changes := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("PASS ", label)
	else:
		failures += 1
		printerr("FAIL ", label)

func run() -> void:
	var player := Player.new()
	root.add_child(player)
	player.setup(false)
	player.set_physics_process(false)
	var menu := Menu.new()
	root.add_child(menu)
	menu.setup(player)
	menu.set_process(false)
	menu.settings_changed.connect(func(_settings: Dictionary): changes += 1)
	check(is_equal_approx(menu.difficulty, 0.5), "default moderate difficulty")
	menu._choose(5)
	check(menu.settings_page == "game" and menu._sliders[0].visible and not menu._buttons[0].visible, "game page exposes native difficulty slider")
	menu._sliders[0].value = 73.0
	check(is_equal_approx(menu.difficulty, 0.73) and changes > 0, "actual desktop slider emits and applies73percent")
	var saved := menu.get_settings()
	menu.set_difficulty(0.2)
	menu.apply_settings(saved)
	check(is_equal_approx(menu.difficulty, 0.73), "difficulty persists through settings roundtrip")
	menu._adjust_setting(0, -1.0)
	check(is_equal_approx(menu.difficulty, 0.68), "VR adjustment route lowers difficulty")
	menu.adjust_difficulty_stick(1.0, 0.1)
	menu.adjust_difficulty_stick(1.0, 0.1)
	check(is_equal_approx(menu.difficulty, 0.74), "held VR stick continuously sweeps slider")
	menu.set_difficulty(1.0)
	menu._adjust_setting(0, 1.0)
	check(is_equal_approx(menu.difficulty, 1.0), "upper bound clamps instead of wrapping")
	menu.set_difficulty(-5.0)
	check(is_equal_approx(menu.difficulty, 0.0), "lower bound clamps")
	for value in [NAN, INF, {}, [], "hard", null]:
		menu.apply_settings({"difficulty": value})
		check(is_equal_approx(menu.difficulty, 0.5), "malformed difficulty defaults safely")
	menu.set_difficulty(NAN)
	check(is_equal_approx(menu.difficulty, 0.5), "direct NaN rejected")
	player.xr_enabled = true
	player.tracking_available = false
	menu._process(0.016)
	check(is_equal_approx(menu.difficulty, 0.5), "lost tracking cannot adjust difficulty")
	player.xr_enabled = false
	player.tracking_available = true
	player.turning_style = "smooth"
	player.smooth_ease_in = true
	player.apply_turn_input(0.9, 0.05)
	var before := player.rotation.y
	player.apply_turn_input(player.get_turn_axis(Vector2(0.4, -0.8)), 0.1)
	check(is_equal_approx(before, player.rotation.y) and is_zero_approx(player._smooth_turn_rate), "diagonal eject corridor prevents yaw and clears easing")
	menu.free()
	player.free()
	print("DIFFICULTY_SETTINGS_RESULT passes=", passes, " failures=", failures)
	quit(0 if failures == 0 else 1)
