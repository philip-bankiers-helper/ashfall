extends SceneTree
class Gun extends "res://scripts/dt11.gd":
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
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="dtasset081_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var fallback:=Gun.new();root.add_child(fallback);fallback.setup(actor,false);fallback.set_process(false);fallback.set_physics_process(false)
	check(not fallback.has_meta("downloaded_model_077") and not ResourceLoader.has_cached("res://assets/models/download_dt11/model.glb"),"original DT11 fallback remains lazy")
	fallback.shutdown();fallback.free();ProjectSettings.set_setting("ashfall/lightweight_models",false)
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
		var gun:=Gun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
		gun._desktop_signals=true
		var body:MeshInstance3D=gun.model.get_node("DownloadedDT11Body081");var moving:MeshInstance3D=gun.hinge.get_node("DownloadedDT11Barrels081")
		check(gun.get_meta("downloaded_model_077","")=="dt11",side+" imported stock/receiver and hinged barrels active")
		check(triangles(body.mesh)+triangles(moving.mesh)==5846 and triangles(moving.mesh)==1584,side+" source triangle accounting exact,242-triangle fore-end explicitly replaced")
		check(gun.hinge.position.is_equal_approx(Vector3(0,-.135,-.13)) and gun.fore_end_marker.position.is_equal_approx(Vector3(0,.09,-.27)),side+" accepted hinge pivot and support/close grip retained")
		check(not gun.hinge.get_node("ContouredForeEnd063").visible,side+" contoured functional fore-end retained")
		check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,.04,-.65)))<.00001,side+" accepted ballistic origin retained")
		check(absf(gun.chamber_markers[0].position.x)<.02 and gun.chamber_live[0].mesh.top_radius<.01,side+" rendered ports, caps and real markers fit narrower source bores")
		var inserted:Vector3=gun.get_chamber_insert_point();check(absf(inserted.y-.04)<.00001 and absf(inserted.z+.113)<.00001,side+" fitted closed chamber center matches source barrel axis")
		var static_pose:Transform3D=body.global_transform;var closed:Transform3D=moving.global_transform
		gun.eject_magazine();gun._hinge_angle=.72;gun.hinge.rotation.x=-.72
		check(gun.action.state=="open_empty" and moving.global_transform!=closed and body.global_transform==static_pose,side+" real imported barrels break open while stock remains still")
		check(gun.chamber_markers[0].get_parent()==gun.hinge and moving.get_parent()==gun.hinge,side+" cartridge targets and source barrels share exact moving root")
		var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
		tracker.set_input("grip",0.0);gun._poll_vr();var offer:Vector3=gun.get_reload_grab_point();hand.global_position=gun.reload_world_point(offer);tracker.set_input("grip",1.0);gun._poll_vr()
		check(gun._swipe_contact and gun.action.state=="open_empty",side+" actual support-hand tracker acquires shell pair")
		hand.global_position-=gun.global_basis*Vector3.UP*.06;gun._poll_vr();check(gun.action.state=="open_loaded" and gun.action.loaded==2,side+" original DOWN stroke inserts two finite shells")
		hand.global_position+=gun.global_basis*Vector3.UP*.07;gun._poll_vr();check(gun.action.state=="ready" and gun.action.ammo==2,side+" original UP stroke closes, no extra reload gesture")
		gun._process(.2);check(absf(gun.hinge.rotation.x)<.00001 and moving.global_basis.is_equal_approx(gun.model.global_basis),side+" imported barrel returns to closed alignment")
		check(gun._shell_pool[0].mesh.top_radius<.01 and is_equal_approx(gun._shell_pool[0].mesh.height,.07),side+" ejected shell diameter fitted while shell length and physics retained")
		gun.shutdown();gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("DOWNLOADED_DT11_081 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
