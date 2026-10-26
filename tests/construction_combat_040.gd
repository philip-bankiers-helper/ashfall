extends SceneTree
const Builder = preload("res://scripts/field_builder.gd")
const Enemy = preload("res://scripts/enemy.gd")
var passed := 0
var failed := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		printerr("FAIL ",label)
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var builder := Builder.new()
	builder.max_debris = 6
	scene.add_child(builder)
	builder.setup(null,null,null)
	await physics_frame
	for kind in range(3):
		builder.piece_index = kind
		builder._set_piece()
		builder._placement = Transform3D(Basis.IDENTITY,Vector3(kind * 4,2,0))
		builder.preview_valid = true
		builder._commit()
	await physics_frame
	await physics_frame
	check(builder.pieces.size() == 3 and builder.charges == 3,"three shapes consume supply")
	var health_values := [180.0,160.0,140.0]
	for kind in range(3):
		var piece: StaticBody3D = builder.pieces[0]
		check(piece.health == health_values[kind],"shape health tunable %d" % kind)
		var ray_y := 0.0 if kind == 2 else 0.2
		var from: Vector3 = piece.global_position + Vector3(0,ray_y,4)
		var to: Vector3 = piece.global_position + Vector3(0,ray_y,-4)
		var query := PhysicsRayQueryParameters3D.create(from,to,1)
		var collision := scene.get_world_3d().direct_space_state.intersect_ray(query)
		check(not collision.is_empty() and collision.collider == piece,"live construction blocks ballistic ray %d" % kind)
		piece.hit(-100.0)
		piece.hit(INF)
		check(piece.health == health_values[kind],"invalid damage cannot heal or destroy %d" % kind)
		piece.hit(30.0,from,Vector3.FORWARD)
		check(piece.health == health_values[kind] - 30.0 and piece.collision_layer == 1,"nonlethal bullet preserves physical cover %d" % kind)
		piece.hit(1000.0,to,Vector3.BACK)
		check(piece.broken and piece.collision_layer == 0 and not piece.is_in_group("climbable"),"lethal hit immediately disables cover %d" % kind)
		piece.hit(1000.0)
		check(builder.pieces.size() == 2 - kind,"destroy event removes live capacity once %d" % kind)
		await physics_frame
		await physics_frame
		check(scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"destroyed construction passes bullets %d" % kind)
	check(builder.charges == 3,"destruction never refunds construction")
	builder.charges = 9
	check(builder.award_supply("guard-1",2) == 2 and builder.charges == 11,"unique defeated guard grants bounded supply")
	check(builder.award_supply("guard-1",2) == 0 and builder.charges == 11,"duplicate guard reward cannot farm")
	check(builder.award_supply("guard-2",5) == 1 and builder.charges == 12,"supply saturates at cap")
	builder.charges = 7
	check(builder.award_supply("guard-2",5) == 0,"cap-discarded reward cannot be reclaimed later")
	check(builder.award_supply("",5) == 0 and builder.award_supply("bad",-2) == 0,"invalid reward refused")
	check(builder._debris.size() <= builder.max_debris,"cosmetic shards remain bounded")
	await create_timer(0.8).timeout
	check(builder._debris.is_empty(),"destruction shards expire without physics or persistent nodes")
	builder.preview_valid = true
	builder._commit()
	check(builder.pieces.size() == 1,"destroyed piece frees capacity for replacement")
	builder.reset_builds()
	check(builder.pieces.is_empty() and builder.charges == 6 and builder._debris.is_empty(),"encounter reset clears cover and debris and restores supply")
	builder.charges = 8
	check(builder.award_supply("guard-1",2) == 2,"new encounter permits fresh enemy identity")
	builder.piece_index = 0
	builder._set_piece()
	builder._placement = Transform3D(Basis.IDENTITY,Vector3(0,1.4,-4))
	builder.preview_valid = true
	builder._commit()
	var panel: StaticBody3D = builder.pieces[0]
	var shooter := Enemy.new()
	scene.add_child(shooter)
	shooter.set_physics_process(false)
	shooter.locked_aim = Vector3(0,1.4,-8)
	var player_damage := [0.0]
	shooter.hit_player.connect(func(amount): player_damage[0] += amount)
	await physics_frame
	await physics_frame
	for shot in range(7):
		shooter._fire(shooter.locked_aim)
	check(panel.health == 12.0 and player_damage[0] == 0.0,"seven actual enemy discharges wear wall to12HP without target damage")
	shooter._fire(shooter.locked_aim)
	check(panel.broken and player_damage[0] == 0.0,"eighth enemy discharge destroys180HP wall and is absorbed")
	await physics_frame
	await physics_frame
	shooter._fire(shooter.locked_aim)
	check(player_damage[0] == 12.0,"ninth enemy discharge damages now exposed player")
	await physics_frame
	await physics_frame
	print("CONSTRUCTION_COMBAT_040_RESULT ",passed," passed ",failed," failed")
	scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(1 if failed else 0)
