extends SceneTree
class Gun extends "res://scripts/auto_shotgun.gd":
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
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="m10asset081_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var fallback:=Gun.new();root.add_child(fallback);fallback.setup(actor,false);fallback.set_process(false);fallback.set_physics_process(false)
	check(not fallback.has_meta("downloaded_model_077") and not ResourceLoader.has_cached("res://assets/models/download_m1014/model.glb"),"authored M1014 fallback stays lazy")
	fallback.shutdown();fallback.free();ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_m1014/asset-provenance.json"))
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
		var gun:=Gun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
		gun._desktop_signals=true;preload("res://scripts/arsenal_data.gd").apply(gun,9);gun._process(0)
		var body:MeshInstance3D=gun.model.get_node("DownloadedM1014Body081")
		check(gun.get_meta("downloaded_model_077","")=="m1014" and triangles(body.mesh)+triangles(gun.bolt.mesh)==79142,side+" exact imported body/bolt accounting")
		check(triangles(gun.bolt.mesh)==2548 and gun.bolt.material_override==null,side+" original textured bolt/knob separated")
		check(gun.magazine_size==6 and absf(gun.fire_interval-.29071666666667395)<.0000001,side+" accepted six-round capacity and faster recorded cadence preserved")
		check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,.045,-.77)))<.00001,side+" unchanged firing origin and unit model scale")
		check(gun.model.scale.is_equal_approx(Vector3.ONE) and gun.bolt.scale.x==(-1 if side=="left" else 1),side+" mirrored source bolt follows existing handed target")
		gun.eject_magazine();check(gun.reload_state=="needs_mag",side+" original reload begins with shell pack")
		var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(gun.get_reload_grab_point());tracker.set_input("grip",1.0);gun._poll_vr()
		check(gun._contact=="load",side+" actual tracked support hand grabs pack")
		hand.global_position+=gun.global_basis*Vector3.UP*.15;gun._poll_vr();check(gun.reload_state=="needs_rack" and gun._seated_rounds==6 and gun.ammo==0,side+" original UP seats six shells before chambering")
		tracker.set_input("grip",0.0);gun._poll_vr();var p:Array=data.actual_bolt_contact;var knob:=Vector3(p[0],p[1],p[2]);if side=="left":knob.x=-knob.x
		hand.global_position=gun.model.to_global(knob);tracker.set_input("grip",1.0);gun._poll_vr();check(gun._contact=="charge",side+" actual imported knob is within physical charging target")
		hand.global_position+=gun.global_basis*Vector3.BACK*.05;gun._poll_vr();check(gun.bolt.position.z>gun.HANDLE.z+.04 and gun.reload_state=="needs_rack",side+" source bolt follows partial pull")
		hand.global_position+=gun.global_basis*Vector3.BACK*.05;gun._poll_vr();check(gun.reload_state=="ready" and gun.ammo==6,side+" original full BACK chambers")
		tracker.set_input("grip",0.0);gun._poll_vr();gun._process(0);var rest:Vector3=gun.bolt.position;gun.cooldown=0;gun.fire();gun._process(.045)
		check(gun.ammo==5 and gun.bolt.position.z>rest.z+.02,side+" firing cycles imported bolt using original visual clock")
		gun._process(.2);check(gun.bolt.position.distance_to(rest)<.00001,side+" visible bolt returns without altered firing/reload state")
		gun.shutdown();gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("DOWNLOADED_M1014_081 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
