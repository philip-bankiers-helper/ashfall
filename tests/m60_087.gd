extends SceneTree
var checks:=0
var failures:=0
var actor
var rack
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func triangles(mesh:Mesh)->int:
	var count:=0
	for surface in mesh.get_surface_count():count+=mesh.surface_get_array_len(surface)/3
	return count
func poll(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip)
	gun._poll_vr()
func stroke(gun,travel:Vector3)->void:
	var point:Vector3=gun.get_reload_grab_point()
	poll(gun,point,0);poll(gun,point,1);poll(gun,point+travel,1)
func run()->void:
	ProjectSettings.set_setting("ashfall/lightweight_models",false)
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="m60_087_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		for key in ["grip","trigger"]:t.set_input(key,0.0)
		t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	var gun=rack.weapons[8]
	check(gun.get_meta("articulated_m60_087",false),"game-ready M60 with fitted donor reload parts installed")
	check(gun.model.scale.is_equal_approx(Vector3.ONE),"accepted M60 root scale retained")
	var cover:MeshInstance3D=gun.cover.get_node("DownloadedCover085")
	check(triangles(cover.mesh)==9457,"complete 9457-triangle authored cover assembly, no receiver region cut")
	check(triangles(gun.charging_handle.mesh)==470,"connected source charging knob is actual moving contact")
	check(triangles(gun.belt_box.mesh)==3774,"complete author-rigged donor box and lid")
	var belt:MeshInstance3D=gun.belt.get_node("DownloadedBelt085")
	check(triangles(belt.mesh)==3392,"all eight donor linked rounds retained")
	check(belt.rotation.is_zero_approx(),"donor cartridges retain forward bore orientation")
	var body:MeshInstance3D=gun.model.get_node("DownloadedBody085")
	check(is_equal_approx(body.mesh.get_aabb().size.z,1.39879070856),"actual fitted barrel-to-stock extent matches accepted 086 length")
	var fixed:Transform3D=body.transform
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands();rack.selected=8;rack.is_holstered=false;rack.is_selecting=false;rack._apply_selection()
		for hand in [gun.left_hand,gun.right_hand]:trackers[hand].set_input("grip",0.0);trackers[hand].set_input("trigger",0.0)
		actor.update_hand_input_rearm(.2);gun.reset_weapon();gun.ammo=37;gun.seated=37
		var budget:int=gun.ammo+gun.reserve_rounds()
		check(gun.begin_reload() and gun.reload_state=="box_removed",side+" partial reload refunds and opens")
		gun._process(0);check(gun.cover.rotation.x< -1.3 and body.transform==fixed,side+" complete cover rotates while receiver remains fixed")
		check(gun.offered_box.visible and not gun.belt_box.visible and not gun.belt.visible,side+" empty receiver hides box/belt and offers replacement")
		poll(gun,gun.get_reload_grab_point(),0);poll(gun,gun.get_reload_grab_point(),1)
		check(gun.reload_state=="holding_box",side+" actual XR grip acquires donor box")
		poll(gun,gun.get_box_seat(),1)
		check(gun.reload_state=="needs_feed",side+" actual UP inserts box at fitted seat")
		stroke(gun,Vector3.RIGHT*gun.feed_direction()*.081)
		check(gun.reload_state=="box_seated" and gun.belt_fed,side+" actual mirrored ACROSS feeds belt")
		stroke(gun,Vector3.DOWN*.08)
		check(gun.reload_state=="needs_charge" and is_zero_approx(gun.cover.rotation.x),side+" actual DOWN closes whole cover")
		var handle:Vector3=gun.get_handle_point()
		poll(gun,handle,0);poll(gun,handle,1);poll(gun,handle+Vector3.BACK*.055,1)
		check(gun.charging_handle.position.z>handle.z+.05,side+" actual charging mesh follows partial rearward pull")
		poll(gun,handle+Vector3.BACK*.12,1)
		check(gun.reload_state=="ready" and gun.ammo==gun.magazine_size,side+" actual BACK completes ready reload at unchanged catalog capacity")
		check(gun.ammo+gun.reserve_rounds()==budget,side+" physical reload conserves exact ammunition")
		check(gun.charging_handle.position.is_equal_approx(gun.get_handle_point()),side+" handle returns to fitted home")
		check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,.04,-.91)))<.00001,side+" original muzzle ray datum preserved")
		poll(gun,gun.get_handle_point(),0)
	gun.begin_reload();gun.grab_magazine();gun.suspend_for_selection()
	check(gun.reload_state=="box_removed", "switch interruption safely returns unseated offered box")
	for t in trackers.values():XRServer.remove_tracker(t)
	trackers.clear();rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	print("M60_087 checks=",checks," failures=",failures," synthetic=true native_rendered=false headset_tested=false")
	quit(failures)
