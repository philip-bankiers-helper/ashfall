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
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for i in range(5):
		var gun=rack.weapons[i]
		var labels=gun.find_children("*","Label3D",true,false)
		check(labels.size()==1 and labels[0]==gun.ammo_label,"slot%d runtime only ammo text exists"%i)
	for gun in rack.weapons:check(not gun.muzzle_flash.visible,"all weapon flashes hidden before first process")
	var pump=rack.weapons[4]
	var wrist=pump.model.get_node("TraditionalWoodWrist")
	check(wrist.mesh is ArrayMesh and wrist.mesh.get_aabb().size.z>.11 and wrist.mesh.get_aabb().size.y<.08,"pump wrist tapered/sloped wood rather than vertical magazine box")
	check(pump.model.find_children("TraditionalTriggerGuard*","MeshInstance3D",true,false).size()==3,"pump thin trigger guard separates wrist from loading port")
	rack.select_inventory_weapon(4);pump.cooldown=0
	check(pump.chambered and pump.tube_rounds==4 and pump.ammo==5,"pump starts one chamber four tube")
	pump.fire()
	check(not pump.chambered and pump.tube_rounds==4 and pump.ammo==4 and pump.spent_chamber,"shot consumes chamber only")
	pump.cooldown=0;pump.fire()
	check(pump.ammo==4,"unchambered pump cannot fire")
	pump.pump_sample(false,pump.PUMP_REST,true);pump.pump_sample(true,pump.PUMP_REST,true)
	pump.pump_sample(true,pump.PUMP_REST+Vector3(0,0,.13),true)
	check(pump.reload_state=="needs_pump_forward" and not pump.spent_chamber,"rear stroke extracts spent case only")
	pump.pump_sample(true,pump.PUMP_REST,true)
	check(pump.chambered and pump.tube_rounds==3 and pump.ammo==4,"forward stroke chambers exactly one tube round")
	var reserve:int=rack.reserves.shells
	pump.grab_magazine();pump.insert_magazine()
	check(pump.tube_rounds==4 and pump.ammo==5 and rack.reserves.shells==reserve-1,"single underreceiver shell insertion tops off one")
	pump.grab_magazine();pump.insert_magazine()
	check(pump.ammo==5 and rack.reserves.shells==reserve-1,"full tube rejects extra shell without spending")
	pump.chambered=false;pump.tube_rounds=0;pump.spent_chamber=false;pump.reload_state="needs_pump_back";pump._sync_rounds();rack.reserves.shells=1
	pump.grab_magazine();pump.insert_magazine()
	check(not pump.chambered and pump.tube_rounds==1 and pump.ammo==1 and rack.reserves.shells==0,"empty single remaining reserve goes only to tube")
	pump.pump_sample(false,pump.PUMP_REST,true);pump.pump_sample(true,pump.PUMP_REST,true);pump.pump_sample(true,pump.PUMP_REST+Vector3(0,0,.13),true);pump.pump_sample(true,pump.PUMP_REST,true)
	check(pump.chambered and pump.tube_rounds==0 and pump.ammo==1,"partial tube chambering conserves count")
	pump.grab_magazine();pump.insert_magazine()
	check(pump.ammo==1 and rack.reserves.shells==0,"zero reserve no shell creation")
	pump._process(0)
	check(not pump.magazine.visible and not pump.hip_source.visible and not pump.bolt.visible and not pump.shell_offer.visible,"pump no magazine riflehandle or zeroreserve offer")
	check(pump.model.find_child("UnderReceiverShellPort",true,false)!=null and pump.pump.name=="SlidingForeEnd","pump distinct shell port and sliding fore-end geometry")
	var double=rack.weapons[1]
	check(not double.shell_pair.visible and not double.shell_offer.visible and not double.insert_guide.visible,"closed Cinder hides shell offer and reload props before first process")
	double.reset_weapon()
	check(not double.muzzle_flash.visible and not double.shell_pair.visible and not double.shell_offer.visible,"Cinder reset starts clean without first process")
	rack.reserves.shells=1;double.eject_magazine();double.grab_magazine();double.insert_magazine()
	check(double.chamber_states==["live","empty"] and double.get_loaded_rounds()==1 and rack.reserves.shells==0,"break action partial reserve displays only one live chamber")
	double.rack_bolt();double.cooldown=0;double._semi_release=true;double.fire()
	check(double.chamber_states==["live","spent"] or double.chamber_states==["spent","empty"],"break action fired chamber shows spent cap")
	double.eject_magazine()
	check(double.chamber_states==["empty","empty"] and not double.chamber_live[0].visible and not double.chamber_live[1].visible,"opening ejects and reveals two empty mouths")
	check(double.hinge.find_children("OpenChamberMouth*","MeshInstance3D",true,false).size()==2,"break action has two separate ring chamber mouths")
	double.hinge.rotation.x=-.72
	var target:Vector3=double.get_chamber_insert_point()
	check(target.distance_to(double.to_local((double.chamber_markers[0].global_position+double.chamber_markers[1].global_position)*.5))<.0001,"break action insertion target follows actual opened hinge")
	check(pump.get_reload_hint()=="" and double.get_reload_hint()=="","shotguns no reload instruction HUD")
	rack.shutdown();await create_timer(.35).timeout;rack.free();actor.free();await process_frame
	print("SHOTGUNS_041 checks=",checks," failures=",failures)
	quit(failures)


