extends SceneTree
class Gun extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func triangles(mesh:Mesh)->int:
	var count:=0
	for surface in mesh.get_surface_count():
		var indices=mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		count+=(indices.size() if indices!=null and not indices.is_empty() else mesh.surface_get_array_len(surface))/3
	return count
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="asset081_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var fallback:=Gun.new();root.add_child(fallback);fallback.setup(actor,false);fallback.set_process(false);fallback.set_physics_process(false)
	check(not fallback.has_meta("downloaded_model_077") and not ResourceLoader.has_cached("res://assets/models/download_awp/model.glb"),"original AWP fallback avoids imported GLB")
	fallback.shutdown();fallback.free();ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_awp/asset-provenance.json"))
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
		var gun:=Gun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
		gun._desktop_signals=true
		var body:MeshInstance3D=gun.model.get_node("DownloadedAWPBody081");var moving:MeshInstance3D=gun.bolt_handle.get_node("DownloadedAWPBolt081")
		check(gun.get_meta("downloaded_model_077","")=="awp",side+" actual imported AWP active")
		check(triangles(body.mesh)+triangles(moving.mesh)+triangles(gun.magazine.mesh)==int(data.visible_source_triangles),side+" visible source triangle accounting exact")
		check(int(data.visible_source_triangles)+int(data.omitted_triangles)==21916 and int(data.omitted_triangles)==0,side+" original cosmetic scope omission explicitly accounted")
		check(triangles(moving.mesh)==414 and triangles(gun.magazine.mesh)==680,side+" real bolt/knob and magazine separated")
		check(gun.magazine.mesh==gun.loose_magazine.mesh and gun.hip_source.get_child(0).mesh==gun.magazine.mesh and gun._debris[gun.CASING_POOL_SIZE].mesh==gun.magazine.mesh,side+" all magazine presentations use imported shape")
		check(absf(gun.magazine.position.z-gun.get_magazine_insert_point().z)<.00001,side+" actual well and rendered magazine agree")
		var expected:=Transform3D(gun.model.global_basis*Basis(Vector3.RIGHT,-deg_to_rad(2.5)),gun.model.to_global(Vector3(0,.047,-1.01)))
		check(gun.get_shot_transform().is_equal_approx(expected),side+" unchanged calibrated firing ray")
		check(gun.optic.gun==gun and gun.optic.OCULAR==Vector3(0,.151,.065) and gun.optic.zoom_magnification==4 and gun.scoped_damping_multiplier(4,true)==2,side+" functional scope alignment and2x damping retained")
		check(gun.optic.right_scope_camera!=null and gun.optic.scope_camera!=null and gun.optic.get_parent()==gun.model,side+" existing per-eye scope/compositor ownership retained")
		check(moving.layers==1<<18 and body.layers==1<<18 and moving.basis.get_scale().is_equal_approx(Vector3.ONE),side+" live mesh layer and unit hierarchy scale")
		var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
		var p:Array=data.actual_bolt_contact;var knob:=Vector3(p[0],p[1],p[2])
		gun.eject_magazine();check(gun.reload_state=="needs_bolt" and gun.ammo==3,side+" reload request requires first BACK before magazine eject")
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.model.to_global(knob);tracker.set_input("grip",1.0);gun._poll_vr()
		var start:Vector3=gun.bolt_handle.position;hand.global_position+=gun.global_basis*Vector3.BACK*.06;gun._poll_vr()
		check(gun.bolt_handle.position.z>start.z+.05 and gun.reload_state=="needs_bolt",side+" real visible bolt follows partial physical pull")
		hand.global_position+=gun.global_basis*Vector3.BACK*.07;gun._poll_vr();check(gun.reload_state=="needs_mag" and gun.ammo==0,side+" first full BACK ejects magazine")
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(gun.get_magazine_offer_point());tracker.set_input("grip",1.0);gun._poll_vr();check(gun.reload_state=="held_mag",side+" actual tracker acquires new magazine")
		hand.global_position=gun.reload_world_point(gun.get_magazine_insert_point());gun._poll_vr();check(gun.reload_state=="needs_bolt" and gun.ammo==3 and not gun.chambered,side+" UP insertion still requires chambering")
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.model.to_global(knob);tracker.set_input("grip",1.0);gun._poll_vr();hand.global_position+=gun.global_basis*Vector3.BACK*.13;gun._poll_vr()
		check(gun.reload_state=="ready" and gun.chambered and gun.bolt_handle.position==gun.BOLT_REST,side+" second BACK chambers and spring returns imported bolt")
		tracker.set_input("grip",0.0);gun._poll_vr();gun.cooldown=0;gun.fire();check(gun.ammo==2 and gun.spent_chamber and gun.reload_state=="needs_bolt",side+" nonfinal shot retains correct chamber state")
		gun.recoil=0;gun.recoil_pitch=0;gun.recoil_yaw=0;gun._apply_recoil_visual()
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.model.to_global(knob);tracker.set_input("grip",1.0);gun._poll_vr();hand.global_position+=gun.global_basis*Vector3.BACK*.13;gun._poll_vr()
		check(gun.reload_state=="ready" and gun.chambered and gun.ammo==2,side+" nonfinal shot needs only BACK, no magazine exchange")
		gun.shutdown();gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("DOWNLOADED_AWP_081 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
