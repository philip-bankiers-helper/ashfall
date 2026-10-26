extends SceneTree
class AK extends "res://scripts/catalog_firearm.gd":
	func _vr_active()->bool:return true
class PDW extends "res://scripts/top_feed_pdw.gd":
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
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="asset078_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	for id in ["akm","p90"]:
		var gun=AK.new() if id=="akm" else PDW.new()
		if id=="akm":gun.profile_id="akm"
		root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		check(not gun.has_meta("downloaded_model_077"),id+" original fallback selectable")
		check(not ResourceLoader.has_cached("res://assets/models/download_"+id+"/model.glb"),id+" fallback does not load new GLB")
		gun.shutdown();gun.free()
	ProjectSettings.set_setting("ashfall/lightweight_models",false)
	for side in ["right","left"]:
		actor.dominant_hand=side
		for id in ["akm","p90"]:
			actor.left_hand_reserved=false
			for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
			var gun=AK.new() if id=="akm" else PDW.new()
			if id=="akm":gun.profile_id="akm"
			root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
			gun._desktop_signals=true
			var label:String=side+" "+id+" ";var folder:String="res://assets/models/download_"+id+"/"
			var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"asset-provenance.json"));var body:MeshInstance3D=gun.model.get_node("DownloadedBody077")
			check(gun.get_meta("downloaded_model_077","")==id,label+"new model active")
			var visible_triangles:=triangles(body.mesh)+triangles(gun.magazine.mesh)+(triangles(gun.bolt.mesh) if data.moving_triangles>0 else 0)
			check(visible_triangles==int(data.visible_source_triangles),label+"all intended source triangles present exactly once")
			check(visible_triangles+int(data.omitted_triangles)==int(data.source_triangles),label+"visible and excluded source accounting exact")
			check(int(data.omitted_triangles)==(204 if id=="akm" else 0),label+"only AK duplicate animation spare omitted")
			check(body.mesh.get_aabb().size.x<.15 and body.mesh.get_aabb().size.length()<1.5,label+"no floating off-weapon spare or scale explosion")
			check(triangles(gun.magazine.mesh)==(204 if id=="akm" else 4612),label+"correct disconnected magazine selected")
			check(gun.magazine.mesh==gun.loose_magazine.mesh and gun.hip_source.get_child(0).mesh==gun.magazine.mesh,label+"offered held seated use same new magazine")
			var m:Array=data.muzzle;check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(m[0],m[1],m[2])))<.00001,label+"existing ballistic origin retained")
			if id=="akm":check(gun.get_meta("ring_sight").visible,label+"accepted three-depth ring sight remains visible")
			else:check(gun.get_top_seat().distance_to(gun.magazine.position)<.00001 and absf(gun.get_top_offer().z-gun.get_top_seat().z-.17-.0508/gun.visual_model_scale())<.00001,label+"actual top-mag fit drives offer and seat without changing forward stroke")
			gun.eject_magazine();check(gun.reload_state=="needs_mag" and not gun.magazine.visible,label+"existing eject state removes new mag")
			var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
			tracker.set_input("grip",0.0);gun._poll_vr()
			var offer:Vector3=gun.get_top_offer() if id=="p90" else gun.get_magazine_offer_point()
			hand.global_position=gun.reload_world_point(offer);tracker.set_input("grip",1.0);gun._poll_vr();check(gun.reload_state=="held_mag",label+"actual tracker acquires new magazine")
			if id=="p90":
				hand.global_position=gun.reload_world_point(offer+Vector3.UP*.16);gun._poll_vr();check(gun.reload_state=="held_mag",label+"upward gesture alone cannot bypass forward insertion")
			hand.global_position=gun.reload_world_point(gun.get_top_seat() if id=="p90" else gun.get_magazine_insert_point());gun._poll_vr()
			check(gun.reload_state=="needs_rack",label+"correct actual tracker insertion seats new magazine")
			tracker.set_input("grip",0.0);gun._poll_vr()
			if id=="akm":
				var p:Array=data.moving_grip_center_model;hand.global_position=gun.model.to_global(Vector3(p[0],p[1],p[2]))
			else:hand.global_position=gun.reload_world_point(gun.get_charge_point())
			tracker.set_input("grip",1.0);gun._poll_vr();hand.global_position+=gun.global_basis*Vector3.BACK*.10;gun._poll_vr()
			check(gun.reload_state=="ready" and gun.ammo>0,label+"rack at visible handle chambers weapon")
			gun.reset_weapon();var home:Vector3=gun.get_meta("download_magazine_home_077");check(gun.magazine.position.distance_to(home)<.00001,label+"reset restores actual fitted magazine center")
			gun.shutdown();gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("DOWNLOADED_NEXT_078 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
