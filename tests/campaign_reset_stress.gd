extends "res://tests/integration.gd"

func count_bodies(node: Node) -> int:
	var count := 1 if node is RigidBody3D else 0
	for child in node.get_children(): count += count_bodies(child)
	return count

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		quit(2)
		return
	var main = load("res://scripts/main.gd").new()
	root.add_child(main)
	main.new_campaign()
	await physics_frame
	await process_frame
	var baseline_nodes: int = main.find_children("*", "", true, false).size()
	var baseline_bodies := count_bodies(main)
	var peak_corpses := 0
	var peak_bodies := 0
	var peak_enemy_hosts := 0
	for cycle in range(30):
		for enemy in main.enemies: enemy.set_physics_process(false)
		for enemy in main.enemies.duplicate(): enemy.take_damage(10000)
		await physics_frame
		var corpses := get_nodes_in_group("ragdolls")
		var active_bodies := 0
		for corpse in corpses: active_bodies += corpse.bodies.size()
		peak_corpses = maxi(peak_corpses, corpses.size())
		peak_bodies = maxi(peak_bodies, active_bodies)
		check(corpses.size() == 4 and corpses.size() <= 6 and active_bodies <= 48, "cycle %d actual deaths create bounded physical corpses" % cycle)
		main.field_menu.set_open(true)
		main._process(0.01)
		var age: float = corpses[0].age
		for frame in range(3): await physics_frame
		check(corpses.all(func(c): return c._paused and c.bodies.all(func(b): return b.freeze)) and corpses[0].age == age, "cycle %d menu freezes corpse bodies and age" % cycle)
		main.field_menu.set_open(false)
		main._process(0.01)
		for frame in range(3): await physics_frame
		check(corpses[0].age > age and corpses.all(func(c): return not c._paused), "cycle %d resume advances real corpse physics" % cycle)
		match cycle % 3:
			0: main._respawn()
			1: main.new_campaign()
			2: check(main.load_checkpoint(), "cycle %d checkpoint recovery succeeds" % cycle)
		for frame in range(3): await physics_frame
		await process_frame
		var enemy_hosts: int = main.get_children().filter(func(n): return n is AshEnemy).size()
		peak_enemy_hosts = maxi(peak_enemy_hosts, enemy_hosts)
		print("RESET_CYCLE cycle=", cycle, " enemy_hosts=", enemy_hosts, " scene_nodes=", main.find_children("*", "", true, false).size())
		check(get_nodes_in_group("ragdolls").is_empty() and count_bodies(main) == baseline_bodies, "cycle %d cleanup restores baseline rigid body count" % cycle)
		check(main.find_children("*", "", true, false).size() == baseline_nodes and main.enemies.size() == 4, "cycle %d cleanup restores exact scene node and encounter counts" % cycle)
		check(main.health == 100 and not main.dead and main.weapon.ammo == main.weapon.magazine_size, "cycle %d recovery restores health and active weapon" % cycle)
	await create_timer(1.7).timeout
	check(main.find_children("*", "", true, false).size() == baseline_nodes, "after real death tween drain scene node count returns to baseline")
	print("RESET_STRESS_COUNTS cycles=30 peak_corpses=", peak_corpses, " peak_bodies=", peak_bodies, " peak_enemy_hosts=", peak_enemy_hosts, " baseline_nodes=", baseline_nodes, " baseline_bodies=", baseline_bodies)
	main._stop_audio_tree(main)
	stop_audio(main)
	await create_timer(0.2).timeout
	main.free()
	await process_frame
	print("CAMPAIGN_RESET_RESULT passes=",passed," failures=",failures.size()," synthetic=true headset_tested=false")
	quit(0 if failures.is_empty() else 1)

