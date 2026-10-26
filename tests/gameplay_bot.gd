extends "res://scripts/main.gd"
## Synthetic aim/locomotion harness: no teleport, invulnerability or kill injection.
## Uses actual collision sweeps, reload FSM, shot signal raycast and enemy AI.
var bot_time := 0.0
var sample_time := 0.0
var reload_timer := 0.0
var route_index := 0
var previous_chapter := 0
var stuck_time := 0.0
var last_position := Vector3.ZERO
var travelled := 0.0
var bot_shots := 0
var bot_reloads := 0
var bot_deaths := 0
var was_dead := false
var frame_times: Array[float] = []
var climbing_seconds := 0.0
var stairs_only := false
var mixed_weapons := false
var weapon_switches := 0
var weapon_shots := {"kestrel":0,"cinder":0}
var weapon_rounds_consumed := {"kestrel":0,"cinder":0}
var weapon_reload_completions := {"kestrel":0,"cinder":0}
var source_hashes: Dictionary = {}
var captures: Dictionary = {}
var bot_gpu_samples: Array[float] = []
var routes: Array = [
	[Vector3(0,0,0), Vector3(0,1,-14), Vector3(4,1,-16), Vector3(8,0,-24), Vector3(-10,0,-28), Vector3(0,1,-15)],
	[Vector3(8,1,-14), Vector3(8,0,-28), Vector3(-18,0,-35.8), Vector3(-18,8,-38), Vector3(-18,8,-43), Vector3(-24,8,-43), Vector3(-24,8,-47), Vector3(-18,8,-43)],
	[Vector3(-11.4,8,-43), Vector3(-11.4,8,-47), Vector3(6,8,-47), Vector3(6,12,-60.5), Vector3(6,12,-63.3), Vector3(2.5,12,-63.3), Vector3(2.5,16,-50.5), Vector3(8,16,-50.5), Vector3(8,16,-62), Vector3(15,16,-69)],
	[Vector3(15,16,-61), Vector3(0,0,10), Vector3(0,0.2,15)]
]

func _ready() -> void:
	for script_name in ["main", "player", "weapon", "world", "enemy", "menu", "ambience"]:
		source_hashes[script_name + ".gd"] = FileAccess.get_sha256("res://scripts/" + script_name + ".gd")
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		push_error("Bot needs isolated APPDATA")
		get_tree().quit(2)
		return
	super._ready()
	if not is_instance_valid(player) or not is_instance_valid(world):
		set_process(false)
		set_physics_process(false)
		get_tree().quit(2)
		return
	stairs_only = "--stairs" in OS.get_cmdline_user_args()
	mixed_weapons = "--mixed-weapons" in OS.get_cmdline_user_args()
	if stairs_only:
		routes[1] = [Vector3(8,1,-14), Vector3(8,0,-24.5), Vector3(-29,0,-24.5), Vector3(-29,0,-27.5), Vector3(-29,4,-41.5), Vector3(-29,4,-44.2), Vector3(-25,4,-44.2), Vector3(-25,8,-31.5), Vector3(-20.7,8,-30.4), Vector3(-20.7,8,-38), Vector3(-18,8,-43)]
		routes[2] = [Vector3(-11.4,8,-43), Vector3(-11.4,8,-47), Vector3(6,8,-47), Vector3(6,12,-60.5), Vector3(6,12,-63.3), Vector3(2.5,12,-63.3), Vector3(2.5,16,-50.5), Vector3(8,16,-50.5), Vector3(8,16,-62), Vector3(15,16,-69)]
	# Keep automated acceptance independent of previous menu/save tests.
	field_menu.difficulty = 1.0 if "--hard" in OS.get_cmdline_user_args() else 0.5
	new_campaign()
	player.set_physics_process(false)
	last_position = player.global_position
	weapon.shot.connect(func(_a,_b,_c):
		bot_shots += 1
		weapon_shots.kestrel += 1)
	weapon.pellet_shot.connect(func(_a,_b,_c):
		bot_shots += 1
		weapon_shots.cinder += 1)
	print("BOT_START no_teleport=true actual_damage=true synthetic_aim=true")

func _process(delta):
	if not is_instance_valid(player): return
	super._process(delta)
	frame_times.append(delta * 1000)
	if not gpu_samples.is_empty(): bot_gpu_samples.append(gpu_samples.back())
	if bot_time > 2 and not captures.has("start"): _capture_bot_frame("start")
	if chapter == 2 and not captures.has("mid"): _capture_bot_frame("mid")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	bot_time += delta
	sample_time += delta
	reload_timer -= delta
	var displacement: float = player.global_position.distance_to(last_position)
	travelled += displacement
	last_position = player.global_position
	if dead and not was_dead:
		bot_deaths += 1
		print("BOT_DEATH t=", bot_time, " position=", player.global_position)
	was_dead = dead
	if complete or bot_time >= bot_time_limit():
		finish_bot()
		return
	if dead: return
	if chapter != previous_chapter:
		previous_chapter = chapter
		route_index = 0
	# The west-flank patrol waypoints are only needed to expose surviving
	# enemies. Once clear, walk directly to the relay on this roof.
	if chapter == 1 and not stairs_only and route_index >= 4 and enemies.is_empty():
		route_index = routes[1].size() - 1
	var route: Array = routes[mini(chapter,routes.size()-1)]
	var goal: Vector3 = route[mini(route_index, route.size()-1)]
	var horizontal: Vector3 = (goal - player.global_position) * Vector3(1,0,1)
	if horizontal.length() < 0.9 and absf(goal.y-player.global_position.y) < 2.2 and route_index < route.size()-1:
		route_index += 1
		print("BOT_WAYPOINT t=", snappedf(bot_time,0.1), " chapter=", chapter, " index=", route_index, " pos=", player.global_position)
	var direction: Vector3 = horizontal.normalized()
	var cam: Camera3D = player.get_view_camera()
	if direction.length_squared() > 0.01:
		cam.look_at(cam.global_position + direction)
	if displacement < 0.008 and horizontal.length() > 1:
		stuck_time += delta
	else:
		stuck_time = maxf(0, stuck_time-delta*0.2)
	if bot_should_glide() and not player.is_on_floor() and player.velocity.y < 1:
		player._desktop_glide = true
		player._physics_process(delta)
	elif player.mantling:
		player._step_mantle(delta)
	elif (stuck_time > 0.35 or not player._grabs.is_empty()) and not stairs_only:
		var start: Vector3 = player.global_position + Vector3.UP * 1.1
		var query := PhysicsRayQueryParameters3D.create(start, start + direction * 1.35, 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not player._grabs.is_empty() or (not hit.is_empty() and absf(hit.normal.y) < 0.75):
			player._grabs[cam] = cam.global_position
			if not player.try_start_mantle():
				player.apply_climb_motion(Vector3.UP * 2.2 * delta, delta)
				climbing_seconds += delta
		else:
			walk_step(direction, delta)
	else:
		walk_step(direction, delta)
	# Aim only when actual raycast reaches a living target; walls stop shots.
	var chosen = null
	var closest := 1000.0
	for enemy in bot_targets():
		if not is_instance_valid(enemy): continue
		var aim: Vector3 = enemy.global_position + Vector3.UP * 1.1
		var query := PhysicsRayQueryParameters3D.create(cam.global_position, aim, 5, [player.get_rid()])
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		var distance: float = cam.global_position.distance_to(aim)
		if not result.is_empty() and result.collider == enemy and distance < closest:
			chosen = enemy
			closest = distance
	if chosen != null:
		cam.look_at(chosen.global_position + Vector3.UP * 1.1)
		if mixed_weapons:
			var requested: int = 1 if closest < 12 else (0 if closest > 18 else weapon.selected)
			if weapon.select_weapon(requested): weapon_switches += 1
		var before_ammo: int = weapon.ammo
		var fired_id: String = weapon.active_id
		weapon.fire()
		weapon_rounds_consumed[fired_id] += maxi(0,before_ammo-weapon.ammo)
	if weapon.ammo == 0 or weapon.reload_state != "ready":
		if reload_timer <= 0:
			if weapon.reload_state == "ready": bot_reloads += 1
			var reload_id: String = weapon.active_id
			var previous_state: String = weapon.reload_state
			weapon.desktop_reload_step()
			if previous_state != "ready" and weapon.reload_state == "ready": weapon_reload_completions[reload_id] += 1
			reload_timer = 0.22
	_activate_objective()
	if sample_time >= 10:
		sample_time = 0
		print("BOT_SAMPLE t=", int(bot_time), " chapter=", chapter, " route=", route_index, " pos=", player.global_position, " enemies=", enemies.size(), " hp=", health, " shots=", bot_shots, " kills=", total_kills, " stuck=", snappedf(stuck_time,0.1))
		if enemies.size() == 1: print("BOT_REMAINING_ENEMY ", enemies[0].global_position)

func bot_targets() -> Array:
	return enemies

func bot_should_glide() -> bool:
	return chapter == 3

func bot_time_limit() -> float:
	return 180.0 if mixed_weapons else 120.0

func bot_report_suffix() -> String:
	return ""

func bot_extra_report() -> Dictionary:
	return {}

func walk_step(direction: Vector3, delta: float) -> void:
	player._grabs.clear()
	player.velocity.x = direction.x * 4.2
	player.velocity.z = direction.z * 4.2
	player.velocity.y -= 18 * delta
	player.move_and_slide()

func finish_bot() -> void:
	set_physics_process(false)
	await _capture_bot_frame("end")
	frame_times.sort()
	var sum := 0.0
	for value in frame_times: sum += value
	var report := {"elapsed":bot_time,"chapter":chapter,"complete":complete,"kills":total_kills,"shots":bot_shots,"reloads":bot_reloads,"deaths":bot_deaths,"travelled_metres":travelled,"climbing_seconds":climbing_seconds,"position":str(player.global_position),"desktop_frame_mean_ms":sum/maxi(1,frame_times.size()),"desktop_frame_p95_ms":frame_times[int(frame_times.size()*.95)] if not frame_times.is_empty() else 0,"headset_tested":false,"synthetic_aim":true,"movement":"capsule sweep, climb/mantle production methods; synthetic velocity steering"}
	report["display_server"] = DisplayServer.get_name()
	report["rendering_device"] = RenderingServer.get_video_adapter_name()
	report["stairs_only"] = stairs_only
	report["difficulty"] = field_menu.difficulty
	report["mixed_weapons"] = mixed_weapons
	report["weapon_switches"] = weapon_switches
	report["weapon_shots"] = weapon_shots
	report["weapon_rounds_consumed"] = weapon_rounds_consumed
	report["weapon_reload_completions"] = weapon_reload_completions
	report["timing_note"] = "Process interval only; fixed-fps/headless values are simulated, not performance. Native values do not measure GPU or headset timing."
	report["source_sha256"] = source_hashes
	bot_gpu_samples.sort()
	report["viewport_gpu_sample_count"] = bot_gpu_samples.size()
	if not bot_gpu_samples.is_empty():
		report["viewport_gpu_median_ms"] = bot_gpu_samples[int(bot_gpu_samples.size()*0.5)]
		report["viewport_gpu_p95_ms"] = bot_gpu_samples[mini(bot_gpu_samples.size()-1,int(bot_gpu_samples.size()*0.95))]
	report["viewport_size"] = str(get_viewport().size)
	report["gpu_timing_scope"] = "Godot viewport measured GPU render duration; excludes Quest compositor/Link encoding and is not headset performance."
	report["utc"] = Time.get_datetime_string_from_system(true)
	report.merge(bot_extra_report())
	print("BOT_RESULT ", JSON.stringify(report))
	var report_name := "bot-" + ("headless" if DisplayServer.get_name() == "headless" else "native") + ("-stairs" if stairs_only else "-climb") + ("-mixed" if mixed_weapons else "") + bot_report_suffix() + ".json"
	var file := FileAccess.open("res://../reports/QA/" + report_name, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"\t"))
	# Optional post-run art inspection camera; never changes player position
	# or contributes to route completion, distance, combat or timing evidence.
	if DisplayServer.get_name() != "headless" and "--gallery-capture" in OS.get_cmdline_user_args():
		var review_camera: Camera3D = player.get_view_camera()
		var saved_camera := review_camera.global_transform
		review_camera.global_position = Vector3(10.5, 2.2, -28)
		review_camera.look_at(Vector3(20, 2.6, -39))
		await _capture_bot_frame("gallery-staged-camera")
		review_camera.global_transform = saved_camera
	await _quit_game(0, "test_complete")

func _capture_bot_frame(label: String) -> void:
	captures[label] = true
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var filename := "res://../reports/QA/bot-" + ("stairs" if stairs_only else "climb") + ("-mixed" if mixed_weapons else "") + bot_report_suffix() + "-" + label + ".png"
	image.save_png(filename)
	print("BOT_CAPTURE ", filename)

