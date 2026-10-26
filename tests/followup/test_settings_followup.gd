extends SceneTree
class Blocker extends Node:
	var blocked:=false
	func blocks_sprint()->bool:return blocked
var failures:=0
var checks:=0
func check(ok:bool,label:String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	var menu=load("res://scripts/menu.gd").new();root.add_child(menu);menu.setup(actor);menu.set_process(false)
	check(not menu.vignette_enabled and actor.smooth_turn_speed==360 and is_equal_approx(actor.effective_walk_speed(),6.5),"fresh defaults vignette off smooth360 and walk1x=6.5m/s")
	menu.apply_settings({})
	check(actor.walk_speed_multiplier==1 and not menu.vignette_enabled,"missing settings use fresh defaults without false migration")
	menu.apply_settings({"walk_speed_multiplier":1.2,"vignette_enabled":true,"smooth_turn_speed":90})
	check(is_equal_approx(actor.walk_speed_multiplier,1.0) and is_equal_approx(actor.effective_walk_speed(),6.5),"legacy saved120% migrates once to new 6.5m/s calibration")
	check(menu.vignette_enabled and actor.smooth_turn_speed==90,"existing explicit user choices preserved")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(menu.get_settings()))
	check(saved.movement_settings_version==3,"saved settings carry explicit calibration version3")
	menu.apply_settings(saved);menu.apply_settings(saved)
	check(actor.walk_speed_multiplier==1,"version2 roundtrip does not migrate twice")
	menu.apply_settings({"walk_speed_multiplier":.25})
	check(actor.walk_speed_multiplier==.25,"legacy lower speed clamps to attainable newminimum")
	menu.apply_settings({"walk_speed_multiplier":"bad"})
	check(actor.walk_speed_multiplier==1,"malformed legacy speed does not migrate default")
	menu.apply_settings({"movement_settings_version":2,"snap_degrees":999,"smooth_turn_speed":999,"walk_speed_multiplier":99,"sprint_binding":"left_grip"})
	check(actor.snap_degrees==180 and actor.smooth_turn_speed==720 and actor.walk_speed_multiplier==3,"new persisted bounds180/720/3 enforced")
	check(actor.sprint_binding=="left_grip","optional sprint binding persists")
	menu.settings_page="movement"
	check(menu.numeric_setting(2).max==180 and menu.numeric_setting(3).max==720,"slider bounds agree with save bounds")
	menu.reset_movement_settings()
	print("RESET_VALUES ",actor.sprint_binding," ",actor.smooth_turn_speed," ",actor.walk_speed_multiplier," ",menu.vignette_enabled)
	check(actor.sprint_binding=="left_stick_click" and actor.smooth_turn_speed==360 and actor.walk_speed_multiplier==1 and not menu.vignette_enabled,"reset uses new defaults including physical leftclick sprint")
	var floor:=StaticBody3D.new();root.add_child(floor)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(20,.2,20);collision.shape=shape;floor.add_child(collision);floor.position.y=-.1
	actor.position=Vector3(0,.02,0)
	await physics_frame
	actor._resolve_support(.05, true);await physics_frame
	actor._resolve_support(.05, true)
	var tracker:=XRControllerTracker.new();tracker.name="sprint_left";tracker.type=XRServer.TRACKER_CONTROLLER
	XRServer.add_tracker(tracker);actor.left_hand.tracker=tracker.name;actor.left_hand.pose="grip"
	tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	actor.xr_enabled=true;actor.update_hand_input_rearm(.1)
	tracker.set_input("primary",Vector2(0,1));tracker.set_input("primary_click",true)
	check(actor.is_supported() and actor.sprint_requested(),"grounded moving physical leftclick requests sprint")
	actor.dominant_hand="left"
	check(actor.sprint_requested(),"physical sprint binding independent of weapon dominance")
	tracker.set_input("primary",Vector2.ZERO)
	check(not actor.sprint_requested(),"stationary click never sprints")
	tracker.set_input("primary",Vector2(0,1));actor.input_enabled=false
	check(not actor.sprint_requested(),"paused gameplay blocks sprint")
	actor.input_enabled=true;actor.left_hand_reserved=true
	tracker.set_input("primary_click",false);actor.sprint_requested()
	tracker.set_input("primary_click",true)
	check(actor.sprint_requested(),"physical stick click remains available during support reservation")
	actor.left_hand_reserved=false;actor._grabs[actor.left_hand]=Vector3.ZERO
	check(not actor.sprint_requested(),"same-frame grabbed hand blocks sprint")
	actor._grabs.clear();actor.mantling=true
	check(not actor.sprint_requested(),"mantle blocks sprint")
	actor.mantling=false
	var blocker:=Blocker.new();root.add_child(blocker);actor.sprint_conflict_provider=blocker;blocker.blocked=true
	actor.sprint_binding="left_grip";tracker.set_input("primary_click",false);tracker.set_input("grip",0.0);actor.sprint_requested()
	tracker.set_input("grip",1.0)
	check(not actor.sprint_requested(),"support/reload intent callback blocks fresh optional grip sprint")
	blocker.blocked=false;actor.sprint_binding="left_grip";tracker.set_input("primary_click",false);tracker.set_input("grip",0.0);actor.sprint_requested()
	tracker.set_input("grip",1.0)
	actor.left_hand.global_position=Vector3(0,1.2,0)
	check(actor.sprint_requested(),"optional free leftgrip requests sprint")
	var wall:=StaticBody3D.new();root.add_child(wall);wall.position=Vector3(0,1.2,-.2)
	var wall_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(2,2,.2);wall_shape.shape=box;wall.add_child(wall_shape)
	await physics_frame
	actor.left_hand.global_position=Vector3(0,1.2,0)
	check(not actor.sprint_requested(),"nearby climb surface wins initial grip before grab latch")
	wall.free();tracker.invalidate_pose("grip")
	check(not actor.sprint_requested(),"tracking loss blocks sprint")
	menu.free();actor.free();floor.free();blocker.free();XRServer.remove_tracker(tracker);tracker=null
	await process_frame
	print("SETTINGS_FOLLOWUP_RESULT checks=",checks," failures=",failures," synthetic=true")
	quit(failures)

