extends "res://tests/stereo_dynamic_benchmark.gd"
## Actual main scene + weapon rack + production spatial HUD. Independent eyes.
var game: Node3D
var weapon_samples := {"kestrel":[],"cinder":[]}
var next_shot := 0.0
var weapons_seen: Array[String] = []
var captures := {}
var shot_counts := {"kestrel":0,"cinder":0}

func _create_world() -> Node3D:
	game = load("res://main.tscn").instantiate()
	add_child(game)
	# Isolated APPDATA and --desktop are required by the runner. Never load XR.
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.ui_layer.visible = false
	game.vr_label.visible = true
	game.field_menu.set_process_unhandled_input(false)
	game.weapon.shot.connect(func(_origin,_direction,_damage): shot_counts["kestrel"] += 1)
	game.weapon.pellet_shot.connect(func(_origin,_directions,_damage): shot_counts["cinder"] += 1)
	for enemy in game.enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	game.enemies.clear()
	game.encounter_active = true
	return game.world

func _build_fixture() -> void:
	super._build_fixture()
	game.enemies.clear()
	for actor in actor_root.get_children():
		if actor is AshEnemy:
			actor.target = game.player
			actor.healthmax = 1000000.0
			actor.health = actor.healthmax
			# Explicit fixture-only durable enemies keep all eight AI active.
			game.enemies.append(actor)
	game.weapon.reset_weapon()
	game.weapon.select_weapon(0)
	next_shot = 0.35
	game.vr_label.visible = true

func _process(delta: float) -> void:
	if finished or not is_instance_valid(game): return
	# Position the real player camera at the midpoint of the two rendered eyes.
	# The root camera renders no third 3D view, but its weapon/HUD nodes remain
	# part of the shared World3D and are visible to both independent cameras.
	var view: Dictionary = VIEWS[view_index]
	var center: Vector3 = view.position + Vector3(sin(phase_time*.8)*.6,sin(phase_time*.6)*.08,cos(phase_time*.8)*.25)
	var camera: Camera3D = game.player.get_view_camera()
	var facing := Basis.looking_at(view.target-center,Vector3.UP)
	game.player.position = center - Vector3.UP*1.6
	camera.global_transform = Transform3D(facing,center)
	game.health = 100.0
	game.vr_label.visible = true
	game.ui_layer.visible = false
	var wanted := 1 if phase_time >= warmup + duration*0.5 else 0
	if game.weapon.selected != wanted:
		game.weapon.reset_weapon()
		game.weapon.select_weapon(wanted)
	var weapon_id: String = game.weapon.active_id
	if not weapons_seen.has(weapon_id): weapons_seen.append(weapon_id)
	var capture_key := str(view.name) + "-" + weapon_id
	if not logic_only and phase_time > warmup + (duration*0.5 + 0.5 if wanted == 1 else 0.5) and not captures.has(capture_key):
		captures[capture_key] = {"pending":true}
		_capture_eyes(capture_key)
	next_shot -= delta
	if next_shot <= 0.0:
		if game.weapon.ammo == 0: game.weapon.reset_weapon()
		else: game.weapon.fire()
		next_shot = 0.4 if wanted == 0 else 0.65
	var count_before := samples.size()
	super._process(delta)
	if samples.size() > count_before:
		# Reservoir-free per-weapon subset is bounded by the 27-second run.
		var measured: Dictionary = samples[-1].duplicate()
		measured["weapon"] = weapon_id
		weapon_samples[weapon_id].append(measured)

func _capture_eyes(key: String) -> void:
	await RenderingServer.frame_post_draw
	var paths: Array[String] = []
	for side in range(2):
		var path := output.get_basename() + "-" + key + ("-left.png" if side == 0 else "-right.png")
		var error := eyes[side].get_texture().get_image().save_png(path)
		if error == OK: paths.append(path)
	var active = game.weapon.weapons[game.weapon.selected]
	captures[key] = {"paths":paths,"hud_visible_in_tree":game.vr_label.is_visible_in_tree(),"weapon_visible_in_tree":active.is_visible_in_tree(),"hud_origin_in_eye_frusta":[cameras[0].is_position_in_frustum(game.vr_label.global_position),cameras[1].is_position_in_frustum(game.vr_label.global_position)],"weapon_model_origin_in_eye_frusta":[cameras[0].is_position_in_frustum(active.model.global_position),cameras[1].is_position_in_frustum(active.model.global_position)]}

func _finish() -> void:
	# Do not invoke main's quit helper: the benchmark owns the result and code.
	game.set_process(false)
	game.set_physics_process(false)
	game.music.shutdown()
	game.weapon.shutdown()
	_stop_audio(game)
	await super._finish()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output))
	data["dynamic_fixture"]["includes_weapon_or_campaign_ui"] = true
	data["full_game_fixture"] = {"main_scene":"res://main.tscn","weapon_rack":true,"weapons_seen":weapons_seen,"hud":"actual production Label3D HUD; desktop CanvasLayer hidden","ai_and_target_durable":true,"automatic_weapon_refill":true,"per_weapon_samples":weapon_samples,"weapon_sample_seconds_per_view":duration*0.5}
	data["full_game_fixture"]["eye_captures"] = captures
	data["full_game_fixture"]["shots_emitted"] = shot_counts
	data["limits"] = "Actual campaign main scene, world, eight active production AI, six48body-cap wrecks, real Kestrel/Cinder models/fire/effects and spatial Label3D HUD rendered through two independent eye cameras. Synthetic durable actors and auto-refill preserve workload. Excludes OpenXR multiview/runtime/compositor/Link and physical tracking. Weapon uses desktop positioning, not tracked-hand pose. Not headset frame time or FPS."
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t"));file.close()
