extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	await process_frame;await physics_frame
	game.set_process(false);game.player.set_process(false);game.player.set_physics_process(false);game.field_menu.set_open(false);game.player.input_enabled=true
	var rack=game.weapon;rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	check(rack.reserves=={"rifle":180,"pistol":72,"shells":48},"finite original checkpoint defaults")
	for side in ["left","right"]:
		game.player.dominant_hand=side;rack._refresh_hands()
		for i in range(5):
			rack.select_inventory_weapon(i);rack.refresh_ammo_displays()
			var gun=rack.weapons[i];var panel=gun.ammo_panel
			var state=rack.get_ammo_display_state(i)
			check(gun.ammo_label.text=="%d/%d"%[state.loaded,state.reserve],side+" slot%d exact numeric loaded/reserve"%i)
			check(gun.ammo_label.get_parent()==panel and panel.get_parent()==gun.model,side+" slot%d side paint replaced by protruding panel"%i)
			check(absf(panel.position.x)-panel.dimensions.x*.5>=.059 and panel.dimensions.y<=.0141 and panel.dimensions.x<.075,side+" slot%d tiny panel clears central sights"%i)
			check(panel.position.x>0 if side=="left" else panel.position.x<0,side+" slot%d panel mirrors side"%i)
			var to_eye:Vector3=(gun.camera.global_position-panel.global_position).normalized()
			check(panel.global_basis.z.dot(to_eye)>.999,side+" slot%d panel faces viewer"%i)
			check(panel.connector.get_parent()==gun.model and absf(panel.connector.position.x)>.04 and panel.connector.mesh.size.x>.03,side+" slot%d tiny physical connector links receiver"%i)
	for i in range(5):
		var gun=rack.weapons[i]
		var family=rack.AMMO_FAMILIES[i]
		if i==4:gun.chambered=false;gun.tube_rounds=0;gun.reload_state="needs_pump_back";gun._sync_rounds()
		rack.reserves[family]=1
		gun.eject_magazine();gun.grab_magazine();gun.insert_magazine()
		check(rack.reserves[family]==0 and gun.get_loaded_rounds()==1,"slot%d partial reserve loads exactly one physical round"%i)
		if i==4:gun.desktop_reload_step();gun.desktop_reload_step()
		else:gun.rack_bolt()
		rack.refresh_ammo_displays()
		check(gun.ammo==1 and gun.ammo_label.text=="1/0","slot%d partial reload exact display"%i)
		gun.cooldown=0
		if i==1:gun._semi_release=true
		if i==2:gun._semi_armed=true
		if i==3:gun._burst_armed=true
		gun.fire()
		check(gun.ammo==0 and gun.ammo_label.text=="0/0","slot%d last shot updates numeric panel immediately"%i)
		gun.eject_magazine();gun.grab_magazine();gun.insert_magazine();gun.rack_bolt()
		check(gun.ammo==0 and gun.get_loaded_rounds()==0,"slot%d zero reserves cannot create ammo"%i)
		gun.update_ammo_display()
		check(not gun.shell_offer.visible if i in [1,4] else not gun.hip_source.visible,"slot%d zero reserve hides unusable offer"%i)
		gun.reset_weapon()
	rack.reserves={"rifle":10,"pistol":10,"shells":10}
	rack.refresh_ammo_displays()
	check(rack.consume_reserve("rifle",3)==3 and rack.get_ammo_display_state(0).reserve==7 and rack.get_ammo_display_state(3).reserve==7,"rifle/carbine share real reserve")
	check(rack.weapons[0].ammo_label.text.ends_with("/7") and rack.weapons[3].ammo_label.text.ends_with("/7"),"shared family panels refresh immediately")
	check(rack.add_reserve("shells",4)==4 and rack.get_ammo_display_state(1).reserve==14 and rack.get_ammo_display_state(4).reserve==14,"shotguns share pickup credit")
	check(rack.add_reserve("rifle",-10)==0 and rack.consume_reserve("rifle",-10)==0 and rack.add_reserve("unknown",10)==0,"negative and unknown family rejected")
	rack.reserves.pistol=9998
	check(rack.add_reserve("pistol",99)==1 and rack.add_reserve("pistol",1)==0,"bounded credit returns only actual accepted rounds")
	var pickups=load("res://scripts/ammo_pickups.gd").new();root.add_child(pickups);pickups.set_physics_process(false)
	var origin:Vector3=game.player.get_view_camera().global_position-Vector3.UP*.1
	pickups.setup(game.player,rack,[origin,origin,origin])
	rack.reserves={"rifle":0,"pistol":0,"shells":0}
	pickups._physics_process(.2)
	check(rack.reserves=={"rifle":60,"pistol":24,"shells":12},"actual supply pickup script credits real family inventory")
	pickups._physics_process(.2)
	check(rack.reserves=={"rifle":60,"pistol":24,"shells":12},"collected boxes cannot duplicate credit")
	rack.reset_weapon()
	check(rack.reserves==rack.INITIAL_RESERVES,"explicit checkpoint reset restocks defaults")
	pickups.free();rack.shutdown();await create_timer(.35).timeout;game.queue_free();await process_frame;await create_timer(.35).timeout
	print("AMMO_PANEL_040 checks=",checks," failures=",failures)
	quit(failures)



