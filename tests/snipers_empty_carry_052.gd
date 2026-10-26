extends SceneTree
class TrackedAWP extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for index in rack.ACTIVE_WEAPON_INDICES:
		if index in [14,15,16,26,28]:continue # Throw/release depletion covered by explosives_050, not firearm fire().
		rack.selected=index;rack.is_holstered=false;rack._apply_selection();var gun=rack.weapons[index]
		gun.cooldown=0;gun._requires_trigger_release=false
		if index==3:gun._burst_armed=true
		if index==1:gun.action.ammo=1;gun.ammo=1;gun._semi_release=true
		elif index==7:gun.chambers.fill("empty");gun.chambers[0]="live";gun._sync();gun._semi_armed=true
		elif index in [11,12]:
			for child in gun.guns:child.ammo=1;child.cooldown=0;child._requires_trigger_release=false;child._semi_armed=true
		else:gun.ammo=1
		gun.fire()
		if index==1:check(gun.ammo==0 and gun.action.state=="open_empty" and gun.get_reload_grab_point()!=Vector3.ZERO,"DT11 empty automatically breaks open and exposes DOWN shell-insert gesture without thumb input")
		elif index in [11,12]:check(gun.guns[0].ammo==0 and gun.guns[0].reload_state=="needs_mag","paired hand%d enters upward-flick ready automatically"%index)
		else:check(gun.ammo==0 and gun.reload_state in ["needs_mag","remove_top","cylinder_open","box_removed"],"type%d automatic empty magazine/reload-ready state"%index)
	var awp=rack.weapons[5];var spr=rack.weapons[13]
	check(awp!=spr and awp.optic.get_script().resource_path.ends_with("awp_scope.gd") and spr.optic.get_script().resource_path.ends_with("spr_scope.gd"),"AWP and SPR are separate persistent weapons with distinct optics")
	awp.visible=true;awp.reload_state="needs_mag";awp._process(0)
	check(awp.insertion_arrow.visible,"AWP empty magazine UP arrow visible")
	awp.reload_state="needs_bolt"
	for phase in ["back"]:
		awp.bolt_phase=phase;awp._process(0)
		var direction:Vector3={"lift":Vector3.UP,"back":Vector3.BACK,"forward":Vector3.FORWARD,"lower":Vector3.DOWN}[phase]
		check(awp.charging_arrow.visible and awp.charging_arrow.basis.z.dot(direction)>.999,"AWP bolt phase arrow "+phase)
	awp.optic._commit_displayed_frame()
	var awp_fov:float=awp.optic.scope_camera.fov
	var awp_scale:float=(awp.optic.VIEW_RADIUS/awp.optic.VIEW_DISTANCE)/tan(deg_to_rad(awp_fov)*.5)
	check(is_equal_approx(awp_scale,4.0),"AWP central aperture projects4x angular scale analytically")
	check((spr.optic.lens.mesh as QuadMesh).size==Vector2(.11,.065) and spr.optic.viewport.size==Vector2i(520,307),"SPR broad rectangular aperture and matching viewport aspect")
	spr.camera.global_transform=Transform3D(Basis.IDENTITY,spr.optic.lens.global_position+spr.optic.lens.global_basis.z*.16)
	spr.optic._commit_displayed_frame()
	var apparent:float=(.065*.5/.16)/tan(deg_to_rad(spr.optic.scope_camera.fov)*.5)
	check(is_equal_approx(apparent,2.0),"SPR aperture uses its height for analytical 2x apparent magnification")
	check(is_equal_approx(actor.GRAVITY,18.0*.9),"gravity reduced exactly10 percent to16.2")
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="awpsupport048_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.left_hand_reserved=false
		var tracked:=TrackedAWP.new();root.add_child(tracked);tracked.setup(actor,false);tracked.set_process(false);tracked.set_physics_process(false)
		tracked.right_hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,1.4,-.3));tracked._process(0)
		tracked.left_hand.global_position=tracked.to_global(tracked.FOREGRIP_POINT);trackers[tracked.left_hand].set_input("grip",0.0);tracked._process(0)
		check(not tracked.optic.active and not tracked.optic.lens.visible,side+" AWP black surround inactive without support grip")
		trackers[tracked.left_hand].set_input("grip",1.0);tracked._process(0)
		check(tracked.supported and tracked.optic.active and tracked.optic.lens.visible and tracked.optic.lens.get_parent()==tracked.camera,side+" actual synthetic offhand grip activates central AWP scope and surround")
		trackers[tracked.left_hand].set_input("grip",0.0);tracked._process(0)
		check(not tracked.optic.active and not tracked.optic.lens.visible,side+" offhand release removes AWP black surround immediately")
		tracked.shutdown();tracked.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	rack.shutdown();await create_timer(.2).timeout;rack.free();actor.free();await create_timer(.2).timeout # Let deferred AudioServer playback releases complete after freeing the rack.
	print("SNIPERS_EMPTY_048 checks=",checks," failures=",failures," gpu_rendered=false shader_gpu_compiled=false headset_tested=false")
	quit(failures)

