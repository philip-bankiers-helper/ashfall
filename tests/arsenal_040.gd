extends SceneTree
var passed:=0
var failed:=0
var shots:=0
var pellets:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;printerr("FAIL ",label)
func run()->void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.field_menu.set_open(false)
	game.paused=false
	game.player.input_enabled=true
	var rack=game.weapon
	rack.inventory=null # Mechanical all-five fixture; ownership is tested separately.
	rack.set_process(false)
	for weapon in rack.weapons:weapon.set_process(false);weapon.set_physics_process(false)
	rack.shot.connect(func(_a,_b,_c):shots+=1)
	rack.pellet_shot.connect(func(_a,_b,_c):pellets+=1)
	check(rack.weapons.size()==12,"actual Main rack owns twelve real weapon types")
	for i in range(5):
		check(rack.select_inventory_weapon(i),"select slot %d"%i)
		check(rack.active_id==rack.weapon_ids[i],"identity slot %d"%i)
		check(rack.weapons[i].visible,"selected model visible %d"%i)
	var pistol=rack.weapons[2]
	rack.select_inventory_weapon(2)
	pistol._semi_armed=true
	pistol.cooldown=0
	var before=shots
	pistol.fire()
	check(shots==before+1 and pistol.ammo==11,"pistol actual rack shot and ammo")
	pistol.cooldown=0;pistol.fire()
	check(shots==before+1,"pistol held press cannot auto fire")
	pistol._process(0.3);pistol.fire()
	check(shots==before+2,"pistol neutral release rearms")
	check(pistol.recoil_pitch>0 and pistol.recoil>0,"pistol visual recoil")
	pistol.eject_magazine();pistol.grab_magazine();pistol.insert_magazine()
	check(pistol.reload_state=="needs_rack" and pistol.ammo==0,"pistol magazine requires slide")
	pistol.rack_bolt()
	check(pistol.reload_state=="ready" and pistol.ammo==12,"pistol physical state reload capacity")
	var burst=rack.weapons[3]
	rack.select_inventory_weapon(3)
	burst._burst_armed=true;burst.cooldown=0
	before=shots
	burst.fire()
	check(shots==before+1 and burst.burst_remaining==2,"burst first shot immediate")
	burst._process(0.08)
	check(shots==before+1,"burst cannot beat 85ms cadence")
	burst._process(0.006)
	check(shots==before+2 and burst.burst_remaining==1,"burst second at cadence")
	burst._process(0.086)
	check(shots==before+3 and burst.ammo==24 and burst.burst_remaining==0,"burst three real rounds and ammo")
	check(is_equal_approx(burst.cooldown,0.3),"burst recovery delay")
	burst.eject_magazine();burst.grab_magazine();burst.insert_magazine();burst.rack_bolt()
	check(burst.ammo==27 and burst.reload_state=="ready","burst tracked magazine-rack capacity")
	var pump=rack.weapons[4]
	rack.select_inventory_weapon(4)
	pump.cooldown=0
	var pellet_before=pellets
	pump.fire()
	check(pellets==pellet_before+1 and pump.ammo==4 and pump.reload_state=="needs_pump_back","pump emits rack pellets and requires action")
	pump.cooldown=0.65;pump.fire()
	check(pellets==pellet_before+1,"pump cannot fire without manual cycle")
	pump.pump_sample(false,pump.PUMP_REST,true)
	pump.pump_sample(true,pump.PUMP_REST,true)
	pump.pump_sample(true,pump.PUMP_REST+Vector3(0,0,0.13),true)
	check(pump.reload_state=="needs_pump_forward","held tracked pull opens action")
	pump.pump_sample(true,pump.PUMP_REST+Vector3(0,0,0.07),true)
	check(pump.reload_state=="needs_pump_forward","partial forward does not chamber")
	pump.pump_sample(true,pump.PUMP_REST,true)
	check(pump.reload_state=="ready" and pump.ammo==4,"held tracked full forward chambers without free ammo")
	check(pump.cooldown>=0.65,"pump completion preserves minimum shot recovery")
	pump.cooldown=0;pump.fire()
	pump.pump_sample(false,pump.PUMP_REST,true)
	pump.pump_sample(true,pump.PUMP_REST,true)
	pump.pump_sample(true,pump.PUMP_REST+Vector3(0,0,0.13),true)
	pump.pump_sample(false,pump.PUMP_REST,true)
	check(pump.reload_state=="needs_pump_back","release mid-cycle cancels contact")
	pump.pump_sample(true,pump.PUMP_REST,false)
	check(not pump._pump_contact,"tracking loss cancels pump")
	pump.desktop_reload_step();pump.desktop_reload_step()
	check(pump.reload_state=="ready","desktop explicit two-stroke debug action")
	while pump.tube_rounds<4:pump.grab_magazine();pump.insert_magazine()
	check(pump.ammo==5,"pump individual shell top-off capacity")
	for hand in ["left","right"]:
		game.player.dominant_hand=hand
		rack._refresh_hands()
		for weapon in rack.weapons:check(weapon.right_hand==game.player.get_weapon_hand() and weapon.left_hand==game.player.get_support_hand(),"role mirrors "+hand)
	for hand in ["left","right"]:
		game.player.dominant_hand=hand
		rack._refresh_hands()
		rack.select_inventory_weapon(0)
		var primary=game.player.get_weapon_hand()
		var secondary=game.player.get_support_hand()
		var primary_raw:Transform3D=primary.global_transform
		var secondary_raw:Transform3D=secondary.global_transform
		game.player.animate_hand(primary,0,0,1)
		check(primary.get_node("ArticulatedGlove/Middle").rotation.x< -1.0 and primary.get_node("ArticulatedGlove/Index").rotation.x< -0.6,hand+" dominant fingers close around gun and trigger")
		rack.weapons[0].supported=true
		game.player.animate_hand(secondary,0,0,1)
		check(secondary.get_node("ArticulatedGlove/Middle").rotation.x< -1.0 and secondary.get_node("ArticulatedGlove/Thumb").rotation.x< -0.7,hand+" support fingers and thumb close around foregrip")
		check(primary.global_transform.is_equal_approx(primary_raw) and secondary.global_transform.is_equal_approx(secondary_raw),hand+" grip pose preserves both raw tracked transforms")
		rack.set_holstered(true)
		game.player.animate_hand(primary,0,0,1)
		check(absf(primary.get_node("ArticulatedGlove/Middle").rotation.x+0.1)<0.001,hand+" holster releases forced finger curl")
	rack.set_holstered(true)
	before=shots;pellet_before=pellets
	rack.fire()
	check(shots==before and pellets==pellet_before,"holster blocks every rack shot")
	rack.shutdown()
	await create_timer(0.35).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.35).timeout
	print("ARSENAL_040 ",passed," passed / ",failed," failed")
	quit(1 if failed else 0)





