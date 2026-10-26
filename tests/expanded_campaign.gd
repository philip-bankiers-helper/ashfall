extends "res://tests/integration.gd"
func freeze_combat(main):
	main.set_process(false)
	main.player.set_physics_process(false)
	for enemy in main.enemies: enemy.set_physics_process(false)
func run():
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		quit(2)
		return
	var legacy_hash := FileAccess.get_sha256("user://campaign.json") if FileAccess.file_exists("user://campaign.json") else "missing"
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	check(main.extended_campaign and main.missions.size()==6, "opt-in expanded campaign exposes six missions")
	main.new_campaign()
	freeze_combat(main)
	for index in [3,4]:
		main.chapter=index
		main._begin_chapter()
		freeze_combat(main)
		check(main._save_progress(), "mission entry checkpoint writes " + main.mission_id())
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://campaign-expanded.json"))
		check(saved.mission_id==main.mission_id() and saved.campaign_id=="ashfall-expanded-v1", "checkpoint stores authoritative mission identity")
		if index==3: main.interference_units[0].take_damage(1000)
		else:
			main.player.global_position=main.campaign_extension.isolator_position
			main._activate_objective()
			check(main.spillway_gate.is_open and main.chapter==4, "isolator interaction opens gate without requiring guard deaths")
		main.health=12
		main.player.velocity=Vector3(2,3,4)
		check(main.load_checkpoint(), "checkpoint load succeeds for new mission")
		freeze_combat(main)
		check(main.chapter==index and main.health==100 and main.player.velocity==Vector3.ZERO, "load restores mission health and motion")
		check(main.player.global_position.is_equal_approx(main.campaign_extension.safe_spawns[index-3]), "load uses authored safe entry spawn")
		check(main.interference_units.all(func(u):return not u.is_disabled) if index==3 else not main.spillway_gate.is_open, "load resets partial jammer or gate progress")
		if index==3: main.interference_units[0].take_damage(1000)
		else: main.spillway_gate.activate()
		main._damage_player(1000)
		check(main.dead, "lethal damage starts actual deferred recovery")
		await create_timer(2.7).timeout
		freeze_combat(main)
		check(not main.dead and main.health==100 and main.chapter==index, "actual death timer restores same new mission")
		check(main.interference_units.all(func(u):return not u.is_disabled) if index==3 else not main.spillway_gate.is_open, "death resets objective partial state")
	# Actual grouped ray hits: last jammer resolves before a guard in the same
	# discharge. Mission transition must retire that guard before damage applies.
	main.chapter=3
	main._begin_chapter()
	freeze_combat(main)
	main.interference_units[0].take_damage(1000)
	var final_unit = main.interference_units[1]
	var volley_guard = main.enemies[0]
	final_unit.global_position=Vector3(1000,10,-5)
	volley_guard.global_position=Vector3(1002,10,-5)
	await physics_frame
	await physics_frame
	var volley_origin := Vector3(1000,11.1,0)
	var rays: Array[Vector3] = [(final_unit.global_position+Vector3.UP*1.1-volley_origin).normalized(),(volley_guard.global_position+Vector3.UP*1.1-volley_origin).normalized()]
	var space = main.get_world_3d().direct_space_state
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(volley_origin,volley_origin+rays[0]*10,5)).get("collider")==final_unit and space.intersect_ray(PhysicsRayQueryParameters3D.create(volley_origin,volley_origin+rays[1]*10,5)).get("collider")==volley_guard, "same volley fixture rays physically hit final jammer then guard")
	var before_guard_health: float=volley_guard.health
	var before_score: int=main.total_kills
	var before_corpses: int=get_nodes_in_group("ragdolls").size()
	main._on_pellet_shot(volley_origin,rays,1000)
	check(main.chapter==4 and volley_guard.is_queued_for_deletion(), "final jammer pellet advances and queues surviving guard retirement")
	check(volley_guard.health==before_guard_health and main.total_kills==before_score and get_nodes_in_group("ragdolls").size()==before_corpses, "later pellet group cannot damage retired guard or mint ghost corpse/kill")
	await process_frame
	check(not is_instance_valid(volley_guard), "retired same-volley guard is actually deleted")
	final_unit.position=main.campaign_extension.jammer_positions[1]
	main.chapter=3
	main._begin_chapter()
	freeze_combat(main)
	var old_enemies: Array=main.enemies.duplicate()
	var kills: int=main.total_kills
	main.interference_units[0].take_damage(1000)
	check(main.chapter==3, "single jammer insufficient")
	main.toast_time=0
	main._process(0)
	check(main._compact_status("", "", "").contains("SHOOT 1 CORE") and main.hud.text.is_empty() and main.vr_label.text.is_empty(), "remaining sabotage objective is retained internally without persistent HUD text")
	main.interference_units[1].take_damage(1000)
	check(main.chapter==4 and main.total_kills==kills, "both jammers advance with surviving guards without awarded kills")
	check(old_enemies.all(func(e):return e.collision_layer==0 and e.collision_mask==0 and not e.is_physics_processing()), "outgoing guards immediately lose combat collision and processing")
	check(old_enemies.all(func(e):return e.defeated.get_connections().is_empty() and e.hit_player.get_connections().is_empty()), "outgoing guard signals disconnected before deferred deletion")
	freeze_combat(main)
	main.player.global_position=main.campaign_extension.exit_position
	main._check_spillway_exit()
	check(main.chapter==4, "closed gate prevents positional escape advancement")
	main.player.global_position=main.campaign_extension.isolator_position+Vector3(10,0,0)
	main._activate_objective()
	check(not main.spillway_gate.is_open, "remote isolator activation rejected")
	main.player.global_position=main.campaign_extension.isolator_position
	main.field_menu.set_open(true)
	main._activate_objective()
	check(not main.spillway_gate.is_open, "open menu blocks isolator interaction")
	main.field_menu.set_open(false)
	main._process(.01)
	freeze_combat(main)
	main._activate_objective()
	check(main.spillway_gate.is_open and main.chapter==4, "nearby active interaction opens physical gate")
	main.toast_time=0
	main._caption_source=""
	main.radio_time=17
	main._process(.1)
	check(main._objective_label()=="EXIT" and main.hud.text.is_empty() and main.waypoint.text.contains("EXIT"), "opened spillway waypoint identifies exit without persistent status text")
	var caption_clock: float=main._caption_clock
	main.weapon.weapons[0].reload_state="needs_rack"
	main._process(.5)
	check(not main.vr_cue.text.contains("rack the bolt") and main._caption_clock>caption_clock, "reload shows no instruction and no longer pauses accessible story captions")
	main.weapon.weapons[0].reload_state="ready"
	for tick in range(40): main._process(1.0)
	check(not main._caption_pending and not main.training_label.visible and main.waypoint.text.contains("EXIT"), "radio pages drain while exit waypoint persists and verbose training stays hidden")
	main.player.global_position=main.campaign_extension.exit_position+Vector3(0,3,0)
	main._check_spillway_exit()
	check(main.chapter==4, "passing above gate escape box does not advance")
	main.player.global_position=main.campaign_extension.exit_position
	main.paused=true
	main._check_spillway_exit()
	check(main.chapter==4, "paused exit does not advance")
	main.paused=false
	old_enemies=main.enemies.duplicate()
	main._check_spillway_exit()
	check(main.chapter==5 and main.total_kills==kills and old_enemies.size()==4, "positional escape advances with all guards alive and no despawn score")
	check(main.enemies.size()==6 and main.enemies.back().variant==3, "expanded extraction retains Warden encounter")
	main._respawn()
	freeze_combat(main)
	var expected_spawn: Vector3=main.campaign_extension.exit_position+Vector3(0,.4,-.5)
	check(main.player.global_position.is_equal_approx(expected_spawn), "expanded extraction respawns at spillway exit rather than old uplink")
	for tick in range(45):
		await physics_frame
		main.player.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,1.0/60.0)
	check(main.player.is_supported() and main.player.global_position.y>5.9 and main.player.global_position.y<6.1, "actual head-only locomotion settles standing on extraction checkpoint return deck")
	main.new_campaign()
	freeze_combat(main)
	check(main.chapter==0 and not main.spillway_gate.is_open and main.total_kills==0, "expanded new campaign resets gate score and chapter")
	var legacy_after := FileAccess.get_sha256("user://campaign.json") if FileAccess.file_exists("user://campaign.json") else "missing"
	check(legacy_after==legacy_hash, "all expanded operations preserve legacy save bytes")
	main._stop_audio_tree(main)
	stop_audio(main)
	await create_timer(.2).timeout
	main.free()
	await process_frame
	print("EXPANDED_CAMPAIGN_RESULT passes=",passed," failures=",failures.size()," synthetic_logic=true headset_tested=false")
	quit(0 if failures.is_empty() else 1)

