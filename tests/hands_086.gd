extends SceneTree
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
	for hand in [actor.left_hand,actor.right_hand]:
		var rig:Node3D=actor._hand_visuals[hand];var adapter:Node3D=rig.get_node("SkinnedGlove086")
		check(adapter.skeleton.get_bone_count()==26,"real26bone source hand")
		check(not rig.get_node("GripSurface").visible,"procedural geometry hidden in imported hand mode")
		var mesh:MeshInstance3D=adapter.skin.find_child("mesh_Glove_low_*",true,false)
		check(mesh!=null and mesh.skin!=null and mesh.mesh.get_faces().size()/3==1160,"real skinned1160triangle source geometry")
		check(mesh.material_override.albedo_texture!=null and mesh.material_override.orm_texture!=null,"source camo and surface detail textures")
		check((adapter.skin.transform*adapter.palm_reference).distance_to(Vector3(0,.032,0))<.00001,"source anatomical palm datum aligned to grip surface")
		var index:int=adapter.skeleton.find_bone("Index_Intermediate_L" if hand==actor.left_hand else "Index_Intermediate_R")
		adapter.update_pose(0,0,{"role":"free"},1)
		var before:Quaternion=adapter.skeleton.get_bone_pose_rotation(index)
		adapter.update_pose(0,1,{"role":"free"},1)
		check(before.angle_to(adapter.skeleton.get_bone_pose_rotation(index))>.1,"real skin index finger responds to trigger independently")
	for side in ["left","right"]:
		actor.dominant_hand=side;rack._refresh_hands()
		for i in rack.ACTIVE_WEAPON_INDICES:
			rack.selected=i;rack.is_holstered=false;rack._apply_selection()
			var gun:Node3D=rack.weapons[i];gun.set_process(false);gun.set_physics_process(false)
			if gun.has_method("get_reticle_entries"):
				for child in gun.guns:child.show()
			var hand:XRController3D=actor.get_weapon_hand();var raw:Transform3D=hand.global_transform
			var contact:Dictionary=actor.get_hand_art_contact(hand)
			if contact.role!="firing":continue
			actor.animate_hand(hand,1,.3,1.0/90)
			var rig:Node3D=actor._hand_visuals[hand];var adapter:Node3D=rig.get_node("SkinnedGlove086")
			check(rig.global_position.distance_to(contact.weapon.model.to_global(contact.center))<.00001,side+" weapon-specific actual palm anchor "+rack.weapon_names[i])
			check(adapter.skin.global_basis.get_scale().is_equal_approx(Vector3.ONE),side+" human hand stays unscaled "+rack.weapon_names[i])
			check(hand.global_transform.is_equal_approx(raw),side+" hand presentation never rewrites tracked controller "+rack.weapon_names[i])
			var finite:=true
			for bone in adapter.skeleton.get_bone_count():finite=finite and adapter.skeleton.get_bone_global_pose(bone).is_finite()
			check(finite,side+" all posed bones finite "+rack.weapon_names[i])
	check(FileAccess.get_file_as_string("res://assets/hands/xrtools086/License.md").contains("Miodrag Sejic"),"source CC0 attribution retained")
	rack.shutdown();rack.free();actor.free()
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	check(actor.left_hand.get_node("ArticulatedGlove").get_node_or_null("SkinnedGlove086")==null,"original LowPoly fallback remains available")
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null)
	print("HANDS_086 checks=",checks," failures=",failures," actual_skin=true xr_off=true native_appearance_unverified=true");quit(failures)
