extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for dominance in ["right","left"]:
		actor.dominant_hand=dominance;rack._refresh_hands()
		var awp=rack.weapons[5];awp.reset_weapon();awp.cooldown=0;awp.fire()
		check(awp.reload_state=="needs_bolt","AWP nonfinal shot waits for one cycle "+dominance)
		awp.eject_magazine();check(awp.reload_state=="needs_mag","AWP can remove mag BEFORE cycling "+dominance)
		awp.grab_magazine();awp.insert_magazine();check(awp.reload_state=="needs_bolt","AWP magazine directly inserts then one cycle "+dominance)
		awp.bolt_sample(awp.get_bolt_grip_point(),false,true);awp.bolt_sample(awp.get_bolt_grip_point()+Vector3(.13,0,-.15),true,true);awp.bolt_sample(awp.get_bolt_grip_point()+Vector3(.13,0,-.15)+Vector3.BACK*.12,true,true)
		check(awp.reload_state=="ready" and awp.chambered,"wide forward bolt grab + simple back stroke completes "+dominance)
		check(awp._in_reload_reach(awp.OFFER_POINT+Vector3(.19,0,0),awp.OFFER_POINT,.25),"much larger AWP magazine acquisition "+dominance)
		var p90=rack.weapons[10]
		for x in [-.15,.15]:
			for z in [-.17,.17]:check(p90._in_reload_reach(p90.TOP_OFFER+Vector3(x,0,z),p90.TOP_OFFER,.25),"P90 target exceeds visible .083x.245mag "+dominance)
		var dt=rack.weapons[1];dt.reset_weapon();dt.eject_magazine();dt.grab_magazine();dt.insert_magazine()
		for i in 5:dt.gun_flick_sample(Vector3.ZERO,Vector3.FORWARD,.011,true,false)
		for i in 6:dt.gun_flick_sample(Vector3.UP*.01*(i+1),Vector3.FORWARD,.011,true,false)
		check(dt.action.state=="ready","DT11 6cm controlled up closes "+dominance)
		var mag=rack.weapons[7];mag.reset_weapon();mag.eject_magazine();mag.insert_magazine()
		for i in 5:mag.gun_flick_sample(Vector3.ZERO,Vector3.FORWARD,.011,true,false)
		for i in 6:mag.gun_flick_sample(Vector3.RIGHT*.01*(i+1),Vector3.FORWARD,.011,true,false)
		check(mag.reload_state=="ready","Magnum 6cm right flick closes "+dominance)
		mag.eject_magazine();mag.insert_magazine()
		for i in 5:mag.gun_flick_sample(Vector3.ZERO,Vector3.FORWARD,.011,true,false,Vector3.UP)
		for i in 6:mag.gun_flick_sample(Vector3.ZERO,Vector3.FORWARD,.011,true,false,Vector3.UP.rotated(Vector3.FORWARD,(i+1)*.07))
		check(mag.reload_state=="ready","Magnum pure right wrist-roll closes without translation "+dominance)
		mag.recoil_pitch=0;mag._kick_recoil(.05,.1);var peak:float=mag.recoil_pitch
		for i in 23:mag._recover_recoil(.01)
		check(absf(mag.recoil_pitch)<peak*.025,"Magnum below2.5percent by .23s (085slower return) independently of rate "+dominance)
		var spr=rack.weapons[13];spr.recoil_pitch=0;spr._kick_recoil(.05,.1);peak=spr.recoil_pitch
		spr._recover_recoil(.2072);check(absf(spr.recoil_pitch/peak+.30)<.015,"SPR 30percent undershoot "+dominance)
		spr._recover_recoil(.09);check(absf(spr.recoil_pitch)<.0001,"SPR settles by .28s "+dominance)
		# Legacy post-kick sine regression;071 actual emitted endpoints tested separately.
		p90.set_meta("endpoint_experiment_enabled",false)
		p90.recoil_pattern_index=0;p90.recoil_pitch=0;p90.recoil_yaw=0;var previous:=Vector2.ZERO;var plateau:=false
		for i in 45:
			p90._kick_recoil(.052,.096);var current:=Vector2(p90.recoil_pitch,p90.recoil_yaw)
			if i>1 and current.distance_to(previous)<.00001:plateau=true
			previous=current
		check(not plateau,"P90 all45 deterministic shot orientations remain distinct "+dominance)
		p90.set_meta("endpoint_experiment_enabled",true)
	for index in [3,17,23]:check(rack.weapons[index].has_meta("reflex_sight") and rack.weapons[index].get_meta("reflex_sight").style=="window","holographic window on correct weapon "+str(index))
	check(not rack.weapons[0].has_meta("reflex_sight"),"CX4 no misplaced holographic sight")
	for index in [14,15,16]:check(rack.is_catalog_active(index) and rack.weapons[index].has_method("sample_motion"),"functional sword integrated "+str(index))
	check(not rack.is_catalog_active(22) and rack.weapon_names[11]=="DUAL UZIS","single Uzi absent; dual collection retained")
	var wheel=rack.wheel;wheel.set_owned_indices([0,1,2,3,5,6]);wheel._set_highlight(wheel.SLOT_ACTIONS.find("weapon_3"));check(wheel.status_label.text=="MK18","pointed weapon selector caption")
	check(is_equal_approx(wheel.get_node("CancelMarkA").mesh.size.y,.074*1.05),"selector center X exactly5percent larger")
	var closure=load("res://scripts/closure_flick.gd").new()
	for i in 6:closure.sample(Vector3.ZERO,Vector3.FORWARD,Vector3.UP,.011,true,false)
	var accidental:=false
	for i in 25:accidental=closure.sample(Vector3(sin(i)*.004,cos(i)*.004,0),Vector3.FORWARD,Vector3.UP,.011,true,false) or accidental
	check(not accidental,"normal sub-centimetre tremor never closes")
	for i in 6:closure.sample(Vector3.ZERO,Vector3.FORWARD,Vector3.UP,.011,true,false)
	check(not closure.sample(Vector3.UP*.1,Vector3.FORWARD,Vector3.UP,.011,true,true),"held trigger blocks closure")
	check(not closure.sample(Vector3.UP*2,Vector3.FORWARD,Vector3.UP,.011,true,false),"tracking jump cannot close")
	var grenade=rack.weapons[26];var zone=rack.weapons[28];var rocket=rack.weapons[27]
	var v:=Vector3(0,7,-7);var old_range:=2*v.y*absf(v.z)/9.8;var enhanced:Vector3=grenade.prepared_velocity(v)
	check(absf((2*enhanced.y*absf(enhanced.z)/9.8)/old_range-5)<.001,"matched-angle grenade ballistic range5x")
	check(is_equal_approx(rocket.prepared_velocity(Vector3.FORWARD*200).length(),200),"rocket200m/s survives output clamp,10x old20")
	var seen_audio:Dictionary={}
	for key in ["frag_blast","zone_arm","zone_bloom","rocket_launch","rocket_impact"]:
		var stream=load("res://scripts/audio_bank.gd").sample(key);var content_hash:=hash(stream.data)
		check(stream.get_length()>.5 and stream.data.size()>128 and not seen_audio.has(content_hash),"original distinct decoded audio effect "+key)
		seen_audio[content_hash]=true # Export may store QOA; byte size is not a PCM duration.
	var world=load("res://scripts/world.gd").new();root.add_child(world);world.build();await physics_frame
	actor.position=world.player_spawn;var inventory=load("res://scripts/weapon_inventory.gd").new();root.add_child(inventory);inventory.setup(actor,rack);inventory.set_process(false);await physics_frame
	for index in [14,15,16]:check(inventory.pickups.has(index) and inventory.pickups[index].is_visible_in_tree(),"sword immediately on arrival map "+str(index))
	# Real authored mid-height service bridge in attached scene (not an equivalent box).
	for outside in [.001,.04,.09]:
		actor.position=Vector3(-2,8.001-1.65,-45.5+outside);actor.xr_enabled=true;actor.tracking_available=true;actor.xr_camera.position.y=1.65;await physics_frame
		check(actor.try_start_release_mantle(Vector3(-2,7.92,-45.51)) and absf(actor.position.y-8)<.02,"actual service bridge grazing release outside="+str(outside))
	inventory.free();world.free();rack.shutdown();rack.free();actor.free();await create_timer(.1).timeout
	print("FEEDBACK_052 checks=",checks," failures=",failures," physical_acceptance=false")
	quit(failures)
