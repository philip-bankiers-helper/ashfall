extends SceneTree
var checks:=0
var failures:=0
var trackers:Dictionary={}
var actor
func _initialize()->void:Engine.max_fps=90;call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop()
	for child in node.get_children():freeze(child)
func grip(hand:XRController3D,value:float)->void:
	trackers[hand].set_input("grip",value)
	if value==0:actor.update_hand_input_rearm(.2)
	actor._objective_grip_frame=-1;actor.update_objective_grips()
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	freeze(game);game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	actor=game.player;actor.input_enabled=true;actor.tracking_available=true;actor.xr_enabled=true;actor.global_position=Vector3(1000,0,1000);actor.xr_camera.position.y=1.404
	var rack=game.weapon;var supplies=game.field_consumables
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.name="feedback068_"+str(hand.get_instance_id());t.type=XRServer.TRACKER_CONTROLLER;XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["left","right"]:
		actor.dominant_hand=side;rack._refresh_hands()
		var hand:XRController3D=actor.get_weapon_hand()
		supplies.reset_supplies(actor.global_position);rack.inventory.capacity=6;supplies.collect(1);supplies.stock.shaker=0
		for i in supplies.pickups.size():supplies.pickups[i].global_position=Vector3(1100+i,1,1100)
		var point:=Vector3(1000,1.2,998.5);supplies.pickups[0].global_position=point
		rack.set_holstered(false)
		hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),point+Vector3.BACK*1.9)
		grip(hand,0);supplies._update_pickup_rings()
		check(supplies.aim_rings[hand].visible,"ordinary aimed pickup ring visible while gun drawn "+side)
		var blocker:=StaticBody3D.new();blocker.position=point+Vector3.BACK*.9
		var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1,2,.1);collision.shape=box;blocker.add_child(collision);game.add_child(blocker)
		await physics_frame;await physics_frame
		grip(hand,0);grip(hand,1)
		check(supplies.stock.shaker==0 and not supplies.pickups[0].get_meta("taken"),"wall blocks production pickup "+side)
		blocker.free();await physics_frame;grip(hand,0)
		rack.weapons[rack.selected].reload_state="held_mag";grip(hand,1)
		check(supplies.stock.shaker==0,"held reload part blocks supply acquisition "+side)
		rack.weapons[rack.selected].reload_state="ready";grip(hand,0);grip(hand,1)
		check(supplies.stock.shaker==1 and supplies.held_kind=="shaker" and supplies.held_hand==hand,"fresh grip at 1.9m collects and equips through Main/arbiter "+side)
		supplies._process(.01)
		check(supplies.held_prop.global_basis.y.normalized().dot(-hand.global_basis.z.normalized())>.99999,"actual held shaker thumb-axis transform "+side)
		check(actor._hand_holds_item(hand),"equipped supply reserves hand from climbing "+side)
		var ray:Transform3D=actor.get_view_camera().global_transform
		rack._a_blocked=false;rack._a_previous=false
		rack.update_a_input(.02,true,true,ray);rack.update_a_input(.02,false,true,ray)
		check(supplies.held_kind.is_empty() and supplies.selected_kind=="shaker","production A release stows shaker "+side)
		rack.update_a_input(.11,true,true,ray)
		var slot:int=rack.wheel.SLOT_ACTIONS.find("consumable:"+str(supplies.items.keys()[0]))
		var target:Vector3=rack.wheel.to_global(rack.wheel.slot_position(slot,.23))
		var select_ray:=Transform3D(Basis.looking_at(target-ray.origin,Vector3.UP),ray.origin)
		rack.update_a_input(.02,true,true,select_ray);rack.update_a_input(.02,false,true,select_ray)
		check(supplies.held_kind=="soda" and supplies.selected_kind=="soda","actual A wheel switches shaker to soda "+side)
		supplies._process(.01)
		check(supplies.held_prop.global_basis.y.normalized().dot(-hand.global_basis.z.normalized())>.99999,"actual held soda thumb-axis transform "+side)
		supplies.stow();supplies.selected_kind=""
	# Use the actual world-reticle update, not only the geometric helper.
	game.weapon_inventory.owned.assign([0,21,25]);rack.is_holstered=false
	for index in [0,21,25]:
		rack.selected=index;rack._apply_selection()
		var gun:Node3D=rack.weapons[index];gun.ammo=3;gun.reload_state="ready"
		gun.transform=Transform3D(Basis.IDENTITY,Vector3(1000,1,998))
		var sight:Node3D=gun.get_meta("ring_sight")
		var rear:Node3D=sight.get_node("RearReference");var front:Node3D=sight.get_node("FrontReference")
		var axis:Vector3=(front.global_position-rear.global_position).normalized()
		actor.xr_camera.global_transform=Transform3D(Basis.looking_at(axis,Vector3.UP),rear.global_position-axis*.22)
		game.aim_reticle.update_reticle()
		check(not game.aim_reticle.visible,"production world reticle hides for aligned sight "+str(index))
		actor.xr_camera.global_position+=Vector3.RIGHT*.12
		game.aim_reticle.update_reticle()
		check(game.aim_reticle.visible,"production world reticle reappears off sight "+str(index))
		# Returning to ADS must keep current firing origin/direction published.
		gun.global_position+=Vector3(.06,.04,0)
		actor.xr_camera.global_transform=Transform3D(Basis.looking_at(axis,Vector3.UP),rear.global_position-axis*.22)
		game.aim_reticle.update_reticle()
		check(gun.get_firing_pose().origin.distance_to(gun.get_shot_transform().origin)<.00001,"aligned translated sight publishes current firing origin "+str(index))
		gun.global_basis=Basis(Vector3.UP,.12)*gun.global_basis
		axis=(front.global_position-rear.global_position).normalized()
		actor.xr_camera.global_transform=Transform3D(Basis.looking_at(axis,Vector3.UP),rear.global_position-axis*.22)
		game.aim_reticle.update_reticle()
		check(gun.get_firing_pose().basis.is_equal_approx(gun.get_shot_transform().basis),"aligned rotated sight publishes current firing direction "+str(index))
		var emissions:Array=[]
		var callback:=func(origin:Vector3,direction:Vector3,_damage:float):emissions.append({"origin":origin,"direction":direction})
		gun.shot.connect(callback);gun.cooldown=0;gun._requires_trigger_release=false
		var expected:Transform3D=gun.get_shot_transform();gun.fire()
		check(emissions.size()==1 and emissions[0].origin.distance_to(gun.camera.global_position)<.00001 and emissions[0].direction.dot(-expected.basis.z)>.99999,"actual headless shot follows moving aim with desktop origin "+str(index))
		gun.shot.disconnect(callback)
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	game._quitting=true;rack.shutdown();game._stop_audio_tree(game)
	await create_timer(1.0).timeout
	game.queue_free();await process_frame;await process_frame
	print("INTERACTION_068 checks=",checks," failures=",failures," synthetic_trackers=true xr_runtime_off=true headset_tested=false")
	quit(failures)
