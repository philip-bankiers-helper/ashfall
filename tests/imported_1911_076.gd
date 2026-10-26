extends SceneTree
class Gun extends "res://scripts/catalog_firearm.gd":
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
	ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="asset076_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side
		var gun:=Gun.new();gun.profile_id="1911";gun.mode="semi";root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
		gun._desktop_signals=true
		check(gun.get_meta("imported_tactical_1911",false),side+" actual imported asset active")
		var body:MeshInstance3D=gun.model.get_node("ImportedTactical1911")
		check(triangles(body.mesh)+triangles(gun.magazine.mesh)+triangles(gun.bolt.mesh)==3888,side+" every original source triangle retained exactly once")
		check(triangles(gun.magazine.mesh)==106 and triangles(gun.bolt.mesh)==1103,side+" existing disconnected mag and slide extracted")
		check(body.mesh.surface_get_material(0) is StandardMaterial3D,side+" textured source material retained")
		check(gun.magazine.mesh==gun.loose_magazine.mesh and gun.magazine.mesh==gun.hip_source.get_child(0).mesh,side+" seated held and offered mag use same imported shape")
		check(gun.magazine.position.distance_to(gun.magazine_home)<.00001 and absf(gun.get_magazine_insert_point().z-gun.magazine_home.z)<.00001,side+" actual mag and physical well agree")
		check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,.045,-.42)))<.00001,side+" existing ballistic origin preserved")
		check(gun.fire_interval==.115 and gun.damage==45.0,side+" imported asset does not alter base handling before arsenal tuning")
		var local_forward:Vector3=gun.model.to_local(gun.get_shot_transform().origin)
		var bounds:AABB=body.mesh.get_aabb().merge(gun.bolt.transform*gun.bolt.mesh.get_aabb())
		check(absf(bounds.position.z-local_forward.z)<.012,side+" barrel ends at calibrated existing muzzle")
		var original_y:float=gun.bolt.position.y;gun._carrier_time=.0475;gun._process(0)
		check(absf(gun.bolt.position.z+.065)<.00001 and gun.bolt.position.y==original_y,side+" extracted slide actually cycles along bore")
		gun.eject_magazine();check(gun.reload_state=="needs_mag",side+" original magazine eject state works")
		var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
		tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);gun._poll_vr()
		hand.global_position=gun.reload_world_point(gun.get_magazine_offer_point());tracker.set_input("grip",1.0);gun._poll_vr()
		check(gun.reload_state=="held_mag",side+" actual tracker grip picks up imported mag")
		hand.global_position=gun.reload_world_point(gun.get_magazine_insert_point());gun._poll_vr()
		check(gun.reload_state=="needs_rack",side+" actual upward insert accepts imported mag")
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(Vector3(-.05,.064,-.10));tracker.set_input("grip",1.0);gun._poll_vr()
		hand.global_position+=gun.global_basis*Vector3.BACK*.10;gun._poll_vr()
		check(gun.reload_state=="ready" and gun.ammo>0,side+" actual rack gesture chambers imported1911")
		check(gun.magazine.mesh==gun._debris[gun.CASING_POOL_SIZE].mesh,side+" spent debris uses actual imported mag")
		gun.shutdown();gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("IMPORTED_1911_076 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
