extends SceneTree
const Enemy = preload("res://scripts/enemy.gd")
class Target extends CharacterBody3D:
	var exposure_provider: Node
var target: Target
var hits := 0
var damage := 0.0
var failures := 0
func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1
func box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	b.position = pos
	root.add_child(b)
	return b
func scenario(level: float, mode: String) -> Dictionary:
	seed(731)
	target.position = Vector3.ZERO
	var e := Enemy.new()
	e.setup(target, 0)
	e.position = Vector3(0, 0, 12)
	root.add_child(e)
	e.set_physics_process(false)
	e.set_difficulty(level)
	e.set_guard_heading(Vector3.FORWARD)
	e.hit_player.connect(func(amount): hits += 1; damage += amount)
	hits = 0
	damage = 0.0
	var shots := 0
	var first_shot := -1.0
	var dodge_start := Vector3.ZERO
	var wall: StaticBody3D
	if mode == "cover": wall = box(Vector3(0, 2, 5), Vector3(80, 4, 1))
	await physics_frame
	for i in range(2700):
		var prev = e.state
		if mode == "cover_late" and e.state == Enemy.State.WINDUP and not is_instance_valid(wall):
			wall = box(Vector3(0, 2, 5), Vector3(80, 4, 1))
			await physics_frame
		if mode in ["reactive", "reactive_fast"] and e.state == Enemy.State.WINDUP:
			# 250ms response after lock; physical 3m/s lateral movement.
			if e.state_time < e._reaction_duration() - e._dodge_window() + (0.12 if mode == "reactive_fast" else 0.25):
				dodge_start = target.position
			else:
				var side := -1.0 if dodge_start.x > 0 else 1.0
				target.position.x += side * 3.0 / 90.0
		e._physics_process(1.0 / 90.0)
		if prev == Enemy.State.WINDUP and e.state == Enemy.State.RECOVER:
			shots += 1
			if first_shot < 0: first_shot = float(i) / 90.0
		await physics_frame
	var result := {"difficulty":level,"mode":mode,"shots":shots,"hits":hits,"damage":damage,"first_shot":first_shot,"healthmax":e.healthmax}
	e._voice.stop()
	e._impact_voice.stop()
	e._voice.stream = null
	e._impact_voice.stream = null
	# Fixed-fps timers advance simulation faster than the audio mixer wall clock.
	OS.delay_msec(100)
	await create_timer(0.1).timeout
	e.queue_free()
	if is_instance_valid(wall): wall.queue_free()
	await process_frame
	OS.delay_msec(100)
	await process_frame
	return result
func run():
	target = Target.new()
	root.add_child(target)
	box(Vector3(0,-0.5,0),Vector3(200,1,200))
	await physics_frame
	var normal = await scenario(0.5,"stationary")
	var hard = await scenario(1.0,"stationary")
	var normal_move = await scenario(0.5,"reactive")
	var hard_move = await scenario(1.0,"reactive")
	var cover = await scenario(1.0,"cover")
	var fast = await scenario(1.0,"reactive_fast")
	var late = await scenario(1.0,"cover_late")
	for result in [normal,hard,normal_move,hard_move,cover,fast,late]: print("RUNTIME ",JSON.stringify(result))
	check(hard.shots >= normal.shots * 1.5,"upper difficulty produces >=50% more actual shots")
	check(hard.damage >= normal.damage * 1.5,"stationary actual damage pressure increases >=50%")
	check(hard.first_shot < normal.first_shot,"hard acquires/reacts sooner in actual fight")
	check(normal_move.hits == 0 and hard_move.hits > 0,"250ms late response evades normal but is punished on hard")
	check(cover.hits == 0 and cover.shots == 0,"solid cover prevents acquisition and all damage")
	check(fast.shots > 0 and fast.hits == 0,"120ms reaction at 3m/s still defeats challenging locked aim")
	check(late.shots > 0 and late.hits == 0,"cover entered during windup blocks an already acquired attack")
	check(hard.healthmax == normal.healthmax,"difficulty never inflates enemy HP")
	for child in root.get_children(): child.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	Enemy._sound_bank.clear()
	Enemy.AudioBank._cache.clear()
	await create_timer(0.1).timeout
	OS.delay_msec(100)
	await process_frame
	print("DIFFICULTY_038 failures=", failures)
	quit(0 if failures == 0 else 1)




