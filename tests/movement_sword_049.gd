extends SceneTree
class TrackedActor extends "res://scripts/player.gd":
	# Adapt session presence only; production controller gates and full motion remain.
	func update_tracking()->bool:tracking_available=true;return true
class Katana extends "res://scripts/melee_sword.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=TrackedActor.new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.xr_camera.position.y=1.65;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="swordmotion049_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("primary",Vector2.ZERO);t.set_input("grip",0.0);t.set_input("trigger",0.0);trackers[hand]=t
	var floor:=StaticBody3D.new();root.add_child(floor);floor.position.y=-.1
	var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.2,100);col.shape=box;floor.add_child(col)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	var old=rack.weapons[14];old.shutdown();old.free();var katana:=Katana.new();rack.add_child(katana);katana.setup(actor,false);katana.set_process(false);katana.set_physics_process(false);rack.weapons[14]=katana;rack._connect_weapon_events(katana)
	await physics_frame;await physics_frame;await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for mode in [[0,1.0],[14,1.15],[15,1.25],[16,1.25],[14,.90]]:
			actor.position=Vector3.ZERO;actor.velocity=Vector3.ZERO;actor._grabs.clear();actor.input_enabled=true;actor.head_obstructed=false;actor._sprint_mode=0;actor.left_hand_reserved=false
			for t in trackers.values():t.set_input("primary",Vector2.ZERO);t.set_input("grip",0.0);t.set_input("trigger",0.0)
			actor.update_hand_input_rearm(.2);rack.selected=mode[0];rack.is_holstered=false;rack._apply_selection();var active=rack.weapons[mode[0]];active.refresh_hands()
			active.right_hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,1.2,-.3));active.cooldown=0;active._process(0)
			if mode[0]==14:
				active.left_hand.global_position=active.model.to_global(active.SUPPORT_POINT);active._process(0)
				trackers[active.left_hand].set_input("grip",1.0 if mode[1]<1 else 0.0);active._process(0)
			trackers[actor.left_hand].set_input("primary",Vector2(0,1))
			actor._physics_process(1.0/90.0)
			var speed:=Vector2(actor.velocity.x,actor.velocity.z).length();var expected:float=actor.effective_walk_speed()*mode[1]
			print("SWORD_WALK ",side," mode=",mode," actual=",speed," expected=",expected," supported=",actor.is_supported())
			check(absf(speed-expected)<.02,side+" actual floor movement applies equipped sword gain"+str(mode))
			check(is_equal_approx(actor.get_effective_glide_speed(),actor.effective_walk_speed()*2),side+" sword keeps accepted base glide relation"+str(mode))
	for t in trackers.values():XRServer.remove_tracker(t)
	rack.shutdown();rack.free();actor.free();floor.free();await create_timer(.2).timeout
	print("MOVEMENT_SWORD_049 checks=",checks," failures=",failures," actual_physics=true headset_tested=false")
	quit(failures)
