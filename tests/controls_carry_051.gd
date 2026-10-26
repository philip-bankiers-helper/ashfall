extends SceneTree
class DT11 extends "res://scripts/dt11.gd":
	func _vr_active()->bool:return true
class Magnum extends "res://scripts/revolver.gd":
	func _vr_active()->bool:return true
class AWP extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true
class SPR extends "res://scripts/spr.gd":
	func _vr_active()->bool:return true
class Pair extends "res://scripts/dual_pistols.gd":
	func _vr_active()->bool:return true
class RFB extends "res://scripts/catalog_firearm.gd":
	func _init()->void:profile_id="rfb"
	func _vr_active()->bool:return true
class Rack extends Node3D:
	var weapons:Array=[]
	var selected:=0
	var is_holstered:=false
	var is_selecting:=false
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
var checks:=0
var failures:=0
var actor
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func neutral()->void:
	actor._grabs.clear();actor.left_hand_reserved=false;actor.input_enabled=true
	for t in trackers.values():
		t.set_input("trigger",0.0);t.set_input("grip",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
	actor.update_hand_input_rearm(.2)
func start(script):
	var gun=script.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);return gun
func stop(gun)->void:gun.shutdown();gun.free();neutral()
func hand(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);gun._poll_vr()
func flick(gun,axis:Vector3,valid:bool=true)->void:
	for i in 4:gun.gun_flick_sample(Vector3.ZERO,Vector3.FORWARD,.03,valid,false)
	gun.gun_flick_sample(axis*.12,Vector3.FORWARD,.08,valid,false)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for h in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="controls050_"+str(h.get_instance_id());XRServer.add_tracker(t);h.tracker=t.name;h.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[h]=t
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side;neutral()
		var dt=start(DT11);dt._process(0)
		check(not dt.swipe_arrow.visible,side+" C05 ready DT has no downward opening arrow")
		var offer:Vector3=dt.get_reload_grab_point();hand(dt,offer,0);hand(dt,offer,1);hand(dt,offer+Vector3.DOWN*.1,1)
		check(dt.action.state=="ready" and dt.ammo==2,side+" C05 down cannot open loaded DT")
		trackers[dt.right_hand].set_input("primary_click",false);dt._poll_vr();trackers[dt.right_hand].set_input("primary_click",true);dt._poll_vr()
		check(dt.action.state=="open_empty",side+" C05 fresh dominant thumbstick click opens")
		trackers[dt.right_hand].set_input("primary_click",false)
		offer=dt.get_reload_grab_point();hand(dt,offer,0);hand(dt,offer,1);hand(dt,offer+Vector3.DOWN*.08,1)
		check(dt.action.state=="open_loaded",side+" C04 C05 DOWN inserts only into already open chambers")
		hand(dt,dt.get_reload_grab_point()+Vector3.RIGHT*.21,0);var close:Vector3=dt.get_reload_grab_point()+Vector3.RIGHT*.21;hand(dt,close,1);hand(dt,close+Vector3.UP*.09,1)
		check(dt.action.state=="ready" and dt.ammo==2,side+" C04 wider offhand close target accepts UP")
		for i in 2:dt.cooldown=0;dt._semi_release=true;dt.fire()
		check(dt.action.state=="open_empty" and dt.ammo==0,side+" C05 final empty shot auto-opens")
		dt.grab_magazine();dt.insert_magazine();flick(dt,Vector3.DOWN)
		check(dt.action.state=="open_loaded",side+" C04 downward gun flick cannot close")
		dt.closure.reset();actor._grabs[dt.left_hand]=Vector3(1,1,1);flick(dt,Vector3.UP)
		check(dt.action.state=="ready" and actor._grabs.has(dt.left_hand),side+" C04 gun-only UP closes without stealing wall anchor")
		actor._grabs.clear();stop(dt)
		var rfb=start(RFB);rfb.eject_magazine()
		hand(rfb,Vector3(0,-.28,-.18),0);hand(rfb,Vector3(0,-.28,-.18),1)
		check(rfb.reload_state=="needs_mag",side+" C11 RFB front well cannot grab rear magazine")
		hand(rfb,Vector3(0,-.28,.14),0);hand(rfb,Vector3(0,-.28,.14),1)
		check(rfb.reload_state=="held_mag",side+" C11 RFB physical rear offer can be grabbed")
		hand(rfb,Vector3(0,-.10,.14),1)
		check(rfb.reload_state=="needs_rack",side+" C11 RFB rear UP inserts")
		hand(rfb,Vector3(.065,.055,-.10),0);hand(rfb,Vector3(.065,.055,-.10),1);hand(rfb,Vector3(.065,.055,.01),1)
		check(rfb.reload_state=="ready" and rfb.ammo==rfb.magazine_size,side+" C11 RFB side handle BACK charges")
		stop(rfb)
		var rev=start(Magnum);rev.chambers.assign(["empty","empty","empty","empty","empty","empty","empty"]);rev._sync();rev.eject_magazine();rev._update_reload_visuals()
		check(rev.offered.visible and rev.offered_rounds.size()==7,side+" C02 seven loose cartridge offers are present")
		check(rev.offered.position.distance_to(rev.cylinder.position)>.14,side+" C02 loose ammunition is separated from cylinder and hand")
		offer=rev.get_reload_grab_point();hand(rev,offer,0);hand(rev,offer,1);hand(rev,offer+Vector3.FORWARD*.20,1)
		check(rev.reload_state=="cylinder_loaded" and rev.ammo==7,side+" C02 forward physical load still works")
		var begin:Vector3=offer+Vector3.FORWARD*.20;hand(rev,begin+Vector3.RIGHT*.09,1)
		check(rev.reload_state=="ready",side+" C03 manual offhand RIGHT closes with continuous grip")
		rev.eject_magazine();rev.insert_magazine();flick(rev,Vector3.LEFT)
		check(rev.reload_state=="cylinder_loaded",side+" C03 left flick rejected")
		rev.closure.reset();flick(rev,Vector3.RIGHT,false)
		check(rev.reload_state=="cylinder_loaded",side+" C03 invalid tracking cannot close")
		flick(rev,Vector3.RIGHT)
		check(rev.reload_state=="ready" and rev.ammo==7,side+" C03 dominant gun RIGHT closes")
		stop(rev)
		var awp=start(AWP);awp.cooldown=0;awp.fire();check(awp.reload_state=="needs_bolt" and awp.bolt_phase=="back",side+" C09 AWP requests only BACK")
		var handle:Vector3=awp.get_bolt_grip_point();awp.bolt_sample(handle,false,true);awp.bolt_sample(handle,true,true);awp.bolt_sample(handle+Vector3.UP*.09,true,true)
		check(awp.reload_state=="needs_bolt",side+" C09 lift cannot substitute for BACK")
		awp.bolt_sample(handle+Vector3.BACK*.13,true,true)
		check(awp.reload_state=="ready" and awp.chambered and not awp.spent_chamber and awp.bolt_handle.position==awp.BOLT_REST,side+" C09 one BACK pull cycles and automatically returns")
		for roll in [-1.2,-.5,0.0,.8,1.4]:
			awp.model.basis=Basis(Vector3.FORWARD,roll);awp.optic._commit_displayed_frame()
			check(awp.optic.scope_camera.global_basis.y.dot(Vector3.UP)>.99999,side+" C06 AWP camera/crosshair remains upright roll="+str(roll))
			check((-awp.optic._displayed_pose.basis.z).dot(-awp.get_shot_transform().basis.z)>.99999,side+" C06 upright scope preserves firing axis")
		stop(awp)
		var spr=start(SPR);spr.global_transform=Transform3D.IDENTITY;spr.model.basis=Basis.IDENTITY
		var view:Camera3D=actor.get_view_camera();view.global_transform=Transform3D(spr.optic.global_basis,spr.optic.to_global(spr.optic.OCULAR+Vector3.BACK*.16))
		check(not spr.supported and spr.optic.simulate_displayed_frame_for_test(),side+" C07 eye alignment activates existing rectangular SPR without offhand grip")
		var rack:=Rack.new();root.add_child(rack);rack.weapons=[spr];var game:=Game.new();root.add_child(game)
		var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(actor,rack,game);reticle.set_process(false);reticle.update_reticle()
		check(spr.get_scope_overlay_active() and not reticle.visible,side+" C08 SPR look-through suppresses world crosshair")
		view.position.x+=.5;spr.optic.refresh_optic(0);reticle.update_reticle()
		check(not spr.get_scope_overlay_active() and not reticle.visible,side+" S01 leaving SPR never restores a hip-fire reticle")
		reticle.free();rack.free();game.free();stop(spr)
		var pair=start(Pair);pair.set_process(false)
		for index in 2:
			var gun=pair.guns[index];gun.ammo=0;gun.reload_state="needs_mag"
			var other:float=pair.guns[1-index].spin_elapsed
			for i in 4:gun.flick_sample(Vector3.ZERO,Vector3.FORWARD,.05,true,false)
			gun.flick_sample(Vector3.UP*.15,Vector3.FORWARD,.1,true,false)
			var shot_before:Transform3D=gun.get_shot_transform();gun._process(.12)
			check(gun.spin_elapsed<gun.SPIN_SECONDS and absf(gun.spin_root.rotation.x)>.1,side+" C01 accepted flick starts visible spin hand"+str(index))
			check(is_equal_approx(pair.guns[1-index].spin_elapsed,other),side+" C01 spin remains independent")
			gun.spin_elapsed=gun.SPIN_SECONDS;gun._process(0)
			check(gun.spin_root.basis.is_equal_approx(Basis.IDENTITY),side+" C01 full spin returns neutral")
			var full_ammo:int=gun.ammo;gun.reload_flick()
			check(gun.spin_elapsed==0 and gun.ammo==full_ammo,side+" C01 full gun also flips without creating or spending ammunition")
		stop(pair)
	var menu=load("res://scripts/menu.gd").new();root.add_child(menu);menu.setup(actor);menu.set_process(false);menu.settings_page="weapons"
	check(menu.numeric_setting(0).max==2.0 and menu.weapon_settings.motion_damping==1.35,"C15 damping adjustable to200%, stronger135% fresh default")
	menu.apply_settings({"weapon_settings":{"motion_damping":1.0}})
	check(menu.weapon_settings.motion_damping==1.0,"C15 legacy100% retains96ms tuning, no unit reinterpretation")
	menu.set_numeric_setting(0,2.0);var settings:Dictionary=menu.get_settings();menu.apply_settings(settings)
	check(menu.weapon_settings.motion_damping==2.0,"C15 200% round-trips saved settings")
	menu.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await create_timer(.2).timeout
	print("CONTROLS_050 checks=",checks," failures=",failures," synthetic=true rendered=false headset_tested=false")
	quit(failures)
