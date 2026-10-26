extends SceneTree
class AWP extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true
class SPR extends "res://scripts/spr.gd":
	func _vr_active()->bool:return true
class S85 extends "res://scripts/catalog_firearm.gd":
	func _init()->void:profile_id="s85";mode="bolt"
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
	for hand in trackers:
		trackers[hand].set_input("grip",0.0);trackers[hand].set_input("trigger",0.0);trackers[hand].set_input("primary",Vector2.ZERO)
	actor.update_hand_input_rearm(.2);actor._grabs.clear();actor.left_hand_reserved=false
func run()->void:
	root.size=Vector2i(1100,700)
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="sniper051_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D(Basis.IDENTITY,Vector3(.2 if hand==actor.right_hand else -.2,1.3,-.4)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=t
	await process_frame;neutral()
	for side in ["right","left"]:
		actor.dominant_hand=side;neutral()
		for kind in [AWP,SPR,S85]:
			var gun=kind.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._process(0)
			var rack:=Rack.new();root.add_child(rack);rack.weapons=[gun];var game:=Game.new();root.add_child(game)
			var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(actor,rack,game);reticle.set_process(false);reticle.update_reticle()
			check(not reticle.visible and not gun.allows_world_reticle(),side+" S01 sniper hip crosshair absent "+str(gun.get_script()))
			check(gun._displayed_pose_valid,side+" S01 unscoped sniper still caches rendered gun aim")
			var old:Transform3D=gun.get_firing_pose();gun.right_hand.position+=Vector3(.1,.05,0)
			check(gun.get_firing_pose().is_equal_approx(old),side+" S01 raw hand update cannot replace last displayed aim before gun render")
			if kind!=S85:
				gun.optic.active=true;gun.optic.lens.show();reticle.update_reticle()
				check(not reticle.visible and gun.optic.lens.visible,side+" S01 optic reticle geometry remains while ordinary reticle absent")
				gun.optic.shutdown();reticle.update_reticle();check(not reticle.visible,side+" S01 exiting scope never restores sniper hip reticle")
			if kind==AWP:
				gun.supported=true;gun.optic.zoom_sample(Vector2.ZERO,true,true)
				check(gun.optic.zoom_magnification==4.0,side+" S02 default4x")
				trackers[gun.left_hand].set_input("primary",Vector2.UP);gun.optic.refresh_optic(0)
				check(gun.optic.zoom_magnification==4.0,side+" S02 other controller cannot change AWP zoom")
				trackers[gun.right_hand].set_input("primary",Vector2(0,1));gun.optic.refresh_optic(0)
				check(gun.optic.zoom_magnification==8.0,side+" S02 actual dominant forward changes4x to8x")
				gun.optic.refresh_optic(0);check(gun.optic.zoom_magnification==8.0,side+" S02 held stick cannot repeat toggle")
				trackers[gun.right_hand].set_input("primary",Vector2.ZERO);gun.optic.refresh_optic(0);trackers[gun.right_hand].set_input("primary",Vector2(0,1));gun.optic.refresh_optic(0)
				check(gun.optic.zoom_magnification==4.0,side+" S02 fresh forward can return to4x")
				gun.optic.zoom_sample(Vector2.ZERO,false,true);gun.optic.zoom_sample(Vector2(0,1),true,true)
				check(gun.optic.zoom_magnification==4.0,side+" S02 entering scope with held forward cannot silently select8x")
				gun.optic.zoom_sample(Vector2.ZERO,true,true);gun.optic.zoom_sample(Vector2(0,1),true,false)
				check(gun.optic.zoom_magnification==4.0,side+" S02 tracking/input loss resets zoom and rearm")
				gun.global_transform=Transform3D.IDENTITY;gun.model.transform=Transform3D.IDENTITY;gun.camera.global_transform=Transform3D.IDENTITY
				for power in [4.0,8.0]:
					gun.optic.zoom_magnification=power;gun.optic._commit_displayed_frame()
					check(gun.optic.scope_camera.global_position.distance_to(gun.camera.global_position)<.000001,side+" S02 optical view and unaided eye share origin "+str(power))
					for fov in [70.0,100.0]:
						for ipd in [.058,.072]:
							for sign_x in [-1.0,1.0]:
								var eye:=Camera3D.new();root.add_child(eye);eye.fov=fov;eye.keep_aspect=Camera3D.KEEP_HEIGHT;eye.position=Vector3(sign_x*ipd*.5,0,0)
								var points:Array[Vector3]=[Vector3(0,.6,-20),Vector3(0,-.6,-20)];var direct:Array[Vector2]=[];var through:Array[Vector2]=[]
								for point in points:
									direct.append(eye.unproject_position(point))
									var uv:Vector2=gun.optic.scope_camera.unproject_position(point)/Vector2(gun.optic.viewport.size)
									var plane:Vector3=gun.camera.to_global(Vector3((uv.x-.5)*.30,(.5-uv.y)*.30,-.45));through.append(eye.unproject_position(plane))
								var ratio:float=absf(through[0].y-through[1].y)/absf(direct[0].y-direct[1].y)
								check(absf(ratio-power)<.03,side+" S03 geometric per-eye target scale "+str(power)+" ratio="+str(ratio)+" fov="+str(fov)+" ipd="+str(ipd)+" eye="+str(sign_x))
								eye.free()
			reticle.free();rack.free();game.free();gun.shutdown();gun.free();neutral()
	for t in trackers.values():XRServer.remove_tracker(t)
	trackers.clear();actor.free();await process_frame
	print("SNIPERS_051 checks=",checks," failures=",failures," cpu_projection_only=true native_rendered=false headset_tested=false stereo_vergence_verified=false")
	quit(failures)
