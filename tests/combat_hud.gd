extends SceneTree

const CombatHud = preload("res://scripts/combat_hud.gd")
const Player = preload("res://scripts/player.gd")

class DummyGame extends Node:
	var health := 100.0
	var shield := 100.0
	var paused := false
	var dead := false
	var complete := false

var passes := 0
var failures := 0

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
	var game := DummyGame.new()
	root.add_child(game)
	var player := Player.new()
	game.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.setup(false)
	var hud := CombatHud.new()
	game.add_child(hud)
	hud.setup(player, game)
	hud.set_process(false)
	check(hud.get_parent() == player.get_view_camera(), "meters follow view camera")
	check(hud.visible and hud.health_fill.scale.x == 1.0 and hud.shield_fill.scale.x == 1.0 and hud.sprint_fill.scale.x == 1.0, "full health and shield visible")
	game.health = -4.0
	game.shield = 145.0
	hud.refresh(0.0)
	check(CombatHud.meter_fraction(game.health) == 0.0 and CombatHud.meter_fraction(game.shield) == 1.0, "meters clamp to zero and maximum")
	check(hud.health_fill.scale.x < 0.001 and hud.shield_fill.scale.x == 1.0, "meter geometry clamps to valid range")
	game.health = 35.0
	game.shield = 62.0
	hud.refresh(0.0)
	check(is_equal_approx(hud.health_fill.scale.x, 0.35) and is_equal_approx(hud.shield_fill.scale.x, 0.62), "bar fractions reflect both pools")
	game.paused = true
	hud.refresh(0.0)
	check(not hud.visible, "menu and pause hide meters")
	game.paused = false
	game.dead = true
	hud.refresh(0.0)
	check(not hud.visible, "death hides meters")
	game.dead = false
	game.complete = true
	hud.refresh(0.0)
	check(not hud.visible, "completion hides meters")
	game.complete = false
	hud.refresh(0.0)
	check(hud.visible, "combat meters return")
	var view := Transform3D(Basis.IDENTITY, Vector3(5.0, 2.0, 8.0))
	check(is_equal_approx(CombatHud.bearing_from_view(view, Vector3(5, 80, 3)), 0.0), "front bearing ignores height")
	check(is_equal_approx(CombatHud.bearing_from_view(view, Vector3(10, -30, 8)), PI / 2.0), "right bearing ignores height")
	check(is_equal_approx(CombatHud.bearing_from_view(view, Vector3(0, 2, 8)), -PI / 2.0), "left bearing")
	check(absf(CombatHud.bearing_from_view(view, Vector3(5, 2, 13))) > 3.1, "rear bearing")
	var turned := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO)
	check(is_equal_approx(CombatHud.bearing_from_view(turned, Vector3(-5, 4, 0)), 0.0), "bearing rotates with headset yaw")
	var camera := player.get_view_camera()
	camera.global_transform = view
	hud.notify_damage(Vector3(10, 25, 8))
	check(hud.hit_arrow.visible and hud.hit_arrow.position.x > 0.1 and hud.hit_arrow.position.y < -0.4 and is_equal_approx(hud.hit_arrow.rotation.z,-PI/2), "right hit displays large low chain with actual right bearing")
	hud.refresh(0.6)
	check(hud.hit_arrow.visible and hud.hit_material.albedo_color.a < 0.5, "arrow fades during one-second cue")
	hud.refresh(0.5)
	check(not hud.hit_arrow.visible, "arrow expires")
	# The helper reparents beneath the player's camera; freeing the game must
	# release the camera, helper and every generated HUD surface together.
	game.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(game) and not is_instance_valid(player) and not is_instance_valid(camera) and not is_instance_valid(hud), "camera-mounted HUD releases with game")
	print("COMBAT_HUD_RESULT passes=", passes, " failures=", failures, " synthetic=true headset_tested=false")
	quit(0 if failures == 0 else 1)


