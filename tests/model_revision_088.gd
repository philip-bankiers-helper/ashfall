extends SceneTree
class PreviewBuilder extends "res://scripts/field_builder.gd":
	# Isolate rendered targeting from support availability; full support physics has separate suites.
	func _connected_to_supported(_entries:Array)->bool:return true
class GuardSword extends "res://scripts/melee_sword.gd":
	func _vr_active()->bool:return true
class PulseFAL extends "res://scripts/catalog_firearm.gd":
	func _vr_active()->bool:return true
const Fit=preload("res://scripts/model_scale_084.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func opaque(mesh:Mesh)->bool:
	for i in mesh.get_surface_count():
		var material:=mesh.surface_get_material(i) as StandardMaterial3D
		if material==null or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or material.albedo_color.a<.999:return false
	return true
func body(node:Node,id:int)->MeshInstance3D:
	var name:="DownloadedBody077"
	if id==6:name="AggressorBody"
	elif id==1:name="DownloadedDT11Body081"
	elif id==5:name="DownloadedAWPBody081"
	elif id==8 or id==27:name="DownloadedBody085"
	elif id in [11,12]:name="Body"
	elif id==7:name="DownloadedMagnumBody081"
	elif id==19:name="ImportedTactical1911"
	elif id==9:name="DownloadedM1014Body081"
	return node.find_child(name,true,false) as MeshInstance3D
func run()->void:
	ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	var inventory=load("res://scripts/weapon_inventory.gd").new();root.add_child(inventory);inventory.player=actor;inventory.rack=rack;inventory.set_process(false)
	var expected:={0:.855,1:1.6,2:.7,3:.92,5:1.0,6:.684,7:.84,8:1.0,9:1.0,10:.72,13:1.32,17:.72,18:1.0,19:.55,20:.72,21:.9,23:.8,24:1.037875,25:1.12,27:1.6}
	for i in expected:
		var gun:Node3D=rack.weapons[i];gun.set_process(false);gun.set_physics_process(false)
		check(gun.model.scale.is_equal_approx(Vector3.ONE*float(expected[i])),rack.weapon_names[i]+" latest explicit factor")
		var prop:Node3D=inventory._create_prop(i)
		check(prop.get_child(0).scale.is_equal_approx(gun.model.scale),rack.weapon_names[i]+" actual inventory ground clone retains held root size")
		var live:=body(gun.model,i);var ground:=body(prop,i)
		# Some custom integrations use a distinct named receiver; compare all source body vertices when found.
		check(live!=null and ground!=null,rack.weapon_names[i]+" actual held and ground source bodies found")
		if live!=null and ground!=null:
			check(live.mesh==ground.mesh,rack.weapon_names[i]+" pickup shares the exact held source geometry")
			for axis in [Vector3.RIGHT,Vector3.UP,Vector3.BACK]:check(is_equal_approx((live.global_basis*axis).length(),(ground.global_basis*axis).length()),rack.weapon_names[i]+" transformed held/ground scale agrees "+str(axis))
		prop.free()
	for i in [11,12]:
		var pair:Node3D=rack.weapons[i];var prop:Node3D=inventory._create_prop(i)
		for hand in range(2):
			var canonical:Node3D=prop.find_child("CanonicalPairedUzi%d"%hand,true,false)
			check(canonical.scale.is_equal_approx(pair.guns[hand].model.scale),rack.weapon_names[i]+" real paired ground clone preserves hand "+str(hand))
			if i==12:
				pair.show();var gun:Node3D=pair.guns[hand];gun.show();gun._process(.016)
				check(gun.magazine.mesh==null,"Matador has no inherited magazine mesh after actual process")
				var visible_mag_children:=false
				for part in gun.magazine.find_children("*","MeshInstance3D",true,false):visible_mag_children=visible_mag_children or (part.mesh!=null and part.is_visible_in_tree())
				check(not visible_mag_children,"Matador has no reappearing inherited magazine children")
		prop.free()
	var p90:Node3D=rack.weapons[10]
	check(opaque(p90.model.get_node("DownloadedBody077").mesh) and opaque(p90.magazine.mesh),"P90 body and reload magazine opaque depth pass")
	check(p90.magazine.mesh==p90.loose_magazine.mesh,"opaque P90 reload variants share corrected finish")
	var dt:Node3D=rack.weapons[1]
	check(opaque(dt.model.get_node("DownloadedDT11Body081").mesh) and opaque(dt.hinge.get_node("DownloadedDT11Barrels081").mesh),"DT11 solid receiver and moving barrels opaque")
	check(not dt.hinge.get_node("ContouredForeEnd063").visible and not dt.hinge.has_node("ForeEndBarrelBridge081"),"DT11 extra authored grip/bridge absent")
	check(dt.fore_end_marker!=null and dt.fore_end_marker.position.is_equal_approx(Vector3(0,.09,-.27)),"DT11 functional reload hand marker retained")
	var heavy:Node3D=rack.weapons[8]
	check(heavy.get_meta("downloaded_heavy_085",false) and heavy.cover.has_node("DownloadedCover085") and heavy.belt.has_node("DownloadedBelt085"),"M60 actual source feed cover/belt linked to moving parts")
	check(heavy.belt_box.mesh!=null and heavy.offered_box.has_node("DownloadedMagazine085") and heavy.held_box.has_node("DownloadedMagazine085"),"M60 real source box in seated/offered/carried states")
	heavy.begin_reload();heavy.grab_magazine();heavy.insert_magazine();check(heavy.reload_state=="needs_feed","M60 box UP still requires belt feed")
	heavy.feed_belt();check(heavy.reload_state=="box_seated","M60 feed-across stage retained")
	heavy.close_cover();check(heavy.reload_state=="needs_charge","M60 cover DOWN still requires charging")
	heavy.rack_bolt();check(heavy.reload_state=="ready" and heavy.ammo>0,"M60 BACK finishes functional source reload")
	var launcher:Node3D=rack.weapons[27]
	check(launcher.get_meta("downloaded_model_077","")=="smaw" and launcher.payload.has_node("DownloadedBody085"),"Jinx Fishbones selected as actual launcher")
	var awp:Node3D=rack.weapons[5]
	check(awp.get_meta("source_scope_restored_085",false) and not awp.model.has_node("ImportedScopeRiser081"),"AWP supplied scope restored, added riser absent")
	var housing_visible:=false
	for part in awp.optic.get_children():
		if part is MeshInstance3D and part!=awp.optic.lens:housing_visible=housing_visible or part.visible
	check(not housing_visible and awp.optic.zoom_magnification==4 and awp.scoped_damping_multiplier(4,true)==2,"AWP authored housing hidden while functional4x/2xdamping survives")
	check(rack.weapons[14].model.get_meta("downloaded_model_variant_082")=="katana_alt" and rack.weapons[16].model.get_meta("downloaded_model_variant_082")=="katana","traditional Katana and Genji Cyber Blade active assignments")
	check(rack.weapons[14].shield_hint.billboard==BaseMaterial3D.BILLBOARD_FIXED_Y,"new hilt hint stays world-vertical under headset roll")
	var finish=load("res://scripts/explosive_finish_064.gd")
	for kind in ["zone","frag"]:
		var art:Node3D=finish.grenade(inventory,kind);var drawn:MeshInstance3D=art.get_node("DownloadedGrenade079")
		check(is_equal_approx(drawn.mesh.get_aabb().size.y*art.scale.y,.28 if kind=="zone" else .126),kind+" final transformed visible height")
		art.free()
		var index:int=28 if kind=="zone" else 26
		var prop:Node3D=inventory._create_prop(index)
		var held_mesh:MeshInstance3D=rack.weapons[index].model.find_child("DownloadedGrenade079",true,false)
		var ground_mesh:MeshInstance3D=prop.find_child("DownloadedGrenade079",true,false)
		check(held_mesh.mesh==ground_mesh.mesh and held_mesh.global_basis.get_scale().is_equal_approx(ground_mesh.global_basis.get_scale()),kind+" real ground inventory clone retains requested held visual size")
		prop.free()
	# Actual semi-auto body direction and shared reticle ray, rolled and upright.
	for index in [1,2,19,24]:
		var gun:Node3D=rack.weapons[index]
		for roll in [0.0,PI*.5,-PI*.5]:
			gun.global_basis=Basis.from_euler(Vector3(.2,.3,roll));gun._reticle_bounce_pitch_071=.1;gun._apply_recoil_visual()
			var projected:Transform3D=gun.get_visual_reticle_pose_071(gun.get_shot_transform())
			check((-gun.model.global_basis.z.normalized()).distance_to(-projected.basis.z.normalized())<.00001,rack.weapon_names[index]+" actual barrel and reticle share bounced direction at roll "+str(roll))
			check(gun.model.scale.is_equal_approx(Vector3.ONE*float(expected[index])),"bounce never discards requested visual fit scale")
	var bolt=load("res://scripts/build_lightning_085.gd").new();root.add_child(bolt)
	for start in [Vector3(-.3,1.2,0),Vector3(.3,1.2,0)]:
		for end in [Vector3(0,2,-3),Vector3(0,0,-2),Vector3(.5,1,-4)]:
			bolt.update_bolt(start,end,true)
			check(bolt.visible and bolt.points[0]==start and bolt.points[-1].is_equal_approx(end),"green lightning exact hand/preview endpoints, mirrored hands/wall/floor")
			check(bolt.mesh.get_surface_count()==1 and bolt.material_override.albedo_color.g>.9,"actual green rendered ribbon triangles")
	bolt.update_bolt(Vector3.ZERO,Vector3.ZERO,false);check(not bolt.visible and bolt.mesh.get_surface_count()==0,"bolt clears on cancel/release, no stale beam")
	bolt.free()
	var builder:=PreviewBuilder.new();root.add_child(builder);builder.setup(null,null,null)
	for x in [-.3,.3]:
		var state:={"eligible":true,"tracking":true,"trigger":false,"origin":Vector3(x,1.2,1.4),"direction":Vector3.FORWARD,"head":Vector3(100,100,100)}
		builder.tick_input(state);state.trigger=true;builder.tick_input(state)
		check(builder.preview_valid and builder._lightning.visible,"actual trigger-held builder shows green targeting bolt")
		check(builder._lightning.points[0]==state.origin and (builder._lightning.points[-1]-state.origin).normalized().is_equal_approx(state.direction),"actual active-hand ray drives beam rather than grid preview centre")
		state.cancel=true;builder.tick_input(state);check(not builder._lightning.visible,"actual input cancellation clears beam")
	builder.free()
	# Hold grip before joining the hilt: this formerly remained blocked until release.
	actor.xr_enabled=true;var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="guard085_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side;actor._grabs.clear();actor.left_hand_reserved=false
		for tracker in trackers.values():tracker.set_input("grip",0.0)
		var sword:=GuardSword.new();root.add_child(sword);sword.setup(actor,false);sword.set_process(false);sword.set_physics_process(false);sword._suspend_gestures()
		sword.right_hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,1.2,-.3));sword._pose_weapon()
		sword.left_hand.global_position=sword.model.to_global(sword.SUPPORT_POINT)+Vector3.RIGHT*.5;trackers[sword.left_hand].set_input("grip",1.0);sword._process(0)
		check(not sword.shield_active,side+" held grip away from hilt never activates shield")
		sword.left_hand.global_position=sword.model.to_global(sword.SUPPORT_POINT);sword._process(0)
		check(sword.shield_active and sword.shield_visual.is_visible_in_tree(),side+" already-held grip approaching real hilt activates shield")
		var plane:Transform3D=sword.shield_visual.global_transform
		check(not sword.intercept_bullet(plane*Vector3(0,0,-2),plane*Vector3(0,0,2)).is_empty(),side+" same newly activated shield blocks a front bullet")
		actor._grabs[sword.left_hand]=sword.left_hand.global_position;sword._process(0);check(not sword.shield_active,side+" existing climbing grip still owns the hand")
		actor._grabs.clear();sword.shutdown();sword.free()
		for tracker in trackers.values():tracker.set_input("grip",0.0)
		var fal:=PulseFAL.new();fal.profile_id="fal";fal.mode="semi";root.add_child(fal);fal.setup(actor,false);fal.set_process(false);fal.set_physics_process(false);rack.Arsenal.apply(fal,24)
		for roll in [PI*.5,-PI*.5,0.0]:
			fal.right_hand.global_transform=Transform3D(Basis.from_euler(Vector3(.2,.3,roll))*Basis(Vector3.RIGHT,PI*.5),Vector3(0,1.2,-.3));fal._reticle_bounce_pitch_071=.1;fal._process(.01)
			var aim:Transform3D=fal.get_visual_reticle_pose_071(fal.get_shot_transform())
			check(fal.global_basis.is_equal_approx(fal.corrected_grip_transform(fal.right_hand.global_transform).basis) and fal.get_firing_pose().is_equal_approx(aim),side+"086 tracked FAL stays raw while shot follows displayed filtered crosshair")
		fal.shutdown();fal.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.xr_enabled=false;inventory.free();rack.shutdown();rack.free();actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await process_frame
	print("MODEL_REVISION_088 checks=",checks," failures=",failures," actual_held_ground=true native_rendered=false xr_off=true");quit(failures)

