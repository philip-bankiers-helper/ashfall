extends SceneTree
const Variants=preload("res://scripts/model_variants.gd")
const Assets=preload("res://scripts/blade_assets.gd")
class FAL extends "res://scripts/catalog_firearm.gd":
	func _vr_active()->bool:return true
class UMP extends "res://scripts/compact_smg.gd":
	func _vr_active()->bool:return true
	func uses_aggressor_model()->bool:return not preload("res://scripts/asset_quality.gd").lightweight()
class DT extends "res://scripts/dt11.gd":
	func _vr_active()->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func triangles(mesh:Mesh)->int:
	var count:=0
	for surface in mesh.get_surface_count():
		var indices=mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		count+=(indices.size() if indices!=null and not indices.is_empty() else mesh.surface_get_array_len(surface))/3
	return count
func run()->void:
	ProjectSettings.set_setting("ashfall/model_alternatives",true);ProjectSettings.set_setting("ashfall/lightweight_models",true)
	check(not Variants.active() and Variants.choose("fal")=="fal","Low-Poly takes precedence over alternative skins")
	for id in ["fal_alt","ump_alt","dt11_alt","katana_alt"]:check(not ResourceLoader.has_cached("res://assets/models/download_"+id+"/model.glb"),id+" untouched at fallback startup")
	ProjectSettings.set_setting("ashfall/lightweight_models",false);ProjectSettings.set_setting("ashfall/model_alternatives",false)
	for id in ["fal","ump","katana","dt11"]:check(Variants.choose(id)==("katana_alt" if id=="katana" else id),id+" default selection retained")
	ProjectSettings.set_setting("ashfall/model_alternatives",true)
	check(Variants.choose("cyberblade")=="katana","latest Genji Cyber Blade assignment preserved")
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="alt082_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side
		for id in ["fal","ump"]:
			actor.left_hand_reserved=false
			for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
			var gun=FAL.new() if id=="fal" else UMP.new()
			if id=="fal":gun.profile_id="fal"
			root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
			gun._desktop_signals=true;var label:String=side+" "+id+" "
			var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_"+id+"_alt/asset-provenance.json"))
			var body:MeshInstance3D=gun.model.get_node("DownloadedBody077" if id=="fal" else "AggressorBody")
			check(gun.get_meta("downloaded_model_variant_082","")==id+"_alt",label+"actual runtime selects alternative source")
			check(triangles(body.mesh)+triangles(gun.magazine.mesh)+(triangles(gun.bolt.mesh) if id=="fal" else 0)==int(data.source_triangles),label+" all source triangles retained exactly once")
			check(gun.magazine.mesh.get_surface_count()>0 and gun.loose_magazine.mesh!=null,label+" actual seated and loose magazine meshes exist")
			check(gun.get_shot_transform().basis.get_scale().is_equal_approx(Vector3.ONE),label+" authoritative firing basis remains unit scale")
			var muzzle:=Vector3(0,.045,-.76 if id=="fal" else -.46)
			check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(muzzle))<.00001,label+" previous ballistic origin retained")
			if id=="ump":
				var p:Array=data.magazine_center;check(Vector3(p[0],p[1],p[2]).distance_to(gun.AggressorModel.MAGAZINE_HOME)<.000001,label+" alternate source registered to original magazine home")
				check(gun.model.scale.is_equal_approx(Vector3.ONE*.76),label+" requested35percent total reduction applied exactly once")
			gun.eject_magazine();var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
			tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(gun.get_magazine_offer_point());tracker.set_input("grip",1.0);gun._poll_vr();check(gun.reload_state=="held_mag",label+" tracked acquisition uses actual magazine well")
			hand.global_position=gun.reload_world_point(gun.get_magazine_insert_point());gun._poll_vr();check(gun.reload_state=="needs_rack",label+" UP insertion preserved")
			tracker.set_input("grip",0.0);gun._poll_vr();var at:=Vector3(-.05,.064,-.10)*(1.0 if id=="fal" else .8);hand.global_position=gun.reload_world_point(at);tracker.set_input("grip",1.0);gun._poll_vr();hand.global_position+=gun.global_basis*Vector3.BACK*.10;gun._poll_vr();check(gun.reload_state=="ready" and gun.ammo>0,label+" BACK completes actual reload")
			gun.shutdown();gun.free()
		actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
		var gun:=DT.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
		gun._desktop_signals=true
		var body:MeshInstance3D=gun.model.get_node("DownloadedDT11Body081");var moving:MeshInstance3D=gun.hinge.get_node("DownloadedDT11Barrels081")
		check(gun.get_meta("downloaded_model_variant_082","")=="dt11_alt" and triangles(body.mesh)+triangles(moving.mesh)==14458,side+" alternative DT11 source and all triangles active")
		check(triangles(moving.mesh)==3770 and not gun.hinge.get_node("ContouredForeEnd063").visible,side+" source barrels and source fore-end travel together, no duplicate fore-end")
		check(gun.fore_end_marker.position.is_equal_approx(Vector3(0,.09,-.27)) and gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,.04,-.65)))<.00001,side+" accepted support marker, hinge and firing datum retained")
		var closed:Transform3D=moving.global_transform;var stock:Transform3D=body.global_transform;gun.eject_magazine();gun.hinge.rotation.x=-.72
		check(moving.global_transform!=closed and body.global_transform==stock,side+" imported alternative breaks at actual hinge")
		var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(gun.get_reload_grab_point());tracker.set_input("grip",1.0);gun._poll_vr();hand.global_position-=gun.global_basis*Vector3.UP*.06;gun._poll_vr();check(gun.action.state=="open_loaded" and gun.action.loaded==2,side+" alternative DT11 tracked DOWN loads two shells")
		hand.global_position+=gun.global_basis*Vector3.UP*.07;gun._poll_vr();check(gun.action.state=="ready" and gun.action.ammo==2,side+" alternative DT11 tracked UP closes")
		gun.shutdown();gun.free()
	var expected:Dictionary={}
	for alternative in [false,true]:
		ProjectSettings.set_setting("ashfall/model_alternatives",alternative);var node:=Node3D.new();root.add_child(node);var built:Dictionary=Assets.build(node,"katana")
		if not alternative:expected={"base":built.base.position,"tip":built.tip.position,"grip":built.grip}
		else:
			var mesh:Mesh=node.get_node("DownloadedBlade077").mesh
			check(node.get_meta("downloaded_model_variant_082","")=="katana_alt" and triangles(mesh)==1388,"stand katana separated:1388 sword triangles,1022 stand/scabbard triangles omitted")
			check(built.base.position==expected.base and built.tip.position==expected.tip and built.grip==expected.grip,"traditional katana keeps exact accepted grip and collision endpoints")
			var distance:=INF;var normals_ok:=true
			for surface in mesh.get_surface_count():
				var arrays:=mesh.surface_get_arrays(surface)
				for p in arrays[Mesh.ARRAY_VERTEX]:distance=minf(distance,p.distance_to(expected.tip))
				for n in arrays[Mesh.ARRAY_NORMAL]:normals_ok=normals_ok and n.is_finite() and absf(n.length()-1)<.02
			check(distance<.001 and absf(mesh.get_aabb().position.y-(Assets.GRIP.y-Assets.PRIMARY_POMMEL_DISTANCE))<.001,"actual traditional mesh endpoints fit final calibrated sword length")
			check(normals_ok and mesh.get_aabb().size.x<.12,"piecewise fitted traditional sword has normalized normals and hand-sized cross-section")
			check(mesh.surface_get_material(0).albedo_texture!=null,"original traditional katana texture retained")
		node.free()
	ProjectSettings.set_setting("ashfall/model_alternatives",true)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for index in [1,6,14,24]:
		var gun=rack.weapons[index];var host:Node3D=gun.model if index==14 else gun
		check(rack.select_inventory_weapon(index) and gun.visible and str(host.get_meta("downloaded_model_variant_082","")).ends_with("_alt"),"actual rack equips alternative model at slot "+str(index))
	check(rack.weapons[16].model.get_meta("downloaded_blade_077","")=="cyberblade","production Cyber Blade keeps corrected archetype with alternatives enabled")
	rack.shutdown();rack.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);ProjectSettings.set_setting("ashfall/model_alternatives",null);await create_timer(.2).timeout
	print("MODEL_ALTERNATIVES_082 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
