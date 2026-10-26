extends SceneTree
class TrackedBurst extends "res://scripts/burst_carbine.gd":
	func _vr_active()->bool:return true # CPU seam; no XR runtime is initialized.
var checks:=0
var failures:=0
var clock:=0.0
var stamps:Array[float]=[]
var rows:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func tick(gun,dt:float)->void:clock+=dt;gun._process(dt)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="burst058_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	var gun:=TrackedBurst.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);load("res://scripts/arsenal_data.gd").apply(gun,3)
	gun.shot.connect(func(_origin:Vector3,_direction:Vector3,_damage:float)->void:stamps.append(clock))
	var t=trackers[gun.right_hand]
	for dt in [1.0/60,1.0/90,1.0/120]:
		gun.reset_weapon();load("res://scripts/arsenal_data.gd").apply(gun,3);t.set_input("trigger",0.0);gun._process(0);stamps.clear();clock=0;gun.cooldown=0;t.set_input("trigger",1.0);gun._process(0)
		for i in 40:
			if stamps.size()>=3:break
			tick(gun,dt)
		check(stamps.size()==3,"actual trigger commits exactly3 MK18 rounds dt="+str(dt))
		if stamps.size()!=3:continue
		var first_gap:=stamps[1]-stamps[0];var second_gap:=stamps[2]-stamps[1]
		check(absf(first_gap-.080)<=dt+.00001 and absf(second_gap-.080)<=dt+.00001,"shot1to2 and2to3 each match tuned80ms separately")
		check(absf(stamps[2]-stamps[0]-.160)<=dt+.00001,"first-to-third tuned160ms, faster than old286ms")
		check(absf(gun.cooldown-.240)<.00001,"post-third recovery remains separate240ms")
		t.set_input("trigger",0.0);tick(gun,dt);t.set_input("trigger",1.0)
		for i in 40:
			if stamps.size()>=4:break
			tick(gun,dt)
		var post_gap:float=stamps[3]-stamps[2] if stamps.size()>=4 else -1
		check(stamps.size()==4 and absf(post_gap-.240)<=dt+.00001,"third-to-next-burst is measured independently of intra-burst")
		rows.append({"frame_seconds":dt,"shot1_to2":first_gap,"shot2_to3":second_gap,"shot3_to_next":post_gap,"first_to_next":stamps[3]-stamps[0] if stamps.size()>=4 else -1})
		for i in int(.7/dt):tick(gun,dt)
		check(stamps.size()==6,"held trigger never repeats another mechanically committed burst")
		print("MK18_TIMING_058 ",JSON.stringify(rows.back())," original_tuning=true reference_verified=false")
	var f:=FileAccess.open("user://mk18-timing058.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"\t"));f.close()
	for tr in trackers.values():XRServer.remove_tracker(tr)
	gun.shutdown();gun.free();actor.free();await create_timer(.2).timeout
	print("BURST_058_TIMING checks=",checks," failures=",failures," actual_controller_polling=true measured_reference=false");quit(failures)
