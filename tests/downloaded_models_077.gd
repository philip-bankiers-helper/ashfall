extends SceneTree
class Catalog extends "res://scripts/catalog_firearm.gd":
	func _vr_active()->bool:return true
class Pistol extends "res://scripts/pistol.gd":
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
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="asset077_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side
		for id in ["px4","tec9","mp9","fal","rfb","mp5"]:
			actor.left_hand_reserved=false
			for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
			var gun=Pistol.new() if id=="px4" else Catalog.new()
			if id!="px4":gun.profile_id=id
			root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
			gun._desktop_signals=true
			var label:String=side+" "+id+" "
			var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_"+id+"/asset-provenance.json"))
			check(gun.get_meta("downloaded_model_077","")==id,label+"actual downloaded model active")
			var body:MeshInstance3D=gun.model.get_node("DownloadedBody077")
			var count:=triangles(body.mesh)+triangles(gun.magazine.mesh)
			if data.moving_triangles>0:count+=triangles(gun.bolt.mesh)
			check(count==int(data.source_triangles),label+"all source triangles partitioned exactly once")
			check(triangles(gun.magazine.mesh)==int(data.magazine_triangles),label+"magazine and floorplate extracted")
			check(body.mesh.surface_get_material(0) is StandardMaterial3D and body.mesh.surface_get_material(0).albedo_texture!=null,label+"actual source texture bound")
			check(gun.magazine.mesh==gun.loose_magazine.mesh and gun.magazine.mesh==gun.hip_source.get_child(0).mesh,label+"all three magazine states share imported geometry")
			var home:Vector3=gun.get_meta("download_magazine_home_077")
			check(gun.magazine.position.distance_to(home)<.00001 and absf(gun.get_magazine_insert_point().z-home.z)<.00001,label+"seated magazine and physical well agree")
			var v:Array=data.muzzle;var muzzle:=Vector3(v[0],v[1],v[2])
			check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(muzzle))<.00001,label+"unchanged ballistic origin")
			check(gun.get_shot_transform().basis.get_scale().is_equal_approx(Vector3.ONE),label+"unit direction with no hidden scaling")
			check(not gun.firing_carrier.visible,label+"old carrier hidden from downloaded body")
			check(body.mesh.get_aabb().size.length()<1.5 and body.mesh.get_aabb().position.is_finite(),label+"finite metre-scale geometry")
			gun._process(0)
			check(body.visible and gun.magazine.visible,label+"import survives actual rendered-frame update")
			if id=="px4":
				gun._carrier_time=.0475;gun._process(0)
				check(absf(gun.bolt.position.z+.065)<.00001,label+"separate slide cycles with real firing clock")
			gun.eject_magazine();check(gun.reload_state=="needs_mag" and not gun.magazine.visible,label+"eject removes actual seated magazine")
			var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
			tracker.set_input("grip",0.0);gun._poll_vr()
			hand.global_position=gun.reload_world_point(gun.get_magazine_offer_point());tracker.set_input("grip",1.0);gun._poll_vr()
			check(gun.reload_state=="held_mag",label+"actual tracker grip acquires new magazine")
			hand.global_position=gun.reload_world_point(gun.get_magazine_insert_point());gun._poll_vr()
			check(gun.reload_state=="needs_rack",label+"actual upward insertion seats new magazine")
			tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(Vector3(.065,.055,-.10) if id=="rfb" else Vector3(-.05,.064,-.10));tracker.set_input("grip",1.0);gun._poll_vr()
			hand.global_position+=gun.global_basis*Vector3.BACK*.10;gun._poll_vr()
			check(gun.reload_state=="ready" and gun.ammo>0,label+"actual tracker rack chambers weapon")
			check(gun.magazine.mesh==gun._debris[gun.CASING_POOL_SIZE].mesh,label+"spent magazine uses imported shape")
			gun.reset_weapon();check(gun.reload_state=="ready" and is_equal_approx(gun.bolt.position.z,-.10),label+"reset restores moving part home")
			gun.shutdown();gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("DOWNLOADED_MODELS_077 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
