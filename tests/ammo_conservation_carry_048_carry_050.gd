extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func budget(gun:Node)->int:return gun.get_loaded_rounds()+gun.reserve_rounds()
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for index in [0,2,3,6,17,18,19,20,21,23,24,25]:
		var gun=rack.weapons[index];gun.ammo=gun.magazine_size-2;var initial:=budget(gun);var remaining:int=gun.ammo;var before:int=gun.reserve_rounds()
		gun.eject_magazine();check(gun.ammo==0 and gun.reserve_rounds()==before+remaining,"slot "+str(index)+" partial mag returns exact remaining rounds")
		gun.eject_magazine();check(budget(gun)==initial,"slot "+str(index)+" repeated eject cannot farm reserve")
		for cycle in range(4):
			gun.grab_magazine();gun.insert_magazine();check(budget(gun)==initial,"slot "+str(index)+" finite seating conserves budget")
			gun.suspend_for_selection();check(budget(gun)==initial and gun.reload_state=="needs_rack","slot "+str(index)+" seated switch preserves rounds")
			gun.eject_magazine();check(budget(gun)==initial and gun._seated_rounds==0,"slot "+str(index)+" unracked seated mag refunds once")
		gun.grab_magazine();gun.insert_magazine();gun.rack_bolt()
		check(budget(gun)==initial and gun._seated_rounds==0,"slot "+str(index)+" chambering transfers rather than duplicates seated count")
		gun.eject_magazine();check(budget(gun)==initial,"slot "+str(index)+" chambered magazine can be returned without inflation")
	var pdw=rack.weapons[10];pdw.ammo=31;var pdw_total:=budget(pdw);var pdw_reserve:int=pdw.reserve_rounds();pdw.eject_magazine()
	check(budget(pdw)==pdw_total and pdw.reserve_rounds()==pdw_reserve+31 and pdw.reload_state=="needs_mag","P90 auto-eject refunds all attached live rounds immediately")
	pdw.eject_magazine();pdw.eject_magazine();check(budget(pdw)==pdw_total and pdw.reserve_rounds()==pdw_reserve+31,"P90 repeated eject refunds once only")
	var precision=rack.weapons[5];precision.ammo=3;precision.chambered=false;precision.spent_chamber=true;precision.reload_state="needs_bolt";var precision_total:=budget(precision)
	precision.eject_magazine();precision.eject_magazine();check(budget(precision)==precision_total and precision.ammo==0,"precision mid-bolt partial mag returns remaining live rounds only")
	var lmg=rack.weapons[8];lmg.ammo=37;lmg.seated=37;var lmg_total:=budget(lmg);var lmg_reserve:int=lmg.reserve_rounds();lmg.open_cover();lmg.remove_box();lmg.remove_box()
	check(budget(lmg)==lmg_total and lmg.reserve_rounds()==lmg_reserve+37,"belt box removal returns remaining belt once")
	lmg.grab_magazine();lmg.insert_magazine();lmg.suspend_for_selection();check(budget(lmg)==lmg_total and lmg.reload_state=="needs_feed","belt seating and switching conserve real rounds")
	lmg.feed_belt();lmg.close_cover();lmg.rack_bolt();lmg.open_cover();lmg.remove_box();check(budget(lmg)==lmg_total,"belt charge and remove cannot inflate budget")
	var double=rack.weapons[1];double.chamber_states.assign(["live","spent"]);double.action.ammo=1;double.action.loaded=1;double.ammo=1;var shell_total:=budget(double);var shell_reserve:int=double.reserve_rounds();double.eject_magazine();double.eject_magazine()
	check(budget(double)==shell_total and double.reserve_rounds()==shell_reserve+1,"break action returns live chamber only and never spent case")
	for index in [4,9]:
		var tube=rack.weapons[index];var total:=budget(tube);tube.eject_magazine();tube.eject_magazine();tube.suspend_for_selection()
		check(budget(tube)==total,"tube shotgun "+str(index)+" manual intent and switch retain existing live chamber/tube")
	var revolver=rack.weapons[7];revolver.chambers.assign(["live","spent","empty","live","empty","spent"]);revolver._sync();var cylinder_total:=budget(revolver);revolver.eject_magazine();revolver.eject_cases();revolver.eject_cases()
	check(budget(revolver)==cylinder_total and revolver.chambers.count("live")==2,"revolver spent ejection retains live chambers without refunding spent brass")
	var pair=rack.weapons[11];pair.guns[0].ammo=7;pair.guns[1].ammo=9;pair._sync_pair();var pair_total:=budget(pair)
	pair.guns[0].reload_flick();pair.guns[1].reload_flick();pair._sync_pair()
	check(budget(pair)==pair_total,"dual independent upward reloads conserve shared finite reserve")
	var before_pair:Array=[pair.guns[0].ammo,pair.guns[1].ammo];pair.suspend_for_selection()
	check(budget(pair)==pair_total and [pair.guns[0].ammo,pair.guns[1].ammo]==before_pair,"dual atomic reload survives switching without duplication")
	pair.guns[0].reload_flick();pair._sync_pair();check(budget(pair)==pair_total,"repeated full Uzi flick cannot inflate reserve")
	var capped=rack.weapons[0];capped.reload_state="ready";capped.ammo=5;capped._seated_rounds=0;rack.reserves["rifle"]=9998;var capped_total:=budget(capped);capped.eject_magazine()
	check(budget(capped)==capped_total and capped.ammo==4 and capped.reload_state=="ready","reserve cap credits accepted round and retains unaccepted live rounds")
	capped.eject_magazine();check(budget(capped)==capped_total and capped.ammo==4,"full reserve repeated eject neither loses nor farms rounds")
	# A real tracked offered-magazine gesture is still uncharged when selection interrupts it.
	var trackers:Array=[]
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="ammo_conserve045_"+str(hand.get_instance_id());XRServer.add_tracker(t);trackers.append(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);t.set_input("primary_click",false)
	await process_frame;actor.update_hand_input_rearm(.1)
	var tracked=rack.weapons[2];tracked.reload_state="needs_mag";tracked.ammo=0;tracked._seated_rounds=0;tracked._resume_grip_release=false;tracked._grip_previous=false
	actor.left_hand.global_position=tracked.to_global(tracked.OFFER_POINT)
	tracked._poll_vr();trackers[0].set_input("grip",1.0);tracked._poll_vr()
	var tracked_total:=budget(tracked)
	check(tracked.reload_state=="held_mag","actual tracked fresh grip holds offered unseated magazine")
	tracked.suspend_for_selection();check(tracked.reload_state=="needs_mag" and budget(tracked)==tracked_total and tracked._seated_rounds==0,"selection returns tracked unseated mag without consuming or refunding rounds")
	actor.left_hand.global_position=tracked.to_global(tracked.INSERT_POINT);tracked._poll_vr()
	check(tracked.reload_state=="needs_mag" and budget(tracked)==tracked_total,"held physical grip after switch cannot seat a cancelled magazine")
	for t in trackers:XRServer.remove_tracker(t)
	for index in [5,10]:
		var gun=rack.weapons[index]
		gun.reload_state="needs_mag";gun.ammo=0;gun._seated_rounds=0;var held_total:=budget(gun);gun.grab_magazine();gun.suspend_for_selection()
		check(gun.reload_state=="needs_mag" and budget(gun)==held_total,"unseated partial magazine "+str(index)+" safely returns on selection")
	lmg.reload_state="box_removed";lmg.ammo=0;lmg.seated=0;var box_total:=budget(lmg);lmg.grab_magazine();lmg.suspend_for_selection()
	check(lmg.reload_state=="box_removed" and budget(lmg)==box_total,"held unseated belt box returns without granting or charging ammo")
	double.action.state="open_empty";double.reload_state="open_empty";var double_total:=budget(double);double.grab_magazine();double.suspend_for_selection()
	check(double.action.state=="open_empty" and budget(double)==double_total,"held unseated shell pair returns on switch without altering reserve")
	rack.shutdown();await create_timer(.2).timeout;rack.free();actor.free();await process_frame
	print("AMMO_CONSERVATION_CARRY_048 checks=",checks," failures=",failures," synthetic=true headset_tested=false");quit(failures)


