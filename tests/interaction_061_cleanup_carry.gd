extends SceneTree
##056 carry: all28 behavior assertions unchanged; only a post-free teardown barrier is added.
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
	check(rack.weapons.size()==30 and not rack.has_weapon(4) and rack.has_weapon(12) and rack.has_weapon(13),"retired pump excluded; dual Matadors and separate SPR in active lineup")
	var forwarded:Array[int]=[0,0]
	rack.shot.connect(func(_o,_d,_p):forwarded[0]+=1)
	rack.pellet_shot.connect(func(_o,_d,_p):forwarded[1]+=1)
	rack.select_weapon(11);rack.weapons[11]._process(0);rack.weapons[11].guns[0].cooldown=0;rack.weapons[11].guns[0].fire()
	rack.select_weapon(12);rack.weapons[12]._process(0);rack.weapons[12].guns[0].cooldown=0;rack.weapons[12].guns[0].fire()
	check(forwarded==[1,1],"actual rack forwards Uzi bullet and Matador pellets exactly once")
	var wall:=StaticBody3D.new();var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1,2,.2);col.shape=box;wall.add_child(col);wall.position=Vector3(0,1,-.5);root.add_child(wall)
	var trackers:Array=[]
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="interaction048_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers.append(t)
	await physics_frame;await process_frame;actor.update_hand_input_rearm(.2);actor.xr_enabled=true
	for side in ["right","left"]:
		actor.dominant_hand=side;actor._grabs.clear();actor.left_hand_reserved=false;rack._refresh_hands();rack.selected=0;rack.is_holstered=false;rack._apply_selection()
		var firing:XRController3D=actor.get_weapon_hand();var support:XRController3D=actor.get_support_hand()
		firing.global_position=Vector3(0,1,-.43);support.global_position=Vector3(.2,1,-.43)
		check(not actor.find_grab_surface(firing.global_position).is_empty(),side+" actual collision wall within grab reach")
		actor._update_grab(firing,true)
		check(not actor._grabs.has(firing),side+" drawn firing gun hand cannot acquire wall")
		actor._update_grab(support,true)
		check(actor._grabs.has(support),side+" free offhand acquires wall")
		var anchor:Vector3=actor._grabs.get(support,Vector3.INF)
		check(rack.select_weapon(7) and actor._grabs.get(support)==anchor,side+" weapon changes while offhand anchor persists")
		check(rack.select_inventory_weapon(5) and actor._grabs.get(support)==anchor,side+" backpack selection preserves physical anchor")
		actor._update_grab(support,false,false);rack.set_holstered(true);actor._update_grab(firing,true)
		check(actor._grabs.has(firing),side+" holstering frees firing hand for wall grip")
		rack.set_holstered(false);check(rack.is_holstered and actor._grabs.has(firing),side+" drawing cannot steal its own wall hand")
		actor._update_grab(firing,false,false)
	check(is_equal_approx(actor.GLIDE_HORIZONTAL_SPREAD,1.009375*.95),"horizontal glide threshold reduced by exactly further 5 percent")
	var inventory=load("res://scripts/weapon_inventory.gd").new();root.add_child(inventory);inventory.setup(actor,rack);inventory.set_process(false)
	check(inventory.owned==[0,2,9] and not inventory.pickups.has(4) and inventory.pickups.has(12),"three initial guns and ground lineup omit pump; six-slot contract retained")
	rack.selected=5;rack.is_holstered=false;rack.weapons[5].reload_state="needs_bolt";rack.weapons[5]._bolt_contact=false
	check(inventory._can_interact(),"uncycled sniper allows idle ground pickup")
	rack.weapons[5]._bolt_contact=true;check(not inventory._can_interact(),"held sniper bolt remains protected during ground pickup")
	var reticle=load("res://scripts/aim_reticle.gd").new();root.add_child(reticle);reticle.setup(actor,rack,Node.new());reticle.set_process(false)
	for part in reticle.get_children():check(part.material_override.no_depth_test,"crosshair arm cannot depth clip against contacted surface")
	reticle.game.free();reticle.free();inventory.free();rack.shutdown();await create_timer(.2).timeout;rack.free();actor.free();wall.free()
	for t in trackers:XRServer.remove_tracker(t)
	# Let deferred audio/render releases finish after freeing their owning nodes.
	await create_timer(.2).timeout
	print("INTERACTION_056_CLEANUP checks=",checks," failures=",failures," actual_physics=true rendered=false headset_tested=false")
	quit(failures)
