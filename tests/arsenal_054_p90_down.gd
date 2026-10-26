extends SceneTree
## Synthetic controllers exercise the actual P90 instance created by production Main.
var checks:=0
var failures:=0
var trackers:Dictionary={}
var game
var actor
var rack
var gun
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func sample(point:Vector3,grip:float)->void:
	gun.left_hand.global_position=gun.reload_world_point(point)
	trackers[gun.left_hand].set_input("grip",grip)
	actor._objective_grip_frame=-1;actor.update_objective_grips();gun._poll_vr()
func empty(reserve:int)->void:
	actor._grabs.clear();actor.left_hand_reserved=false;actor.input_enabled=true
	actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset()
	for hand in [actor.left_hand,actor.right_hand]:
		trackers[hand].set_input("grip",0.0);trackers[hand].set_input("trigger",0.0);trackers[hand].set_input("primary",Vector2.ZERO);trackers[hand].set_input("primary_click",false)
	actor.update_hand_input_rearm(.2)
	gun.reset_weapon();rack.Arsenal.apply(gun,10);gun.ammo=0;rack.reserves.pistol=reserve
	gun.eject_magazine();gun._process(0)
	gun.global_transform=Transform3D(Basis.IDENTITY,actor.global_position+Vector3(0,1.2,-.5))
	sample(gun.TOP_OFFER,0)
func seat()->void:
	sample(gun.TOP_OFFER,1);sample(gun.TOP_OFFER+Vector3.DOWN*.17,1)
func charge()->void:
	sample(gun.get_charge_point(),1);sample(gun.get_charge_point()+Vector3.BACK*.08,1)
func budget()->int:return gun.get_loaded_rounds()+gun.reserve_rounds()
func run()->void:
	game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
	game.set_process(false);game.process_mode=Node.PROCESS_MODE_DISABLED;game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	actor=game.player;actor.xr_enabled=true;actor.tracking_available=true;actor.input_enabled=true;actor.global_position=Vector3(1000,2,1000)
	rack=game.weapon;game.weapon_inventory.owned.assign([0,10])
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="p90down054_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;rack._refresh_hands();rack.selected=10;rack.is_holstered=false;rack.is_selecting=false;rack._apply_selection();rack._draw_delay=0
		gun=rack.weapons[10];var label:String=dominance+" Main P90"
		empty(100)
		check(gun.magazine_size==45,label+" retains one-star45 despite two-star50 in film")
		check(gun.TOP_OFFER.y>gun.TOP_SEAT.y+.1 and is_equal_approx(gun.TOP_OFFER.z,gun.TOP_SEAT.z),label+" original top magazine offer sits above seating slot")
		check(gun.insertion_arrow.basis.y.dot(Vector3.DOWN)>.999,label+" insertion cue points DOWN")
		var zone:Dictionary=gun.get_reload_zones()[0]
		check(zone.position==gun.TOP_OFFER and gun._in_reload_reach(gun.TOP_OFFER+Vector3.UP*.28,zone.position,zone.radius),label+" shared enlarged offer volume and arbitration agree")
		check(not gun._in_reload_reach(gun.TOP_OFFER+Vector3.UP*.5,zone.position,zone.radius),label+" remote unrelated grab remains out of range")
		sample(gun.TOP_OFFER,1)
		check(gun.reload_state=="held_mag" and gun.reserve_rounds()==100,label+" actual fresh support grip holds offered top magazine without spend")
		sample(gun.TOP_OFFER+Vector3.FORWARD*.17,1)
		check(gun.reload_state=="held_mag" and gun.reserve_rounds()==100,label+" FORWARD-only stroke cannot substitute for DOWN")
		empty(100);sample(gun.TOP_OFFER,1);sample(gun.TOP_OFFER+Vector3.UP*.15,1)
		check(gun.reload_state=="held_mag" and gun.reserve_rounds()==100,label+" UP cannot insert")
		sample(gun.TOP_OFFER+Vector3.DOWN*.04,1)
		check(gun.reload_state=="held_mag" and gun.reserve_rounds()==100,label+" small downward jitter cannot insert")
		sample(gun.TOP_OFFER+Vector3.DOWN*.17,1)
		check(gun.reload_state=="needs_rack" and gun._seated_rounds==45 and gun.ammo==0 and gun.reserve_rounds()==55 and budget()==100,label+" actual held DOWN seats45 funded rounds and still needs BACK")
		sample(gun.get_charge_point(),1)
		check(gun._rack_grabbed and gun.reload_state=="needs_rack",label+" continuing grip acquires separate side charging target")
		sample(gun.get_charge_point()+Vector3.FORWARD*.09,1)
		check(gun.reload_state=="needs_rack",label+" FORWARD handle stroke cannot charge")
		sample(gun.get_charge_point()+Vector3.BACK*.08,1)
		check(gun.reload_state=="ready" and gun.ammo==45 and gun.reserve_rounds()==55 and budget()==100 and gun._requires_trigger_release,label+" deliberate BACK completes continuous reload with fresh firing trigger")
		check(signf(gun.get_charge_point().x)==(1.0 if dominance=="left" else -1.0),label+" charging target still mirrors toward support hand")
		gun.ammo=13;var funded:=budget();var prior:int=gun.reserve_rounds();gun.eject_magazine();gun.eject_magazine()
		check(budget()==funded and gun.reserve_rounds()==prior+13 and gun.ammo==0,label+" repeated tactical eject refunds live rounds once")
		empty(3);sample(gun.TOP_OFFER,1);sample(gun.TOP_OFFER,0)
		check(gun.reload_state=="needs_mag" and gun.reserve_rounds()==3 and budget()==3,label+" release before insertion returns unspent offer")
		sample(gun.TOP_OFFER,1);check(rack.select_weapon(0),label+" actual rack can switch away while magazine is held")
		check(gun.reload_state=="needs_mag" and budget()==3,label+" switching cancels unfunded carried magazine")
		check(rack.select_inventory_weapon(10),label+" actual inventory selection restores same P90")
		sample(gun.TOP_OFFER+Vector3.DOWN*.17,1)
		check(gun.reload_state=="needs_mag" and budget()==3,label+" held grip after selection cannot replay insertion")
		sample(gun.TOP_OFFER,0);seat()
		check(gun.reload_state=="needs_rack" and gun._seated_rounds==3 and gun.reserve_rounds()==0 and budget()==3,label+" DOWN loads real partial three-round reserve")
		check(rack.select_weapon(0) and rack.select_inventory_weapon(10),label+" actual rack roundtrip preserves seated reload")
		check(gun.reload_state=="needs_rack" and budget()==3,label+" seated rounds survive switching without refund or duplication")
		charge();check(gun.reload_state=="needs_rack",label+" held charge after switching waits for neutral rearm")
		sample(gun.get_charge_point(),0);charge()
		check(gun.reload_state=="ready" and gun.ammo==3 and budget()==3,label+" neutral rearmed BACK completes retained partial load")
		empty(5);actor._grabs[gun.left_hand]=gun.left_hand.global_position;seat()
		check(gun.reload_state=="needs_mag" and budget()==5 and actor._grabs.has(gun.left_hand),label+" wall ownership prevents top magazine acquisition")
		actor._grabs.clear();seat();check(gun.reload_state=="needs_mag" and budget()==5,label+" wall release cannot replay held reload grip")
		sample(gun.TOP_OFFER,0);seat();check(gun.reload_state=="needs_rack" and budget()==5,label+" neutral release restores DOWN reload after wall ownership")
		empty(5);sample(gun.TOP_OFFER,1);trackers[gun.left_hand].invalidate_pose("grip");sample(gun.TOP_OFFER,1)
		trackers[gun.left_hand].set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);sample(gun.TOP_OFFER+Vector3.DOWN*.17,1)
		check(gun.reload_state in ["needs_mag","held_mag"] and gun.get_loaded_rounds()==0 and gun.reserve_rounds()==5,label+" tracking loss prevents held return from seating or spending reserve")
		sample(gun.TOP_OFFER,0);seat();check(gun.reload_state=="needs_rack" and budget()==5,label+" neutral grip after tracking recovery restores DOWN reload")
		empty(5);var control:Vector3=actor.global_position+Vector3(2,1,0)
		actor.objective_grip_provider=func()->Array:return [{"id":"p90-owned-control","position":control,"hand":gun.left_hand}]
		sample(gun.to_local(control),0);sample(gun.to_local(control),1)
		check(actor.is_hand_grip_reserved(gun.left_hand),label+" actual objective arbiter acquires outside reload zone")
		seat();check(gun.reload_state=="needs_mag" and budget()==5 and actor.is_hand_grip_reserved(gun.left_hand),label+" moving owned objective through DOWN path cannot steal hand")
		sample(gun.TOP_OFFER,0);actor.objective_grip_provider=Callable();actor._objective_grip_arbiter.reset()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.2).timeout
	print("ARSENAL_054_P90_DOWN checks=",checks," failures=",failures," actual_main_polling=true native_rendered=false film_raw_buttons_verified=false")
	quit(failures)
