extends SceneTree
class Gun extends "res://scripts/revolver.gd":
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
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="magasset081_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var fallback:=Gun.new();root.add_child(fallback);fallback.setup(actor,false);fallback.set_process(false);fallback.set_physics_process(false)
	check(not fallback.has_meta("downloaded_magnum_081") and not ResourceLoader.has_cached("res://assets/models/download_magnum/model.glb"),"authored Magnum fallback stays lazy")
	fallback.shutdown();fallback.free();ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_magnum/asset-provenance.json"))
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
		var gun:=Gun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
		gun._desktop_signals=true
		var body:MeshInstance3D=gun.model.get_node("DownloadedMagnumBody081");var drum:Node3D=gun.cylinder.get_node("FittedSevenChamberDrum081")
		check(gun.has_meta("downloaded_magnum_081") and triangles(body.mesh)==int(data.visible_source_triangles),side+" imported frame/barrel/grip active")
		check(int(data.source_triangles)==6372 and int(data.visible_source_triangles)+int(data.omitted_triangles)==6372 and int(data.omitted_triangles)==990,side+" six-shot drum/speedloader omission precisely accounted")
		check(gun.CAPACITY==7 and gun.ammo==7 and gun.cartridges.size()==7 and gun.offered_rounds.size()==7,side+" seven functional chambers preserved")
		check(gun.cartridges[0].get_parent()==drum and drum.get_parent()==gun.cylinder,side+" live cartridges and fitted drum share real moving cylinder")
		check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,.065,-.392)))<.00001 and gun.model.scale.is_equal_approx(Vector3.ONE*.84),side+" scaled ballistic datum and requested0.8model scale")
		check(gun.sight_front.is_visible_in_tree() and gun.sight_rear.is_visible_in_tree(),side+" existing geometrically zeroed sight references retained")
		var static_pose:Transform3D=body.global_transform;var closed:Transform3D=gun.cartridges[0].global_transform
		gun.eject_magazine();check(is_equal_approx(gun.cylinder.position.x,.10 if side=="left" else -.10) and gun.cartridges[0].global_transform!=closed and body.global_transform==static_pose,side+" seven-round cylinder opens to correct side, frame remains still")
		gun.chambers.fill("empty");gun._sync();check(gun.ammo==0 and not gun.cartridges[0].visible,side+" fitted live-round visibility follows actual chamber state")
		var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(gun.get_reload_grab_point());tracker.set_input("grip",1.0);gun._poll_vr()
		check(gun._contact=="load",side+" real support-hand tracker acquires seven-round offer")
		hand.global_position+=gun.global_basis*Vector3.FORWARD*.17;gun._poll_vr();check(gun.reload_state=="cylinder_loaded" and gun.ammo==7 and gun.cartridges[6].visible,side+" existing forward load fills seven individual chambers")
		hand.global_position+=gun.global_basis*Vector3.UP*.065;gun._poll_vr();check(gun.reload_state=="ready" and gun.cylinder.position==Vector3.ZERO and gun.cartridges[0].global_transform.is_equal_approx(closed),side+" continuous UP stroke closes fitted cylinder")
		tracker.set_input("grip",0.0);gun._poll_vr();gun.cooldown=0;gun.fire();check(gun.ammo==6 and not gun.cartridges[0].visible and gun.cartridges[1].visible,side+" firing removes only corresponding live cartridge")
		gun.reset_weapon();check(gun.ammo==7 and gun.cartridges[0].visible and body.visible,side+" reset restores seven rounds and imported body")
		gun.shutdown();gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("DOWNLOADED_MAGNUM_081 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
