extends SceneTree
## Real loaded/offer/carry meshes and Main/controller polling, including lateral reach at the visible compact well.
var checks:=0
var failures:=0
var trackers:Dictionary={}
var game
var actor
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func mesh_parts(node:Node)->Array[String]:
	var parts:Array[String]=[]
	if node is MeshInstance3D and node.mesh!=null:
		var finish=node.material_override
		if finish is StandardMaterial3D and not finish.emission_enabled:
			parts.append(str(node.mesh.get_aabb().size)+"|"+str(finish.albedo_color))
	for child in node.get_children():parts.append_array(mesh_parts(child))
	parts.sort();return parts
func sample(gun,point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip)
	actor._objective_grip_frame=-1;actor.update_objective_grips();gun._poll_vr()
func run()->void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	game.process_mode=Node.PROCESS_MODE_DISABLED;game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	actor=game.player;actor.xr_enabled=true;actor.tracking_available=true;actor.input_enabled=true;actor.global_position=Vector3(1000,2,1000)
	actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset()
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="alignment056_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);tracker.set_input("primary_click",false);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	var rack=game.weapon
	for index in [0,17,18,19,20,21,23,24,25]:
		var gun=rack.weapons[index]
		check(mesh_parts(gun.magazine)==mesh_parts(gun.hip_source),gun.profile_id+" offered magazine matches loaded geometry/material parts")
		check(mesh_parts(gun.magazine)==mesh_parts(gun.loose_magazine),gun.profile_id+" carried magazine matches loaded geometry/material parts")
	var bullpup=rack.weapons[23];bullpup.reset_weapon();bullpup.eject_magazine();bullpup.grab_magazine();bullpup._process(0)
	check(bullpup.guide.position.distance_to(bullpup.get_reload_zones()[0].position)<.001,"RFB seated-mag guide stays at actual rear well")
	bullpup.insert_magazine();bullpup._process(0)
	check(bullpup.guide.position.distance_to(bullpup.get_reload_zones()[0].position)<.001,"RFB charging guide shares the actual right-side handle target")
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;rack._refresh_hands()
		for index in [18,19,20]:
			game.weapon_inventory.owned.assign([index]);rack.selected=index;rack.is_holstered=false;rack.is_selecting=false;rack._apply_selection();rack._draw_delay=0
			var gun=rack.weapons[index];gun.reset_weapon();rack.reserves.pistol=1000;rack.reserves.rifle=1000;gun.ammo=0;gun.eject_magazine();gun._process(0)
			gun.global_transform=Transform3D(Basis.from_euler(Vector3(.1,.6,-.2)),actor.global_position+Vector3(0,1.2,-.5))
			var well:Vector3=gun.magazine_home
			var offer:Vector3=gun.reload_local_point(gun.get_offered_magazine_transform().origin)
			var label:String=dominance+" "+gun.profile_id
			check(Vector2(offer.x-well.x,offer.z-well.z).length()<.005,label+" offered UP path is directly below visible magazine well")
			check(absf(gun.insertion_arrow.position.z-well.z)<.005,label+" insertion arrow aligns with visible well")
			check(gun.get_reload_zones()[0].position.distance_to(offer)<.001,label+" arbitration and actual visible offer share one target")
			var hand_offer:=Vector3(.10,offer.y,well.z)
			sample(gun,hand_offer,0);sample(gun,hand_offer,1)
			check(gun.reload_state=="held_mag",label+" fresh grip at visible offered magazine acquires with lateral allowance")
			gun._process(0)
			check(absf(gun.guide.position.z-well.z)<.005,label+" held-mag target is the actual well")
			gun.global_transform=Transform3D(Basis.from_euler(Vector3(.1,.6,-.2)),actor.global_position+Vector3(0,1.2,-.5))
			sample(gun,Vector3(.10,well.y,well.z),1)
			check(gun.reload_state=="needs_rack" and gun.ammo==0 and gun._seated_rounds==gun.magazine_size,label+" straight UP at visible well seats finite rounds but still requires BACK")
			var funded:int=gun.get_loaded_rounds()+gun.reserve_rounds()
			var handle:=Vector3(-.05,.064,-.10)
			sample(gun,handle,1);sample(gun,handle+Vector3.BACK*.08,1)
			check(gun.reload_state=="ready" and gun.ammo==gun.magazine_size and gun.get_loaded_rounds()+gun.reserve_rounds()==funded,label+" unchanged continuous-grip BACK completes funded reload")
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.2).timeout
	print("RELOAD_ALIGNMENT_056 checks=",checks," failures=",failures," actual_main_polling=true physical_acceptance=false");quit(failures)
