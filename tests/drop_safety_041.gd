extends "res://tests/integration.gd"
var game
var inv
var fixtures:Array[Node]=[]
var changes:=0
func box(point:Vector3,size:Vector3,body:StaticBody3D=null)->StaticBody3D:
	if body==null:
		body=StaticBody3D.new(); game.add_child(body); fixtures.append(body)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;collision.position=point;body.add_child(collision)
	return body
func clear_fixture()->void:
	for body in fixtures: body.free()
	fixtures.clear()
func assert_safe_drop(label:String,expect_success:bool)->void:
	var ammo:int=game.weapon.weapons[0].ammo
	var reserves:Dictionary=game.weapon.reserves.duplicate(true)
	var count:int=inv.pickups.size()
	var before_changes:=changes
	var ok:bool=inv.drop_weapon(0)
	check(ok==expect_success,label+" drop result")
	if ok:
		var prop:Node3D=inv.pickups[0]
		var head:Vector3=game.player.get_view_camera().global_position
		var ray:=PhysicsRayQueryParameters3D.create(head,prop.global_position,1,[game.player.get_rid()]);ray.hit_from_inside=true
		check(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),label+" retrieval line clear")
		check(head.distance_to(prop.global_position)<=2.2,label+" within head reach bound")
		var bounds:AABB=inv._world_mesh_bounds(prop);var shape:=BoxShape3D.new();shape.size=bounds.size
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=bounds.get_center();query.exclude=[game.player.get_rid()];query.collision_mask=1;query.margin=.001
		check(game.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),label+" whole visible mesh bounds clear including shared floor RID")
		check(inv.pickup_weapon(0),label+" transfer can return")
	else:
		check(inv.has_weapon(0) and inv.pickups.size()==count,label+" refusal retains ownership and ground count")
		check(changes==before_changes,label+" rejected drop emits no ownership change")
	check(game.weapon.weapons[0].ammo==ammo and game.weapon.reserves==reserves,label+" ammo and reserves unchanged")
func run()->void:
	if not OS.get_user_data_dir().replace("\\","/").contains("reports/QA/test-appdata"):quit(2);return
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	stop_audio(game);game.set_process(false);game.player.set_physics_process(false);game.weapon.set_process(false)
	for gun in game.weapon.weapons:gun.set_process(false);gun.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false)
	game.field_menu.set_open(false);game.player.input_enabled=true;inv=game.weapon_inventory
	inv.changed.connect(func():changes+=1)
	var base:=Vector3(1000,0,1000);game.player.global_position=base;game.player.rotation=Vector3.ZERO
	var camera:Camera3D=game.player.get_view_camera();camera.position=Vector3(0,1.65,0);camera.rotation=Vector3.ZERO
	var shared:=box(base+Vector3(0,-.1,0),Vector3(8,.2,8));box(base+Vector3(0,1.5,-.4),Vector3(3,3,.12),shared)
	await physics_frame
	for side in ["left","right"]:
		game.player.dominant_hand=side
		for repeat in range(3):assert_safe_drop("near wall "+side+str(repeat),true)
	clear_fixture()
	box(base+Vector3(0,-.1,0),Vector3(8,.2,8))
	for offset in [Vector3(.25,1.5,0),Vector3(-.25,1.5,0)]:box(base+offset,Vector3(.1,3,2))
	for offset in [Vector3(0,1.5,.25),Vector3(0,1.5,-.25)]:box(base+offset,Vector3(2,3,.1))
	await physics_frame;assert_safe_drop("enclosed no spot",false)
	clear_fixture();box(base+Vector3(0,-.1,.5),Vector3(2,.2,1.2))
	await physics_frame;assert_safe_drop("ledge chooses supported side",true)
	clear_fixture();box(base+Vector3(0,2.9,0),Vector3(8,.2,8));game.player.global_position=base+Vector3.UP*3
	await physics_frame;assert_safe_drop("raised platform",true)
	game.player.global_position=base+Vector3.UP*10
	await physics_frame;assert_safe_drop("unreachable floor below",false)
	clear_fixture();box(base+Vector3(0,-.1,0),Vector3(8,.2,8));box(base+Vector3(1,1.5,0),Vector3(.12,3,3))
	game.player.global_position=base+Vector3.RIGHT;camera.position=Vector3(-1,1.65,0)
	await physics_frame;assert_safe_drop("body in wall head clear",true)
	clear_fixture();stop_audio(game)
	print("DROP_SAFETY_041_RESULT passes=",passed," failures=",failures.size()," actual_geometry=true synthetic=true headset_tested=false")
	await game._quit_game(0 if failures.is_empty() else 1,"test_complete")
