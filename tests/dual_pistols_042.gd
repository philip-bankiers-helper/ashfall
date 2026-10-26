extends SceneTree
class Pair extends "res://scripts/dual_pistols.gd":
	func _vr_active()->bool:return true
class SprintPlayer extends "res://scripts/player.gd":
	func update_tracking()->bool:return tracking_available
class DesktopPair extends "res://scripts/dual_pistols.gd":
	func _vr_active()->bool:return false
class Reserve extends Node:
	var count:=5
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,n:int)->int:
		var amount:=mini(count,n);count-=amount;return amount
var checks:=0
var failures:=0
var actor
var pair
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func tick()->void:pair._process(0)
func trigger(index:int,value:float)->void:
	trackers[pair.hand_for(index)].set_input("trigger",value);tick()
func sample(index:int,point:Vector3,grip:float)->void:
	var gun=pair.guns[index]
	gun.left_hand.global_position=gun.reload_world_point(point);trackers[gun.left_hand].set_input("grip",grip);tick()
func mouse(button:MouseButton,down:bool)->void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=down
	Input.parse_input_event(event);Input.flush_buffered_events();pair._process(0)
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="dual042_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip"
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=tracker
	await process_frame
	for side in ["right","left"]:
		actor.dominant_hand=side
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
		actor.update_hand_input_rearm(.1)
		pair=Pair.new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
		var reserve:=Reserve.new();root.add_child(reserve);pair.ammo_provider=reserve;pair.ammo_slot=0;tick()
		check(pair.guns[0].right_hand==actor.get_weapon_hand() and pair.guns[1].right_hand==actor.get_support_hand(),side+" two independent physical hand owners")
		check(pair.get_loaded_rounds()==24 and pair.guns[0].ammo_panel.visible and pair.guns[1].ammo_panel.visible and not pair.ammo_panel.visible,side+" two independent tiny ammo panels")
		var before_hand0:Transform3D=pair.hand_for(0).global_transform
		var before_hand1:Transform3D=pair.hand_for(1).global_transform
		trigger(0,1)
		check(pair.guns[0].recoil_pattern_index==1 and pair.guns[1].recoil_pattern_index==0,side+" each pistol owns independent deterministic recoil state")
		check(pair.hand_for(0).global_transform.is_equal_approx(before_hand0) and pair.hand_for(1).global_transform.is_equal_approx(before_hand1),side+" firing preserves both raw controller poses")
		check(pair.guns[0].ammo==11 and pair.guns[1].ammo==12,side+" dominant trigger fires only own pistol")
		pair.guns[0].cooldown=0;tick();check(pair.guns[0].ammo==11,side+" held trigger cannot repeat")
		trigger(1,1);check(pair.guns[0].ammo==11 and pair.guns[1].ammo==11,side+" offhand trigger fires only own pistol")
		check(not pair.guns[0].supported and not pair.guns[1].supported,side+" occupied hands never stabilize opposite gun")
		trigger(0,0);trigger(1,0)
		var raw0:Transform3D=pair.hand_for(0).global_transform
		var raw1:Transform3D=pair.hand_for(1).global_transform
		pair.guns[1].cooldown=0;actor._grabs[pair.hand_for(1)]=pair.hand_for(1).global_position;trigger(1,1)
		check(pair.guns[1].ammo==11 and actor._grabs.has(pair.hand_for(1)),side+" offhand wall anchor blocks own fire without dropping anchor")
		check(not pair.toggle_stow(1),side+" wall-anchored gun cannot stow")
		actor._grabs.clear();trigger(1,0)
		# Deliberate fresh grip at physical hip stows only that gun.
		pair.hand_for(1).global_position=pair.hip_point(1);trackers[pair.hand_for(1)].set_input("grip",0.0);tick();trackers[pair.hand_for(1)].set_input("grip",1.0);tick()
		check(pair.stowed[1] and not pair.stowed[0],side+" tracked own-hip fresh grip frees one hand")
		pair.guns[0].grip_toggle=true
		sample(0,pair.guns[0].PISTOL_SUPPORT_POINT,0);sample(0,pair.guns[0].PISTOL_SUPPORT_POINT,1);sample(0,pair.guns[0].PISTOL_SUPPORT_POINT,0)
		check(pair.guns[0].supported and pair.hand_for(1).get_float("grip")==0 and pair.is_hand_holding_weapon(pair.hand_for(1)),side+" toggled pistol support retains freehand glove curl after grip release")
		sample(0,pair.guns[0].PISTOL_SUPPORT_POINT+Vector3(1,0,0),0)
		check(not pair.guns[0].supported and not pair.is_hand_holding_weapon(pair.hand_for(1)),side+" losing support returns freehand glove pose")
		pair.guns[0].grip_toggle=false
		pair.guns[0].eject_magazine();tick();sample(0,pair.guns[0].OFFER_POINT,0);sample(0,pair.guns[0].OFFER_POINT,1)
		check(pair.guns[0].reload_state=="held_mag",side+" stowed hand physically acquires fresh magazine")
		check(not pair.toggle_stow(1),side+" reload contact blocks retrieving stowed pistol")
		sample(0,pair.guns[0].INSERT_POINT,1)
		check(pair.guns[0].reload_state=="needs_rack" and reserve.count==0 and pair.guns[0]._seated_rounds==5,side+" physical magazine seat consumes partial finite family reserve")
		sample(0,Vector3(-.05,.064,-.10),0);sample(0,Vector3(-.05,.064,-.10),1);sample(0,Vector3(-.05,.064,-.02),1)
		check(pair.guns[0].reload_state=="ready" and pair.guns[0].ammo==5,side+" free hand actual slide pull chambers existing five rounds")
		check(pair.toggle_stow(1) and not pair.stowed[1],side+" ready pistol permits fresh retrieval")
		trigger(0,0);trigger(1,0);pair.guns[1].cooldown=0;trigger(1,1)
		check(pair.guns[1].ammo==10 and pair.guns[0].ammo==5,side+" retrieved pistol retains own old magazine")
		check(pair.get_reticle_entries().size()==2 and pair.is_hand_holding_weapon(pair.hand_for(0)) and pair.is_hand_holding_weapon(pair.hand_for(1)),side+" exposes independent reticle and glove ownership contract")
		pair._suspend_gestures();pair.guns[1].cooldown=0;tick();check(pair.guns[1].ammo==10,side+" rack suspension demands trigger neutral")
		trigger(1,0);trigger(1,1);check(pair.guns[1].ammo==9,side+" neutral rearm returns independent fire")
		# Reverse the stow policy: dominant pistol holstered, offhand pistol reloaded by dominant hand.
		trigger(1,0);check(pair.toggle_stow(0),side+" dominant gun may stow to free dominant reload hand")
		pair.guns[1].eject_magazine();tick();reserve.count=3
		sample(1,pair.guns[1].OFFER_POINT,0);sample(1,pair.guns[1].OFFER_POINT,1);sample(1,pair.guns[1].INSERT_POINT,1)
		check(pair.guns[1].reload_state=="needs_rack" and reserve.count==0,side+" reverse physical reload consumes same finite reserve")
		sample(1,Vector3(-.05,.064,-.10),0);sample(1,Vector3(-.05,.064,-.10),1);sample(1,Vector3(-.05,.064,-.02),1)
		check(pair.guns[1].ammo==3 and pair.guns[0].ammo==5 and pair.reload_state=="ready",side+" reverse slide pull preserves stowed magazine")
		check(pair.toggle_stow(0),side+" dominant retrieval returns two pistols")
		# Tracking loss on offhand must not move raw poses, fire, or block the good hand.
		var before0:int=pair.guns[0].ammo;var before1:int=pair.guns[1].ammo
		trackers[pair.hand_for(1)].invalidate_pose("grip");pair.guns[1].cooldown=0;trigger(1,1)
		check(pair.guns[1].ammo==before1,side+" untracked offhand cannot fire")
		pair.guns[0].cooldown=0;trigger(0,0);trigger(0,1)
		check(pair.guns[0].ammo==before0-1,side+" independently tracked hand remains usable")
		trackers[pair.hand_for(1)].set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		trigger(0,0);trigger(1,0);actor.update_hand_input_rearm(.1);tick()
		actor._objective_grip_arbiter._claimed[pair.hand_for(1)]=true
		pair.guns[1].cooldown=0;trigger(1,1)
		check(pair.guns[1].ammo==before1 and not pair.toggle_stow(1),side+" objective-owned hand blocks weapon fire and stow")
		actor._objective_grip_arbiter.reset()
		check(pair.model.find_children("CanonicalPairedPistol*","Node3D",false,false).size()==2 and not pair.model.visible,side+" canonical groundpair geometry separate from tracked runtime guns")
		pair.shutdown();await create_timer(.2).timeout;pair.free();reserve.free()
	# Exercise actual engine mouse state, rather than directly calling child fire.
	pair=DesktopPair.new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false)
	mouse(MOUSE_BUTTON_LEFT,true)
	check(pair.guns[0].ammo==11 and pair.guns[1].ammo==12,"desktop LMB consumes only primary")
	pair.guns[0].cooldown=0;pair.guns[1].cooldown=0;pair.fire();pair._process(0)
	check(pair.guns[0].ammo==11 and pair.guns[1].ammo==12,"desktop held LMB plus rack fire signal cannot repeat or crossfire")
	mouse(MOUSE_BUTTON_RIGHT,true)
	check(pair.guns[0].ammo==11 and pair.guns[1].ammo==11,"desktop RMB consumes only secondary even while LMB held")
	pair.guns[1].cooldown=0;pair._process(0)
	check(pair.guns[1].ammo==11,"desktop held RMB cannot repeat")
	mouse(MOUSE_BUTTON_RIGHT,false);mouse(MOUSE_BUTTON_RIGHT,true)
	check(pair.guns[0].ammo==11 and pair.guns[1].ammo==10,"desktop RMB release rearms independently while LMB held")
	mouse(MOUSE_BUTTON_LEFT,false);pair.guns[0].cooldown=0;mouse(MOUSE_BUTTON_LEFT,true)
	check(pair.guns[0].ammo==10 and pair.guns[1].ammo==10,"desktop LMB release rearms independently while RMB held")
	pair._suspend_gestures();pair.guns[0].cooldown=0;pair.guns[1].cooldown=0;pair._process(0)
	check(pair.guns[0].ammo==10 and pair.guns[1].ammo==10,"desktop suspension holds both mouse latches until release")
	mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false)
	pair.shutdown();await create_timer(.2).timeout;pair.free();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();await process_frame
	print("DUAL_PISTOLS_042 checks=",checks," failures=",failures," synthetic=true headset_tested=false");quit(failures)




func sprint_regression()->void:
	const DT:=1.0/90.0
	var floor:=StaticBody3D.new();floor.position=Vector3(100,-.1,100)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(100,.2,100);collision.shape=shape;floor.add_child(collision);root.add_child(floor)
	await physics_frame
	for side in ["right","left"]:
		for order in ["player_first","pair_first"]:
			var subject:=SprintPlayer.new();root.add_child(subject);subject.setup(false);subject.xr_enabled=true;subject.tracking_available=true;subject.dominant_hand=side;subject.sprint_binding="left_grip";subject.position=Vector3(100,0,100);subject.xr_camera.position.y=1.65
			subject.set_process(false);subject.set_physics_process(false)
			var local_trackers:Array=[]
			var left:XRControllerTracker
			for hand in [subject.left_hand,subject.right_hand]:
				var t:=XRControllerTracker.new();t.name="dual_sprint_regression_"+str(hand.get_instance_id());t.type=XRServer.TRACKER_CONTROLLER;XRServer.add_tracker(t);local_trackers.append(t);hand.tracker=t.name;hand.pose="grip"
				hand.position=Vector3(-.23 if hand==subject.left_hand else .23,1.05,.03)
				t.set_pose("grip",hand.transform,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
				if hand==subject.left_hand:left=t
			await process_frame
			var bundle:=Pair.new();root.add_child(bundle);bundle.setup(subject,false);bundle.set_process(false);bundle.set_physics_process(false)
			var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.player=subject;rack.weapons=[bundle];rack.selected=0;rack.set_process(false);subject.sprint_conflict_provider=rack
			for i in range(20):subject._physics_process(DT);bundle._process(DT)
			left.set_input("primary",Vector2(0,1));subject._physics_process(DT);bundle._process(0)
			var index:=1 if side=="right" else 0
			var label:String=side+" "+order+" "
			for operation in ["stow","retrieve"]:
				subject.left_hand.global_position=bundle.hip_point(index)
				left.set_input("grip",0.0);bundle._process(0);subject._physics_process(DT)
				subject.left_hand.global_position=bundle.hip_point(index);left.set_input("grip",1.0)
				var consumed:Array=bundle._hip_consumed.duplicate();var slots:Array=bundle.stowed.duplicate()
				check(bundle.blocks_sprint() and bundle.blocks_sprint() and bundle._hip_consumed==consumed and bundle.stowed==slots,label+operation+" hip intent blocks sprint before processing through pure query")
				if order=="pair_first":bundle._process(0);subject._physics_process(DT)
				else:subject._physics_process(DT);bundle._process(0)
				check(subject._sprint_mode==0 and bundle.stowed[index]==(operation=="stow"),label+operation+" real player physics never starts sprint")
				subject.left_hand.global_position=subject.get_view_camera().global_position+Vector3(-.8,-.25,-.4)
				for repeat in range(3):
					if order=="pair_first":bundle._process(0);subject._physics_process(DT)
					else:subject._physics_process(DT);bundle._process(0)
				check(bundle.blocks_sprint() and subject._sprint_mode==0,label+operation+" consumed held grip stays blocked after leaving hip")
				left.set_input("grip",0.0);bundle._process(0);subject._physics_process(DT)
			check(not bundle.blocks_sprint(),label+" physical neutral releases consumed hip gesture")
			left.set_input("grip",1.0);subject._physics_process(DT);bundle._process(0)
			check(subject._sprint_mode==1,label+" new grip away from hip still starts normal sprint")
			left.set_input("grip",0.0);bundle._process(0)
			bundle.guns[0].reload_state="held_mag";check(bundle.blocks_sprint(),label+" child reload state blocks sprint")
			bundle.guns[0].reload_state="ready";bundle.guns[1]._rack_grabbed=true;check(bundle.blocks_sprint(),label+" child slide contact blocks sprint")
			bundle.guns[1]._rack_grabbed=false;bundle.guns[1].supported=true;check(bundle.blocks_sprint(),label+" child support state blocks sprint")
			bundle.guns[1].supported=false
			bundle.shutdown();await create_timer(.2).timeout;bundle.free();rack.free();subject.free()
			for t in local_trackers:XRServer.remove_tracker(t)
			await process_frame
	floor.free()


