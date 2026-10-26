extends SceneTree
class Reserve extends Node:
	var reserve:=12
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":reserve}
	func consume_weapon_reserve(_slot:int,requested:int)->int:
		var count:=mini(reserve,requested);reserve-=count;return count
	func refund_weapon_reserve(_slot:int,count:int)->int:reserve+=count;return count
class GameState extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var supply:=Reserve.new();root.add_child(supply)
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.input_enabled=true;actor.head_obstructed=false;actor._grabs.clear()
		var gun=load("res://scripts/precision_rifle.gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		gun.ammo_provider=supply;gun.ammo_slot=0
		var optic=gun.optic
		var camera:Camera3D=actor.get_view_camera()
		camera.global_transform=Transform3D(optic.global_basis,optic.to_global(optic.OCULAR+Vector3(0,0,.16)))
		await physics_frame
		var view:Transform3D=camera.global_transform;var fov:=camera.fov
		optic.refresh_optic(.1)
		check(optic.active and optic.lens.visible,side+" aligned eye enables Longwatch lens")
		check(not optic.is_processing(),side+" only gun dispatches optical update once")
		check(optic.viewport.world_3d==gun.get_world_3d() and optic.viewport.get_parent()==gun,side+" bounded viewport shares world outside inert model")
		check(optic.viewport.size==Vector2i(384,384) and optic.viewport.msaa_3d==Viewport.MSAA_DISABLED and is_equal_approx(optic.RENDER_INTERVAL,1.0/30),side+" one384square render capped30Hz")
		check(optic.scope_camera.get_viewport()!=camera.get_viewport() and camera.is_current(),side+" scope does not replace main viewport camera")
		check(camera.global_transform.is_equal_approx(view) and is_equal_approx(camera.fov,fov),side+" no head pose or main projection manipulation")
		check((optic.scope_camera.cull_mask & optic.OPTIC_LAYER)==0 and (optic.scope_camera.cull_mask & optic.LIVE_WEAPON_LAYER)==0,side+" live lens and gun excluded from optical camera")
		check((camera.cull_mask & optic.OPTIC_LAYER)!=0 and (camera.cull_mask & optic.LIVE_WEAPON_LAYER)!=0,side+" main camera still sees own gun and optic")
		check(gun.magazine.layers==optic.LIVE_WEAPON_LAYER and gun.ammo_label.layers==optic.LIVE_WEAPON_LAYER,side+" live weapon numeric panel and mag on excluded layer")
		check(optic.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,side+" headless never requests GPU scope frame")
		# Simulate a render commit explicitly: headless must never pretend it drew pixels.
		gun.model.rotation.y=.08
		gun.publish_displayed_aim(Transform3D.IDENTITY)
		check(optic.simulate_displayed_frame_for_test(),side+" explicit headless optical snapshot commit")
		check(is_equal_approx((optic.LENS_RADIUS/optic._eye_relief())/tan(deg_to_rad(optic.scope_camera.fov)*.5),2),side+" actual physical lens projection gives twofold angular scale")
		var displayed:Dictionary=gun.get_displayed_optic_pose()
		var published:Transform3D=displayed.pose
		var target:=published.origin-published.basis.z*180
		check((-optic.scope_camera.global_basis.z).dot((target-optic.scope_camera.global_position).normalized())>.999999,side+" lens center matches published displayed firing ray")
		gun.model.rotation.y=.15;optic.refresh_optic(.01)
		check(gun.get_displayed_optic_pose().pose.is_equal_approx(published) and gun.get_firing_pose().is_equal_approx(published),side+" controller change between30Hzframes preserves displayed firing authority")
		check((-optic.scope_camera.global_basis.z).dot(-gun.get_shot_transform().basis.z)<.999,side+" held image does not silently adopt live changed barrel")
		check(optic.simulate_displayed_frame_for_test() and not gun.get_displayed_optic_pose().pose.is_equal_approx(published),side+" next optical render commit adopts new candidate without stale feedback")
		gun.model.rotation=Vector3.ZERO
		camera.global_position=optic.to_global(optic.OCULAR+Vector3(.10,0,.16));optic.refresh_optic(.1);check(not optic.active,side+" off-axis eye blacks tunnel")
		camera.global_position=optic.to_global(optic.OCULAR+Vector3(0,0,.7));optic.refresh_optic(.1);check(not optic.active,side+" remote eye cannot activate scope")
		camera.global_transform=view;camera.global_rotation.y=PI;optic.refresh_optic(.1);check(not optic.active,side+" wrong eye heading rejects")
		camera.global_transform=view;actor.input_enabled=false;optic.refresh_optic(.1);check(not optic.active and not optic.lens.visible,side+" paused input hides lens and disables update")
		actor.input_enabled=true;actor.head_obstructed=true;optic.refresh_optic(.1);check(not optic.active,side+" obstructed head rejects scope")
		actor.head_obstructed=false;gun.hide();optic.refresh_optic(.1);check(not optic.active,side+" holster and wheel-hidden weapon disable cost")
		gun.show();optic.refresh_optic(.1);gun.suspend_for_selection()
		check(not optic.active and optic.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,side+" production selection suspension immediately disables scope")
		check(not gun.get_displayed_optic_pose().valid,side+" selection shutdown invalidates displayed optic authority")
		var wall:=StaticBody3D.new();var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.5,.5,.04);collision.shape=box;wall.add_child(collision);root.add_child(wall)
		wall.global_position=optic.to_global(Vector3(0,.151,-.08));await physics_frame
		optic.refresh_optic(.1);check(not optic.active,side+" actual cover blocks eye-to-objective line")
		wall.free();await physics_frame
		var panel_id:int=gun.ammo_panel.get_instance_id();var optic_id:int=optic.get_instance_id()
		gun.ammo=3;gun.reload_state="ready";gun.chambered=true;supply.reserve=12;gun.eject_magazine()
		check(gun.ammo==0 and supply.reserve==15 and gun.reload_state=="needs_mag",side+" current045 partial magazine refund retained")
		gun.suspend_for_selection()
		check(gun.ammo_panel.get_instance_id()==panel_id and gun.optic.get_instance_id()==optic_id and gun.reload_state=="needs_mag",side+" switching preserves existing panel optic and reload state")
		check(gun.find_children("*","Label3D",true,false).size()==1,side+" no magnification label or weapon text added")
		var clone:Node3D=gun.model.duplicate(0);var inventory=load("res://scripts/weapon_inventory.gd").new();inventory._strip(clone)
		check(clone.find_children("*","SubViewport",true,false).is_empty() and clone.find_child("DynamicScopeLens",true,false)==null,side+" actual inventory strips live optical image and camera")
		check(clone.find_child("OriginalLongwatchTwoPowerOptic",true,false)!=null,side+" inert scope housing retained on ground clone")
		var world_layers:=true
		for part in clone.find_children("*","VisualInstance3D",true,false):
			if part.layers!=1:world_layers=false
		check(world_layers,side+" ground clone restored to world camera layer")
		clone.free();inventory.free();gun.shutdown();gun.free();await process_frame
	# Nonmagnifying authored sights have distinct geometry and no camera/image machinery.
	for kind in ["window","rings"]:
		var sight=load("res://scripts/authored_reflex_sight.gd").new();root.add_child(sight);sight.setup(kind,Transform3D(Basis.IDENTITY,Vector3(0,.12,-.15)))
		check(sight.find_children("*","Camera3D",true,false).is_empty() and sight.find_children("*","SubViewport",true,false).is_empty(),kind+" nonmagnifying helper never renders or changes projection")
		check(sight.reticle_parts.size()==(3 if kind=="rings" else 1),kind+" distinct authored reticle geometry")
		if kind=="window":check(sight.window.material_override.albedo_color.a<.05,kind+" transparent rectangular window")
		check(sight.find_children("*","Label3D",true,false).is_empty(),kind+" no gun identity or textual magnification claims")
		sight.free()
	var reference=load("res://scripts/weapon.gd").new();root.add_child(reference);reference.setup(actor,false);reference.set_process(false);reference.set_physics_process(false)
	actor.get_view_camera().global_transform=Transform3D.IDENTITY
	reference.publish_displayed_aim(Transform3D(Basis.IDENTITY,Vector3(0,0,-.6)))
	for kind in ["window","rings"]:
		var sight=load("res://scripts/authored_reflex_sight.gd").new();reference.model.add_child(sight);sight.setup(kind,Transform3D(Basis.IDENTITY,Vector3(0,0,-.4)),reference)
		check(sight.collimated_dot!=null and sight.is_processing(),kind+" owner-gun optin creates actual per-eye projected reticle")
		check(sight.process_priority==101,kind+" aim update occurs after world-reticle publication")
		for eye in [Vector3(-.01,0,0),Vector3(.01,0,0)]:
			var projection:Dictionary=sight.project_aim_to_lens(eye)
			check(projection.valid and (projection.point-eye).normalized().dot((sight.aim_target-eye).normalized())>.999999,kind+" left/right eye projection follows actual displayed aim ray")
		check(not sight.project_aim_to_lens(Vector3(.2,0,0)).valid,kind+" off-window aim clipped rather than decorative fixed dot")
		reference.publish_displayed_aim(Transform3D(Basis(Vector3.UP,.02),Vector3.ZERO));sight.update_aim()
		check(sight.aim_target.x< -1.9,kind+" target updates from displayed weapon direction")
		sight.free();reference.publish_displayed_aim(Transform3D(Basis.IDENTITY,Vector3(0,0,-.6)))
	var cover:=StaticBody3D.new();var cs:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1,1,.1);cs.shape=shape;cover.position=Vector3(0,0,-2);cover.add_child(cs);root.add_child(cover);await physics_frame
	var close_sight=load("res://scripts/authored_reflex_sight.gd").new();reference.model.add_child(close_sight);close_sight.setup("window",Transform3D(Basis.IDENTITY,Vector3(0,0,-.4)),reference)
	check(absf(close_sight.aim_target.z+1.95)<.001,"reflex projection converges on actual close ballistic surface")
	close_sight.free();cover.free();await physics_frame
	reference.shutdown();reference.free()
	actor.input_enabled=true;actor.head_obstructed=false;actor.get_view_camera().global_transform=Transform3D.IDENTITY
	var desktop=load("res://scripts/precision_rifle.gd").new();root.add_child(desktop);desktop.setup(actor,false);desktop.set_process(false);desktop.set_physics_process(false)
	var before:Transform3D=actor.get_view_camera().global_transform
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;Input.parse_input_event(event);Input.flush_buffered_events()
	desktop._process(0);desktop.optic.refresh_optic(.1)
	check(desktop.optic.active and actor.get_view_camera().global_transform.is_equal_approx(before),"desktop RMB aligns rifle without moving head")
	event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=false;Input.parse_input_event(event);Input.flush_buffered_events();desktop._process(0)
	check(not desktop.optic.active,"desktop RMB release disables scope")
	desktop.shutdown();desktop.free();supply.free();actor.free();await create_timer(.2).timeout
	# Actual rack plus root's real world-reticle hook must retain the30Hz snapshot.
	var tracked=load("res://scripts/player.gd").new();root.add_child(tracked);tracked.setup(false);tracked.xr_enabled=true;tracked.tracking_available=true;tracked.set_process(false);tracked.set_physics_process(false)
	var trackers:Array[XRControllerTracker]=[]
	for hand in [tracked.left_hand,tracked.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="optic046_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("trigger",0.0);tracker.set_input("grip",0.0);tracker.set_input("primary",Vector2.ZERO);trackers.append(tracker)
	await physics_frame;tracked.update_hand_input_rearm(.1)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(tracked);rack.set_process(false);rack.selected=5;rack._apply_selection()
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for index in [0,3]:
		var kind:String="window" if index==0 else "rings"
		var helper=rack.weapons[index].model.find_child("AuthoredNonmagnifying_"+kind,true,false)
		check(helper!=null and helper.gun==rack.weapons[index] and helper.collimated_dot!=null,"actual rack authored nonmagnifying "+kind+" assignment")
		check(rack.weapons[index].find_children("*","Camera3D",true,false).is_empty() and rack.weapons[index].find_children("*","SubViewport",true,false).is_empty(),"actual rack "+kind+" has no magnifier/camera")
		var clone:Node3D=rack.weapons[index].model.duplicate(0);var inventory=load("res://scripts/weapon_inventory.gd").new();inventory._strip(clone)
		check(clone.find_child("DynamicReflexReticle",true,false)==null and clone.find_child("AuthoredNonmagnifying_"+kind,true,false)!=null,"actual "+kind+" ground clone strips projected live dot and retains housing")
		clone.free();inventory.free()
	var scoped=rack.weapons[5];var eye:Camera3D=tracked.get_view_camera()
	eye.global_transform=Transform3D(scoped.optic.global_basis,scoped.optic.to_global(scoped.optic.OCULAR+Vector3(0,0,.16)))
	await physics_frame
	check(scoped.optic.simulate_displayed_frame_for_test(),"actual rack Longwatch commits explicit test optical frame")
	var displayed:Transform3D=scoped.get_displayed_optic_pose().pose
	scoped.model.rotation.y+=.08
	var state:=GameState.new();root.add_child(state)
	var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(tracked,rack,state);reticle.set_process(false);reticle.update_reticle()
	check(reticle.visible and reticle.ray_direction.dot(-displayed.basis.z)>.999999,"actual root world-reticle hook honors held optical frame")
	var excluded_ui:=true
	for part in reticle.find_children("*","MeshInstance3D",true,false):
		if part.layers & scoped.optic.scope_camera.cull_mask:excluded_ui=false
	check(excluded_ui,"actual root layer20 world reticle excluded from scope image")
	check(scoped.get_firing_pose().is_equal_approx(displayed),"world-reticle publication cannot override scope with changed live controller")
	var fired:Array[Vector3]=[];scoped.shot.connect(func(_o:Vector3,d:Vector3,_damage:float):fired.append(d));scoped.cooldown=0;scoped.fire()
	check(fired.size()==1 and fired[0].dot(-displayed.basis.z)>.999999,"actual precision damaging shot follows last displayed optical ray")
	check(scoped.ammo==4 and not scoped.chambered and scoped.reload_state=="needs_bolt","scope integration retains actual physical bolt and ammo state")
	reticle.free();state.free();rack.shutdown();rack.free();tracked.free()
	for tracker in trackers:XRServer.remove_tracker(tracker)
	await create_timer(.2).timeout
	print("OPTICS_046 checks=",checks," failures=",failures," headset_tested=false rendering_tested=false")
	quit(failures)

