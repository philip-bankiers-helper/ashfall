extends SceneTree
var failures:=0
var checks:=0
var trackers:Array=[]
func check(ok:bool,label:String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func freeze(game):
	game.set_process(false);game.player.set_process(false);game.player.set_physics_process(false)
	for enemy in game.enemies:enemy.set_physics_process(false)
func neutral(game,hand,tracker):
	tracker.set_input("grip",0.0)
	game.player.update_hand_input_rearm(.1)
	await physics_frame
	game.player.update_objective_grips()
func press(game,tracker):
	tracker.set_input("grip",1.0)
	await physics_frame
	game.player.update_objective_grips()
func run():
	if not OS.get_user_data_dir().replace("\\","/").contains("reports/QA/test-appdata"):quit(2);return
	var game=load("res://scripts/main.gd").new();root.add_child(game);game.new_campaign();freeze(game)
	check(game.extended_campaign,"six mission grip fixture uses expanded campaign")
	var actor=game.player
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.name="objective_"+str(trackers.size());tracker.type=XRServer.TRACKER_CONTROLLER
		XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers.append(tracker)
	actor.xr_enabled=true;actor.tracking_available=true;game.xr_enabled=true
	# Actual staging grip selects/draws an existing weapon without replenishing it.
	game.weapon.weapons[1].ammo=1
	actor.update_hand_input_rearm(.1)
	var pickup_targets:Array=game.weapon_pickup_props.get_grip_targets()
	var pickup_point:Vector3=pickup_targets[1].position
	actor.global_position=pickup_point+Vector3(0,-.8,.5)
	actor.left_hand.global_position=pickup_point+Vector3(0,0,.1)
	trackers[0].set_pose("grip",actor.left_hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	await neutral(game,actor.left_hand,trackers[0])
	game.weapon.set_holstered(true)
	await press(game,trackers[0])
	check(game.weapon.selected==1 and not game.weapon.is_holstered,"actual staging grip selects and draws Cinder")
	check(game.weapon.weapons[1].ammo==1,"grip pickup preserves existing ammunition")
	check(actor.is_hand_grip_reserved(actor.left_hand),"pickup grip remains consumed until release")
	await neutral(game,actor.left_hand,trackers[0])
	for index in [0,1,2,4,5]:
		game.chapter=index;game.complete=false;game._begin_chapter();freeze(game)
		check(game._station_grip_targets().is_empty() if index!=4 else not game._station_grip_targets().is_empty(),"combat lock or survivor-friendly isolator "+str(index))
		# Lifecycle fixture retires guards explicitly; this is not combat performance evidence.
		for enemy in game.enemies:enemy.queue_free()
		game.enemies.clear();await physics_frame
		var targets:Array=game._station_grip_targets();check(targets.size()==1,"eligible visible station target "+str(index))
		var point:Vector3=targets[0].position
		var screen:MeshInstance3D=game.objective_nodes[index].get_children()[1]
		check(point.distance_to(screen.to_global(Vector3(0,0,.03)))<.01,"target matches exposed screen face "+str(index))
		actor.global_position=point+Vector3(0,-1,.65);actor.head_obstructed=false
		var hand=actor.left_hand if index%2==0 else actor.right_hand
		var tracker=trackers[0] if index%2==0 else trackers[1]
		hand.global_position=point+Vector3(0,0,.12)
		tracker.set_pose("grip",hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		actor.dominant_hand="left" if index%2==0 else "right"
		await neutral(game,hand,tracker)
		game._on_objective_grip("stale_mission",hand)
		check(game.chapter==index,"stale mission signal cannot advance "+str(index))
		await press(game,tracker)
		check(game.spillway_gate.is_open and game.chapter==4 if index==4 else game.chapter==index+1,"fresh actual controller grip activates station "+str(index))
		check(actor.is_hand_grip_reserved(hand),"transition keeps grip consumed "+str(index))
		freeze(game)
		if index==4:
			check(game._station_grip_targets().is_empty(),"open gate has no repeated grip action")
			actor.global_position=game.campaign_extension.exit_position;game._check_spillway_exit()
			check(game.chapter==5,"physical exit predicate advances after grip-open gate")
		await neutral(game,hand,tracker)
	game.complete=false;game.chapter=3;game._begin_chapter();freeze(game)
	check(game._station_grip_targets().is_empty(),"dam cores remain shot-only without grip shortcut")
	game.chapter=0;game._begin_chapter();freeze(game)
	for enemy in game.enemies:enemy.queue_free()
	game.enemies.clear();game.paused=true
	check(game._station_grip_targets().is_empty(),"pause offers no campaign grip action")
	game.paused=false;game.field_menu.set_open(true)
	check(game._station_grip_targets().is_empty(),"menu offers no campaign grip action")
	game.field_menu.set_open(false)
	game._stop_audio_tree(game)
	await create_timer(.25).timeout
	game.free()
	for tracker in trackers:XRServer.remove_tracker(tracker)
	trackers.clear();await process_frame
	print("OBJECTIVE_GRIP_CAMPAIGN checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)
