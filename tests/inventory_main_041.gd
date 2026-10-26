extends "res://tests/integration.gd"
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("reports/QA/test-appdata"):
		printerr("Isolated QA profile required"); quit(2); return
	var game = load("res://main.tscn").instantiate(); root.add_child(game)
	await process_frame; await physics_frame
	# Authored spawn starts one metre above the deck. Let production locomotion
	# settle it before evaluating a ground drop's finite retrieval reach.
	for frame in range(60): await physics_frame
	check(game.weapon_inventory.drop_weapon(4),"authored starting spawn permits drop after actual physics settles")
	check(game.weapon_inventory.pickup_weapon(4),"authored starting spawn drop returns without losing weapon")
	stop_audio(game); game.set_process(false); game.player.set_physics_process(false)
	game.weapon.set_process(false); game.building_input.set_physics_process(false)
	for gun in game.weapon.weapons: gun.set_process(false); gun.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	game.field_menu.set_open(false); game.paused=false; game.dead=false; game.complete=false
	var actor = game.player; var rack = game.weapon; var inv = game.weapon_inventory
	actor.input_enabled=true
	check(rack.inventory == inv and game.weapon_pickup_props == inv,"Main wires shared finite inventory provider")
	# Queue settle calls, then destroy their props before deferred dispatch.
	# This reproduces fast chapter/recovery transitions caught by the full suite.
	for repeat in range(12):
		inv.relocate_pickups(actor.global_position)
		var stale:Node3D=inv.pickups[1]
		inv.pickups.erase(1)
		stale.free()
		game._begin_chapter()
	await process_frame; await physics_frame; await process_frame
	check(inv.pickups.size()==rack.weapons.size()-3 and inv.get_child_count()==rack.weapons.size()-3+inv.aim_rings.size(),"rapid actual Main reset and freed deferred targets leave exactly one prop per unowned catalog type")
	await physics_frame; await physics_frame
	for prop in inv.pickups.values():
		var origin:Vector3=prop.global_position+Vector3.UP*2.0
		var ray:=PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP*20.0,1,[actor.get_rid()])
		var floor_hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not floor_hit.is_empty() and absf(inv._lowest_mesh_point(prop)-floor_hit.position.y-inv.HOVER_HEIGHT)<.002,"actual Main hover pickup rests75cm over supporting floor")
	var platform:=StaticBody3D.new(); platform.position=Vector3(900,3,900)
	var collision:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=Vector3(5,.4,5)
	collision.shape=box; platform.add_child(collision); game.add_child(platform)
	await physics_frame
	var test_prop:Node3D=inv.pickups[3]; test_prop.global_position=Vector3(900,3.6,900)
	await inv._settle_pickup(test_prop)
	check(absf(inv._lowest_mesh_point(test_prop)-3.95)<.002,"actual Main pickup settles on raised platform surface instead of ground zero")
	var fallback:=Vector3(2000,500,2000); test_prop.global_position=fallback
	await inv._settle_pickup(test_prop)
	check(test_prop.global_position==fallback,"bounded twenty metre cast preserves original point when no floor exists")
	platform.queue_free(); inv.relocate_pickups(actor.global_position)
	# Transfer assertions need a clear drop area; authored spawn clutter may safely
	# refuse a drop. Geometry rejection is exercised separately by drop_safety_041.
	var transfer_floor:=StaticBody3D.new(); transfer_floor.position=Vector3(3000,-.1,3000)
	var transfer_collision:=CollisionShape3D.new(); var transfer_shape:=BoxShape3D.new();transfer_shape.size=Vector3(8,.2,8)
	transfer_collision.shape=transfer_shape;transfer_floor.add_child(transfer_collision);game.add_child(transfer_floor)
	actor.global_position=Vector3(3000,0,3000)
	await physics_frame
	check(inv.owned_indices()==[0,2,4],"Main initializes three actual carried types")
	check(not inv.pickup_weapon(1) and inv.pickups.has(1),"actual full inventory retains refused ground weapon")
	var pump = rack.weapons[4]; pump.chambered=false; pump.tube_rounds=2; pump._sync_rounds()
	var rounds:int=pump.ammo; var reserve:Dictionary=rack.reserves.duplicate(true)
	game.field_menu.settings_page="loadout"; game.field_menu._refresh()
	check(game._loadout_icons().size()==4,"three flat weapon pictures plus return picture")
	game.field_menu.loadout_dropped.emit(2)
	check(not inv.has_weapon(4) and inv.pickups.has(4) and inv.has_weapon(2),"backpack row2 drops stable type4 rather than type2")
	check(game._loadout_icons().size()==3,"drop signal refreshes carried flat picture count")
	check(pump.ammo==rounds and not pump.chambered and pump.tube_rounds==2 and rack.reserves==reserve,"actual drop preserves magazine chamber and family reserves")
	check(inv.pickup_weapon(4),"actual ground weapon returns to open carried slot")
	check(pump.ammo==rounds and not pump.chambered and pump.tube_rounds==2 and rack.reserves==reserve,"actual pickup preserves loaded chamber and reserves")
	game.field_menu.settings_page=""; game.encounter_active=true
	# Pickup targets are now per-hand aim-eligible, not every remote prop.
	actor.xr_enabled=true;actor.tracking_available=true;actor.xr_camera.position.y=1.65
	actor.right_hand.rotation=Vector3(PI/2,0,0)
	var combat_tracker:=XRControllerTracker.new();combat_tracker.type=XRServer.TRACKER_CONTROLLER;combat_tracker.name="inventory_main_combat_right"
	XRServer.add_tracker(combat_tracker);actor.right_hand.tracker=combat_tracker.name;actor.right_hand.pose="grip"
	combat_tracker.set_pose("grip",actor.right_hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await process_frame;actor._hand_input_ready[actor.right_hand]=true
	inv.pickups[1].global_position+=actor.right_hand.global_position+Vector3(0,0,-1.2)-inv._pickup_center(1)
	check(game._objective_grip_targets().any(func(t):return str(t.id).begins_with("inventory_pickup:")),"ground grip targets remain available during combat")
	game.paused=true
	check(not game._objective_grip_targets().any(func(t):return str(t.id).begins_with("inventory_pickup:")),"pause hides ground pickup targets")
	game.paused=false; game.field_menu.set_open(true)
	check(not game._objective_grip_targets().any(func(t):return str(t.id).begins_with("inventory_pickup:")),"open menu hides ground pickup targets")
	game.field_menu.set_open(false); actor.input_enabled=true
	XRServer.remove_tracker(combat_tracker)
	# Real Main signal path, actual objective arbiter, synthetic XR grip and pose.
	inv.drop_weapon(0)
	actor.xr_enabled=true; actor.tracking_available=true; actor.xr_camera.position.y=1.65
	var hand=actor.left_hand
	var tracker:=XRControllerTracker.new(); tracker.type=XRServer.TRACKER_CONTROLLER; tracker.name="inventory_main_left"
	XRServer.add_tracker(tracker); hand.tracker=tracker.name; hand.pose="grip"
	var point:Vector3=actor.global_position+Vector3(0,1.25,-.4)
	inv.pickups[1].global_position=point; hand.global_position=point
	tracker.set_pose("grip",hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	actor._hand_input_ready[hand]=true
	tracker.set_input("grip",0.0); actor._objective_grip_frame=-1; actor.update_objective_grips()
	tracker.set_input("grip",1.0); actor._objective_grip_frame=-1; actor.update_objective_grips()
	check(inv.has_weapon(1) and not inv.pickups.has(1),"synthetic tracked fresh grip traverses actual Main arbiter and pickup handler")
	check(rack.selected==1,"Main equips the ground weapon type after successful grip")
	var snapshot:Array=inv.owned_indices(); var expected:int=rack.weapons.size()-snapshot.size()
	actor.xr_enabled=false; XRServer.remove_tracker(tracker)
	game.chapter=mini(1,game.missions.size()-1); game._begin_chapter()
	check(inv.owned_indices()==snapshot and inv.pickups.size()==expected,"actual chapter restart relocates unowned props without resetting ownership")
	game._begin_chapter(); await process_frame
	check(inv.pickups.size()==expected and inv.get_child_count()==expected+inv.aim_rings.size(),"repeated chapter restart leaves no duplicate ground props")
	for i in range(rack.weapons.size()):
		if not inv.has_weapon(i): check(not rack.weapons[i].visible,"unowned actual weapon has no carried phantom "+str(i))
	stop_audio(game)
	print("INVENTORY_MAIN_041_RESULT passes=",passed," failures=",failures.size()," synthetic=true headset_tested=false")
	await game._quit_game(0 if failures.is_empty() else 1,"test_complete")
