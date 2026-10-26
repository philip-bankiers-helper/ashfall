extends SceneTree
const Enemy = preload("res://scripts/enemy.gd")
const Doll = preload("res://scripts/ragdoll.gd")
class Cover extends StaticBody3D:
	var health := 24.0
	var hits := 0
	func hit(amount: float, _point: Vector3, _direction: Vector3):
		health -= amount
		hits += 1
		if health <= 0: collision_layer = 0
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ", label)
func run():
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	floor.add_child(shape)
	world.add_child(floor)
	floor.position.y = -0.5
	for variant in [0, 2, 1, 3]:
		var enemy = Enemy.new()
		enemy.variant = variant
		world.add_child(enemy)
		enemy.set_physics_process(false)
		check(enemy.health > 0 and enemy.state != Enemy.State.DEAD, "variant %d starts alive" % variant)
		if variant in [0, 2]:
			var visual = enemy._detail_visual
			check(visual != null and visual.skeleton.get_bone_count() > 20, "ground detailed skeleton present")
			check(visual.source_meshes.size() > 0, "licensed visible mesh present")
			visual.update_pose(0.1, true, true, 0.1, 0.2)
			check(visual.model.global_transform.is_finite(), "animated aimed pose finite")
		else:
			check(enemy._visual.find_child("DroneIndustrialDetail", true, false) != null, "flying detail fittings present")
		enemy.set_difficulty(0.5)
		var normal_reaction: float = enemy._reaction_duration()
		var normal_pressure: float = enemy._pressure_scale()
		enemy.set_difficulty(1.0)
		check(enemy._pressure_scale() > normal_pressure and enemy._reaction_duration() < normal_reaction, "038 hard difficulty pressure preserved")
		check(is_equal_approx(enemy._pressure_scale(), 2.35) and is_equal_approx(enemy._reaction_duration(), 0.56), "038 exact pressure and reaction retained")
		var previous_health: float = enemy.health
		enemy.take_damage(5.0)
		check(enemy.health < previous_health, "actual hit path damages variant")
		enemy._die()
		check(enemy.state == Enemy.State.DEAD and enemy.collision_layer == 0 and not enemy._visual.visible, "death removes live combat body")
		var corpse = get_nodes_in_group("ragdolls")[-1]
		check(corpse.bodies.size() == (8 if variant in [0,2] else 6), "actual death creates bounded rigid anatomy")
		if variant in [0,2]:
			var skin = corpse.get_node_or_null("ContinuousCorpseSkin")
			check(skin != null and skin.skeleton.get_bone_count() > 20, "continuous skinned corpse replaces live visual")
			for frame in range(45): await physics_frame
			check(corpse.bodies[0].global_position.is_finite() and skin.skeleton.global_transform.is_finite(), "physics-driven detailed corpse remains finite")
		corpse.set_paused(true)
		check(corpse.bodies[0].freeze, "corpse obeys menu pause")
		corpse.set_paused(false)
		Doll.clear_all(world)
		await process_frame
		check(get_nodes_in_group("ragdolls").is_empty(), "chapter cleanup clears detailed corpse")
		enemy.queue_free()
		await process_frame
	var shooter = Enemy.new()
	world.add_child(shooter)
	shooter.set_physics_process(false)
	shooter.locked_aim = Vector3(0,1.4,-8)
	var cover := Cover.new()
	cover.add_to_group("field_construction")
	var panel := CollisionShape3D.new()
	var panel_box := BoxShape3D.new()
	panel_box.size = Vector3(2,3,0.2)
	panel.shape = panel_box
	cover.add_child(panel)
	world.add_child(cover)
	cover.position = Vector3(0,1.4,-4)
	var player_damage := [0.0]
	shooter.hit_player.connect(func(amount): player_damage[0] += amount)
	await physics_frame
	await physics_frame
	shooter._fire(shooter.locked_aim)
	check(cover.hits == 1 and cover.health == 0.0, "actual enemy discharge damages and destroys construction once")
	check(player_damage[0] == 0.0, "destroyed cover still absorbs destruction shot")
	await physics_frame
	shooter._fire(shooter.locked_aim)
	check(player_damage[0] == 12.0, "later discharge reaches exposed target after panel destroyed")
	world.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("DETAILED_ENEMIES_040 checks=", checks, " failures=", failures, " headset_tested=false")
	quit(failures)
