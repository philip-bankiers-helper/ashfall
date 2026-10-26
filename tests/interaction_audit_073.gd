extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for child in n.get_children():freeze(child)
func verify_label(tool:Node,context:String)->void:
	var expected:Vector3=(tool._paddles[0].global_position+tool._paddles[1].global_position)*.5+Vector3.UP*.13
	check(tool._label.global_position.distance_to(expected)<.0001,context+" label follows actual paddle midpoint")
	check(tool._label.global_basis.is_equal_approx(Basis.IDENTITY),context+" world-up basis")
	check(tool._label.billboard==BaseMaterial3D.BILLBOARD_FIXED_Y,context+" yaw-only billboard")
	check(tool.visible and tool._label.is_visible_in_tree(),context+" visible feedback")
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame;freeze(game)
	game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	var actor=game.player;actor.xr_enabled=false;actor.input_enabled=true;actor.tracking_available=true;actor.vertical_combat_initializing=false;actor.head_obstructed=false
	var tool=game.revive_paddles;check(tool.equip(),"equip actual tool")
	for position in [Vector3(1000,0,1000),Vector3(1003,2,997)]:
		actor.global_position=position;actor.get_view_camera().rotation.z=.4;tool._process(.016);verify_label(tool,"desktop "+str(position))
	var trackers:Array=[]
	actor.xr_enabled=true
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="audit073_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);trackers.append(tracker)
	await process_frame;await physics_frame;actor.update_hand_input_rearm(.2)
	for side in ["left","right"]:
		actor.dominant_hand=side;game.weapon._refresh_hands()
		for position in [Vector3(1000,0,1000),Vector3(1004,1,1002)]:
			actor.global_position=position
			actor.left_hand.global_transform=Transform3D(Basis(Vector3.FORWARD,.4),position+Vector3(-.2,1.2,-.4))
			actor.right_hand.global_transform=Transform3D(Basis(Vector3.RIGHT,.6),position+Vector3(.3,1.5,-.5))
			tool._process(.016);verify_label(tool,"XR "+side+str(position))
	tool.stow();check(not tool._label.is_visible_in_tree(),"stowed feedback hidden")
	var hud=game.combat_hud;hud.set_hud_size(1.0);hud.clear_damage_indicator();hud.refresh(0)
	check(hud.incoming_numbers_enabled,"incoming damage enabled by default")
	check(not hud.incoming_number.visible and not hud.outgoing_number.visible,"rest hides both numbers")
	game._damage_player(0);hud.notify_outgoing(0)
	check(not hud.incoming_number.visible and not hud.outgoing_number.visible,"zero damage does not create number")
	game.health=100;game.shield=100;game._damage_player(12)
	check(hud.incoming_number.visible and hud.incoming_number.text=="-12","actual player damage displays pool loss")
	check(hud.incoming_number.position.is_equal_approx(Vector3(-.18,-.458,-.8)),"incoming preserves authored bottom position")
	var dummy=load("res://scripts/practice_dummy.gd").new();root.add_child(dummy);dummy.set_process(false)
	game._apply_target_damage(dummy,23)
	check(hud.outgoing_number.visible and hud.outgoing_number.text=="23","actual target take_damage displays measured loss")
	check(hud.outgoing_number.position.is_equal_approx(Vector3(.18,-.458,-.8)),"outgoing preserves authored bottom position")
	for size in [.65,1.75]:
		hud.set_hud_size(size)
		var expected_y:float=hud.SHIELD_Y+(-.458-hud.SHIELD_Y)*size
		check(hud.incoming_number.position.is_equal_approx(Vector3(-.18*size,expected_y,-.8)),"incoming respects configured HUD size")
		check(hud.outgoing_number.position.is_equal_approx(Vector3(.18*size,expected_y,-.8)),"outgoing respects configured HUD size")
	hud.refresh(1.16);check(not hud.incoming_number.visible and not hud.outgoing_number.visible,"expired numbers hide")
	dummy.queue_free()
	for tracker in trackers:XRServer.remove_tracker(tracker)
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.25).timeout
	print("INTERACTION_AUDIT_073 checks=",checks," failures=",failures);quit(failures)

