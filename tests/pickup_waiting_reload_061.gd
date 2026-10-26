extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:Engine.max_fps=90;call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func run()->void:
	load("res://scripts/audio_bank.gd").ensure_buses()
	var floor:=StaticBody3D.new();root.add_child(floor);floor.position.y=-.1
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.2,100);collider.shape=box;floor.add_child(collider)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.tracking_available=true;actor.xr_camera.position.y=2.0;freeze(actor)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="pickup_wait061_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);freeze(rack)
	await physics_frame;await physics_frame
	var inv=load("res://scripts/weapon_inventory.gd").new();root.add_child(inv);inv.setup(actor,rack);inv.set_process(false)
	await physics_frame;await physics_frame;await physics_frame
	inv.capacity=4
	check(inv.pickup_weapon(5),"persistent AWP acquired for held-sniper pickup reproduction")
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands()
		for data in [[0,"needs_mag"],[5,"needs_mag"],[5,"needs_bolt"]]:
			var source:int=data[0];var stage:String=data[1];var gun=rack.weapons[source]
			gun.reload_state=stage;gun.ammo=0
			if source==5:gun._bolt_contact=false
			rack.selected=source;rack.is_holstered=false;rack._apply_selection();actor.left_hand_reserved=true
			var hand:XRController3D=actor.get_support_hand();var center:Vector3=inv._pickup_center(14)
			hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI/2),center+Vector3.BACK*.6)
			trackers[hand].set_input("grip",0.0);actor.update_hand_input_rearm(.2)
			var bank:Dictionary=rack.reserves.duplicate();var label:String=side+" held%d %s"%[source,stage]
			check(inv._hand_eligible(hand) and inv.get_aimed_pickup(hand)==14,label+" waiting reload does not reserve distant free offhand")
			trackers[hand].set_input("grip",1.0)
			check(inv.handle_grip("inventory_pickup:14",hand) and inv.has_weapon(14),label+" actual aimed grip acquires Katana")
			check(rack.reserves==bank and gun.ammo==0,label+" pickup preserves empty gun and reserve ammunition")
			trackers[hand].set_input("grip",0.0);actor.update_hand_input_rearm(.2)
			check(inv.drop_weapon(14),label+" acquired Katana can return to persistent ground prop")
			gun.reload_state="ready";actor.left_hand_reserved=false
		var sniper=rack.weapons[5];rack.selected=5;rack.is_holstered=false;rack._apply_selection();sniper.reload_state="needs_bolt";sniper._bolt_contact=true
		var support:XRController3D=actor.get_support_hand();var point:Vector3=inv._pickup_center(14);support.global_transform=Transform3D(Basis(Vector3.RIGHT,PI/2),point+Vector3.BACK*.6)
		check(inv.get_aimed_pickup(support)==-1 and not inv.handle_grip("inventory_pickup:14",support),side+" engaged sniper bolt still prevents stealing hand for pickup")
		sniper._bolt_contact=false;sniper.reload_state="held_mag"
		check(inv.get_aimed_pickup(support)==-1,side+" actually held reload part still prevents inventory transfer")
		sniper.reload_state="ready";actor.left_hand_reserved=false
	for t in trackers.values():XRServer.remove_tracker(t)
	inv.free();rack.shutdown();rack.free();actor.free();floor.free();await process_frame
	print("PICKUP_WAITING_RELOAD_061 checks=",checks," failures=",failures," synthetic_trackers=true headset_tested=false")
	quit(failures)
