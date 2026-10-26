extends SceneTree
class Catalog extends "res://scripts/catalog_firearm.gd":
	func _vr_active()->bool:return true
class PDW extends "res://scripts/top_feed_pdw.gd":
	func _vr_active()->bool:return true
class MK extends "res://scripts/burst_carbine.gd":
	func _vr_active()->bool:return true
class SPR extends "res://scripts/spr.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	var factors:={0:.9,1:1.6,2:.7,3:.92,5:1.0,6:.76,7:.84,8:1.0,9:1.0,10:.8,13:1.32,17:.72,18:1.0,19:.55,20:.72,21:.9,23:.8,24:1.037875,25:.8,27:1.6}
	for i in factors:
		var gun:Node3D=rack.weapons[i];gun.set_process(false);gun.set_physics_process(false)
		check(gun.model.scale.is_equal_approx(Vector3.ONE*float(factors[i])),rack.weapon_names[i]+" requested final root factor applied once")
		check(gun.get_shot_transform().basis.get_scale().is_equal_approx(Vector3.ONE),rack.weapon_names[i]+" authoritative shot ray remains unit and angular-only")
		var logical:=Vector3(.045,-.14,-.21)
		if gun.visual_model_scale()<1.0 and i!=27:
			check(gun._in_reload_reach(logical+Vector3.RIGHT*(.20/gun.visual_model_scale()),logical,.18),rack.weapon_names[i]+" still accepts20cm physical reach after shrink")
		check(gun.reload_local_point(gun.reload_world_point(logical)).distance_to(logical)<.00001,rack.weapon_names[i]+" scaled reload world/logical round trip")
	for i in [11,12]:
		var pair:Node3D=rack.weapons[i]
		check(pair.guns.size()==2 and pair.guns[0].model.scale.is_equal_approx(Vector3.ONE*(.64 if i==11 else .9)) and pair.guns[1].model.scale.is_equal_approx(Vector3.ONE*(.64 if i==11 else .9)),rack.weapon_names[i]+" both independent drawn guns shrink once")
		for gun in pair.guns:
			check(gun.get_meta("downloaded_pair_084","")==("uzi" if i==11 else "matadors") and gun.spin_root.has_node("DownloadedPair084"),"source model actually belongs to occupied-hand flick spin root")
			var body:MeshInstance3D=gun.spin_root.get_node("DownloadedPair084/Body")
			check(body.mesh.surface_get_material(0) is StandardMaterial3D and body.mesh.surface_get_material(0).albedo_texture!=null,"paired source material imports real texture, including specular/glossiness conversion")
		var other_ammo:int=pair.guns[1].ammo;pair.guns[0].ammo=0;pair.guns[0].reload_state="needs_mag"
		check(pair.guns[0].reload_flick() and pair.guns[0].ammo==pair.guns[0].magazine_size and pair.guns[1].ammo==other_ammo,"downloaded pair retains occupied-hand upward reload with independent ammunition")
	var spr:Node3D=rack.weapons[13]
	check(spr.get_meta("downloaded_model_077","")=="spr" and spr.optic.lens.mesh.size==Vector2(.11,.065),"M4 SPR retains broad rectangular lens")
	check(spr.magazine_size==int(preload("res://scripts/arsenal_data.gd").profile(13).magazine_per_hand) and spr.get_script().resource_path=="res://scripts/spr.gd" and spr._semi_armed,"SPR remains semiautomatic magazine/handle rifle, not AWP bolt action")
	check((spr.optic.lens.global_basis.get_scale()-Vector3.ONE*1.1).length()<.00001,"SPR rectangular aperture receives 086half085size, rifle unchanged")
	spr._semi_armed=true;spr._requires_trigger_release=false;spr.cooldown=0;var before:int=spr.ammo;spr.fire();spr.cooldown=0;spr.fire()
	check(spr.ammo==before-1,"SPR fires exactly once per trigger press even when cooldown expires")
	spr.reset_weapon()
	var tec:Node3D=rack.weapons[20]
	check(tec.get_meta("primary_grip_084").is_equal_approx(Vector3(0,-.057,-.025)),"TEC9 rendered primary fist moved forward3cm after0.6scale")
	var p90:Node3D=rack.weapons[10]
	check(p90.get_meta("primary_grip_084").is_equal_approx(Vector3(0,-.057,.025)) and p90.magazine.mesh.get_faces().size()/3==4612,"P90 trigger-side primary grip and real source top-magazine/end caps")
	for id in ["p90","mk18","s85","spr"]:
		var index:int={"p90":10,"mk18":3,"s85":25,"spr":13}[id];var gun:Node3D=rack.weapons[index]
		var body:MeshInstance3D=gun.model.get_node("DownloadedBody077")
		var b:AABB=body.mesh.get_aabb();var span:Vector3=gun.model.global_basis*(Vector3(0,0,b.size.z))
		check(span.length()<(1.6 if id=="spr" else 1.1) and span.length()>.15,id+" actual transformed source body span is finite and no hidden giant import scale")
		check(body.mesh.surface_get_material(0)!=null and gun.magazine.mesh==gun.loose_magazine.mesh,id+" source finishes and actual reload magazine persist")
	for i in [14,16,29]:
		var blade:Node3D=rack.weapons[i]
		check(blade.model.scale.is_equal_approx(Vector3.ONE),rack.weapon_names[i]+" calibrated melee length unchanged")
		if i==14:
			var drawn:MeshInstance3D=blade.model.get_node("DownloadedBlade077")
			var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_katana_alt/asset-provenance.json"))
			var a:Array=data.get("target_pommel",data.target);var b:Array=data.contact_tip;var pommel:=Vector3(a[0],a[1],a[2]);var tip:=Vector3(b[0],b[1],b[2]);var axis:Vector3=(tip-pommel).normalized()
			check(drawn.get_meta("long_axis_roll_degrees_084",0)==360 and (drawn.transform*tip).distance_to(tip)<.00001 and (drawn.transform*pommel).distance_to(pommel)<.00001,"katanaadditional180degree longitudinal roll fixes both pommel and tip endpoints")
			check((drawn.basis*Vector3.RIGHT).distance_to(Vector3.RIGHT)<.001 and (drawn.basis*axis).distance_to(axis)<.001,"katana blade faces reversed about long axis without rotating shield")
			check(blade.shield_visual.get_child_count()==4 and blade.shield_visual.get_child(0).mesh is BoxMesh,"shield has actual bright border geometry independent of faint translucent shader")
	check(rack.weapons[16].model.get_meta("downloaded_model_variant_082","")=="katana","Genji now Cyber Blade; gold-handled source excluded")
	rack.shutdown();rack.free();actor.free()
	# Actual tracker input path at the scaled source geometry, both dominant hands.
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="fit084_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["left","right"]:
		actor.dominant_hand=side
		for id in ["p90","mk18","s85","spr"]:
			actor.left_hand_reserved=false
			for tracker in trackers.values():tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0)
			var gun=PDW.new() if id=="p90" else (MK.new() if id=="mk18" else (SPR.new() if id=="spr" else Catalog.new()))
			if id=="s85":gun.profile_id="s85";gun.mode="semi"
			root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._desktop_signals=true
			var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
			gun.eject_magazine();tracker.set_input("grip",0.0);gun._poll_vr()
			var offer:Vector3=gun.get_top_offer() if id=="p90" else gun.get_magazine_offer_point()
			hand.global_position=gun.reload_world_point(offer);tracker.set_input("grip",1.0);gun._poll_vr()
			check(gun.reload_state=="held_mag",side+" "+id+" grip at scaled source offer acquires actual magazine")
			hand.global_position=gun.reload_world_point(gun.get_top_seat() if id=="p90" else gun.get_magazine_insert_point());gun._poll_vr()
			check(gun.reload_state=="needs_rack",side+" "+id+" proper forward/up path seats source magazine")
			tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(gun.get_charge_point() if id=="p90" else Vector3(-.05,.064,-.10));tracker.set_input("grip",1.0);gun._poll_vr();hand.global_position+=gun.global_basis*Vector3.BACK*.10;gun._poll_vr()
			check(gun.reload_state=="ready" and gun.ammo>0,side+" "+id+" real scaled-frame back rack chambers ammo")
			gun.shutdown();gun.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("MODEL_REVISION_084 checks=",checks," failures=",failures," actual_models=true synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
