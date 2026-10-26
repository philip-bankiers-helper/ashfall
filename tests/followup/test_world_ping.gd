extends SceneTree
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
var failures:=0
var checks:=0
func check(ok:bool,text:String):
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",text)
func _initialize():call_deferred("run")
func run():
	var scene:=Node3D.new();root.add_child(scene)
	var actor=load("res://scripts/player.gd").new();scene.add_child(actor);actor.setup(false);actor.xr_enabled=true
	actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.name="ping"+str(hand.get_instance_id());tracker.type=XRServer.TRACKER_CONTROLLER
		XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	var floor_body:=StaticBody3D.new();var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(4,0.2,4)
	floor_body.add_child(shape);scene.add_child(floor_body);floor_body.position.y=-2
	var game:=Game.new();scene.add_child(game)
	var ping=load("res://scripts/world_ping.gd").new();scene.add_child(ping);ping.setup(actor,game);ping.set_process(false)
	await physics_frame;await physics_frame;actor.update_hand_input_rearm(0.1)
	for side in ["right","left"]:
		actor.dominant_hand=side
		for tracker in trackers.values():tracker.set_input("by_button",false)
		ping.clear_all();ping._process(0.01)
		trackers[actor.get_weapon_hand()].set_input("by_button",true);ping._process(0.01)
		check(ping.remaining==0,side+" dominant BY does not place ping")
		trackers[actor.get_support_hand()].set_input("by_button",true);ping._process(0.01)
		check(ping.remaining>19 and ping.marker.visible,side+" support BY places corrected-ray surface marker")
		check(absf(ping.marker.global_position.y+1.865)<0.01,"ping anchored above actual floor hit")
		game.paused=true;ping._process(0.01);check(not ping.marker.visible,"pause hides marker")
		game.paused=false;ping.remaining=0;ping._process(0.01);check(ping.remaining==0,"held button across resume cannot place ping")
		trackers[actor.get_support_hand()].set_input("by_button",false);ping._process(0.01)
		trackers[actor.get_support_hand()].set_input("by_button",true);ping._process(0.01)
		ping._process(21);check(not ping.marker.visible,"single marker expires after twenty seconds")
	check(ping.get_child_count()==1,"fixed one marker node")
	check(ping.marker.text.unicode_at(0)==0x25C6,"ping uses intended diamond Unicode glyph")
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	trackers.clear();scene.free()
	print("WORLD_PING_RESULT checks=",checks," failures=",failures)
	quit(failures)

