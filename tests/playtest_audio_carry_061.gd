extends SceneTree
class AWP extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true
class MotionPlayer extends "res://scripts/player.gd":
	func update_tracking()->bool:return tracking_available
var checks:=0
var failures:=0
var actor
var rack
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func input(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip);gun._poll_vr()
func pull(gun)->void:
	input(gun,gun.get_bolt_grip_point(),0)
	input(gun,gun.get_bolt_grip_point(),1)
	input(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
func box(size:Vector3,at:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();body.position=at;body.collision_layer=1
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider);root.add_child(body);return body
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="playtest057_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands();actor.left_hand_reserved=false
		var gun:=AWP.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		gun.ammo_provider=rack;gun.ammo_slot=5;rack.reserves["rifle"]=40
		gun.global_position=Vector3(100,2,100);gun.ammo=1;gun.cooldown=0;gun.chambered=true
		gun.fire()
		check(gun.ammo==0 and gun.spent_chamber and gun.reload_state=="needs_bolt" and gun.magazine.visible,side+" final AWP shot retains magazine/spent casing")
		gun._process(0);check(gun.charging_arrow.visible and not gun.insertion_arrow.visible and not gun.hip_source.visible,side+" only BACK arrow before eject")
		input(gun,gun.OFFER_POINT,0);input(gun,gun.OFFER_POINT,1)
		check(gun.reload_state=="needs_bolt",side+" magazine target cannot bypass first BACK")
		input(gun,gun.get_bolt_grip_point(),0);input(gun,gun.get_bolt_grip_point(),1);input(gun,gun.get_bolt_grip_point()+Vector3.BACK*.07,1)
		check(gun.reload_state=="needs_bolt" and gun.magazine.visible,side+" incomplete first pull does not eject")
		input(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
		check(gun.reload_state=="needs_mag" and not gun.magazine.visible and not gun.spent_chamber,side+" first full BACK ejects magazine and case")
		input(gun,gun.OFFER_POINT,1);check(gun.reload_state=="needs_mag",side+" held bolt grip cannot manufacture fresh magazine grab")
		input(gun,gun.OFFER_POINT,0);input(gun,gun.OFFER_POINT,1);check(gun.reload_state=="held_mag",side+" fresh magazine grab follows first pull")
		var reserve:int=gun.reserve_rounds();input(gun,gun.INSERT_POINT,1)
		check(gun.reload_state=="needs_bolt" and gun.ammo==3 and not gun.chambered and gun.reserve_rounds()==reserve-3,side+" UP seats finite unchambered magazine")
		gun.cooldown=0;gun.fire();check(gun.ammo==3,side+" inserted magazine cannot fire before second BACK")
		input(gun,gun.get_bolt_grip_point(),1);input(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
		check(gun.reload_state=="ready" and gun.chambered and gun.ammo==3,side+" second BACK chambers with continuous support grip")
		gun.cooldown=0;gun.fire();pull(gun)
		check(gun.reload_state=="ready" and gun.chambered and gun.ammo==2,side+" nonfinal normal single cycle retains live magazine")
		var total:int=gun.reserve_rounds()+gun.ammo
		gun.eject_magazine();gun.eject_magazine()
		check(gun.ammo==2 and gun.reserve_rounds()+gun.ammo==total and gun.reload_state=="needs_bolt",side+" repeated partial reload requests cannot eject/refund")
		gun.suspend_for_selection();input(gun,gun.get_bolt_grip_point(),1);check(gun.ammo==2,side+" switch while held cannot finish pending first pull")
		input(gun,gun.get_bolt_grip_point(),0);pull(gun)
		check(gun.ammo==0 and gun.reload_state=="needs_mag" and gun.reserve_rounds()==total,side+" pending first pull survives selection and refunds once")
		gun.reset_weapon();input(gun,gun.get_bolt_grip_point(),0);input(gun,gun.get_bolt_grip_point(),1);input(gun,gun.get_bolt_grip_point()+Vector3.BACK*.12,1)
		check(gun.reload_state=="ready" and gun.ammo==3,side+" loaded ready rifle cannot start reload from bolt grip without thumb request")
		gun.eject_magazine();pull(gun);check(gun.reload_state=="needs_mag" and gun.ammo==0,side+" explicit reload intent enables first BACK")
		gun.shutdown();gun.free()
	#061 restores a deliberately gated single swing whoosh. The old stream-null
	# assertion predates that request; retain its actual no-walking-loop contract.
	actor.xr_enabled=false
	for index in [14,15,16]:
		var sword=rack.weapons[index];sword.visible=true;sword.model.show();sword._pose_weapon();sword.sample_motion(.011)
		var before_audio:int=sword.swing_audio_events
		for i in 45:
			sword.global_position.x+=.006;sword.sample_motion(.011)
		check(sword.swing_audio_events==before_audio and not sword._sound.playing,"sword%d slow0.55m/s walking motion cannot emit or loop a voice"%index)
		check(sword._sound.stream is AudioStreamWAV and sword._sound.stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"sword%d authored whoosh is a finite nonlooping sample"%index)
		sword.global_position.x+=.15;sword.sample_motion(.04)
		check(sword.swing_audio_events==before_audio+1,"sword%d deliberate3.75m/s stroke emits exactly one whoosh"%index)
		for i in 10:sword.sample_motion(.011)
		check(sword.swing_audio_events==before_audio+1,"sword%d resting blade cannot retrigger the whoosh"%index)
		actor.global_position.x+=.3;sword.global_position.x+=.3;sword.sample_motion(.011)
		check(sword.swing_audio_events==before_audio+1,"sword%d artificial body translation cannot retrigger whoosh"%index)
		actor.global_position.x-=.3
		check(sword._hum.max_db<=-18,"sword%d shield hum cannot amplify to default nearby ceiling"%index)
	var ambience=load("res://scripts/ambience.gd").new();root.add_child(ambience);ambience.setup(actor,null);ambience.set_physics_process(false)
	actor.sprinting=false;ambience._step(false);check(ambience._foot.volume_db==-22 and ambience._foot.max_db==-22,"normal walking keeps quiet footsteps")
	actor.sprinting=true;ambience._step(false);check(ambience._foot.volume_db==-15 and ambience._foot.max_db==-15,"general sprint footstep contrast preserved")
	ambience.shutdown();ambience.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	# Real head-only collision: timed trajectory, live ceiling and cancellation.
	for dt in [1.0/60,1.0/90,1.0/120]:
		var ledge:=box(Vector3(4,1.2,4),Vector3(0,.6,-3))
		var p:=MotionPlayer.new();root.add_child(p);p.setup(false);p.set_process(false);p.set_physics_process(false);p.position=Vector3(0,1.201-1.65,-1.4);p._sync_head_shape();await physics_frame
		var before:=p.position
		check(p.try_start_release_mantle(Vector3(.28,1.12,-1.01)) and p.mantling and p.position.distance_to(before)<.001,"mantle starts without instantaneous rise dt="+str(dt))
		var elapsed:=0.0;var peak_step:=0.0
		while p.mantling and elapsed<.25:
			var previous:=p.position;p._physics_process(dt);elapsed+=dt;peak_step=maxf(peak_step,p.position.distance_to(previous))
			if elapsed<.19:check(p.mantling and p.position.y<1.2,"mantle remains in progress before200ms")
		check(absf(elapsed-.2)<=dt+.001 and p.is_supported() and absf(p.position.y-1.2)<.015,"timed mantle ends on actual top around200ms")
		check(peak_step<.24 and not p._body_shape.disabled,"rise uses bounded collision sweeps without disabling head")
		p.free();ledge.free();await physics_frame
	var ledge:=box(Vector3(4,1.2,4),Vector3(0,.6,-3))
	var p:=MotionPlayer.new();root.add_child(p);p.setup(false);p.set_process(false);p.set_physics_process(false);p.position=Vector3(0,1.201-1.65,-1.4);p._sync_head_shape();await physics_frame
	check(p.try_start_release_mantle(Vector3(.28,1.12,-1.01)),"dynamic obstruction fixture starts valid route")
	p._step_mantle(.05)
	var ceiling:=box(Vector3(4,.1,4),Vector3(0,2.05,-3));await physics_frame
	for i in 20:p._step_mantle(1.0/90)
	check(not p.mantling and p.get_view_camera().global_position.y<2.0 and not p.is_supported(),"ceiling appearing after preflight stops safe partial rise")
	p.reset_motion();check(not p.mantling and p._mantle_route.is_empty(),"reset cancels pending trajectory")
	p.free();ceiling.free();ledge.free();await physics_frame
	print("PLAYTEST_AUDIO_CARRY_061 checks=",checks," failures=",failures," synthetic_tracking=true real_physics=true audio_listened=false headset_tested=false")
	quit(failures)
