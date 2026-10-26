extends SceneTree
const Enemy = preload("res://scripts/enemy.gd")
class Target extends CharacterBody3D:
	var exposure_provider: Node
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(value: bool,label: String):
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ",label)
func run():
	var world := preload("res://scripts/world.gd").new()
	root.add_child(world)
	world.build()
	var target := Target.new()
	root.add_child(target)
	await physics_frame
	for variant in range(4):
		var enemy := Enemy.new()
		enemy.setup(target,variant)
		root.add_child(enemy)
		enemy.position = Vector3(0,40,0)
		enemy.set_physics_process(false)
		enemy.set_guard_heading(Vector3.FORWARD)
		var range_value: float = enemy.engage_range()
		check(range_value >= (90 if variant==3 else 45),"variant meaningful expanded fire range")
		check(enemy.sight_range()>range_value,"perception range permits weapon acquisition")
		check(enemy._voice.max_distance>range_value,"warning audio reaches engagement distance")
		target.position = Vector3(0,40,-range_value+3)
		await physics_frame
		var aim := target.position+Vector3.UP*1.35
		for i in range(150): enemy._update_detection(aim,enemy.global_position.distance_to(target.position),.1)
		check(enemy._has_sight,"actual map airspace at expandedrange acquired through LOS")
		enemy.state = Enemy.State.PURSUE
		enemy.attack_cooldown = 0
		enemy._physics_process(.001)
		check(enemy.state==Enemy.State.WINDUP,"actual pursue gate enters firingwindup at expandedrange")
		var hits := [0]
		enemy.hit_player.connect(func(_amount):hits[0]+=1)
		enemy._warden_area = false
		enemy.locked_aim = aim
		enemy._fire(aim)
		check(hits[0]==1,"actualdischarge reaches expandedrange target")
		target.position = Vector3(0,40,-range_value-2)
		enemy.locked_aim = target.position+Vector3.UP*1.35
		enemy._fire(enemy.locked_aim)
		check(hits[0]==1,"discharge cannot exceed variantweaponrange")
		# Actual hydrodam spans this ray, even though it is within expandedrange.
		enemy.position = Vector3(0,10,-80)
		target.position = Vector3(0,10,-100)
		enemy.detection_level=0
		enemy.alert_memory=0
		await physics_frame
		aim = target.position+Vector3.UP*1.35
		for i in range(150): enemy._update_detection(aim,20,.1)
		check(not enemy._has_sight and not enemy._clear_line(aim),"actual dam occlusion still prevents acquisition")
		enemy.locked_aim=aim
		enemy._fire(aim)
		check(hits[0]==1,"actualdam blocks discharge at extendedweaponrange")
		enemy._voice.stop();enemy._impact_voice.stop()
		enemy.queue_free()
		await process_frame
	target.queue_free();world.queue_free()
	await process_frame
	Enemy._sound_bank.clear();Enemy.AudioBank._cache.clear()
	await create_timer(.15).timeout
	print("ENEMY_RANGE_040 checks=",checks," failures=",failures," headset_tested=false")
	quit(failures)
