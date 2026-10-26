extends SceneTree
class Pair extends "res://scripts/dual_pistols.gd":
	func _vr_active()->bool:return true
class Reserve extends Node:
	var count:=70
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,n:int)->int:
		var taken:=mini(count,n);count-=taken;return taken
	func refund_weapon_reserve(_slot:int,n:int)->int:count+=n;return n
var checks:=0
var failures:=0
var trackers:Dictionary={}
var observations:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func first(root_node:Node,label:String)->Node:return root_node.find_child(label,true,false)
func mesh_budget(node:Node)->Dictionary:
	var draws:=0;var triangles:=0
	for part in node.find_children("*","MeshInstance3D",true,false):
		if not part.is_visible_in_tree() or part.mesh==null:continue
		for i in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(i)
			var indices=arrays[Mesh.ARRAY_INDEX]
			var vertices=arrays[Mesh.ARRAY_VERTEX]
			triangles+=(indices.size() if indices!=null and indices.size()>0 else vertices.size())/3
			draws+=1
	return {"draw_surfaces":draws,"triangles":triangles}
func export_visual(node:Node3D,path:String)->void:
	var triangles:Array=[];var frame:=node.global_transform.affine_inverse()
	for part in node.find_children("*","MeshInstance3D",true,false):
		if not part.is_visible_in_tree() or part.mesh==null:continue
		var relative:Transform3D=frame*part.global_transform
		var finish:Material=part.material_override
		var color:Color=finish.albedo_color if finish is StandardMaterial3D else Color(.5,.5,.5)
		for index in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(index);var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
			if indices==null or indices.is_empty():
				indices=PackedInt32Array()
				for i in vertices.size():indices.append(i)
			for i in range(0,indices.size(),3):
				var face:Array=[]
				for j in 3:
					var point:Vector3=relative*vertices[indices[i+j]];face.append([point.x,point.y,point.z])
				triangles.append({"v":face,"color":[color.r,color.g,color.b]})
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(triangles));file.close()
func run()->void:
	# 077 retained authored asset coverage; downloaded versions have separate tracker/geometry tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="handgun063_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip"
		t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("trigger",0.0);t.set_input("grip",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	var bank:=Reserve.new();root.add_child(bank)
	for dominance in ["right","left"]:
		bank.count=1000
		actor.dominant_hand=dominance;actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("trigger",0.0);t.set_input("grip",0.0)
		actor.update_hand_input_rearm(.2)
		var gun=load("res://scripts/revolver.gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun.ammo_provider=bank;gun.ammo_slot=0
		check(gun.CAPACITY==7 and gun.ammo==7 and gun.cartridges.size()==7 and gun.offered_rounds.size()==7,dominance+" Magnum retains seven functional chambers and offers")
		check(gun.model.to_local(gun.get_shot_transform().origin).distance_to(Vector3(0,.065,-.392))<.00001,dominance+" Magnum original bore and shot origin unchanged")
		var drum=first(gun.model,"OriginalMagnumCylinderDetail063")
		check(drum!=null and gun.cylinder.is_ancestor_of(drum),dominance+" cylinder flutes/rims belong to actual moving cylinder")
		var closed:Vector3=drum.global_position;gun.eject_magazine()
		check(absf(drum.global_position.distance_to(closed)-.10)<.00001 and gun.offered.visible,dominance+" new cylinder hardware follows original open travel and offer state")
		gun.chambers[2]="empty";gun._sync()
		check(not first(gun.cartridges[2],"LiveRoundPrimer063").is_visible_in_tree() and first(gun.cartridges[1],"LiveRoundPrimer063").is_visible_in_tree(),dominance+" primer detail inherits actual live/empty chamber visibility")
		gun.chambers.fill("empty");gun._sync();gun._update_reload_visuals()
		var offer:Vector3=gun.get_reload_grab_point();gun.reload_sample(offer,true,true);gun.reload_sample(gun.mirror_point(gun.OPEN_POINT),true,true)
		check(gun.reload_state=="cylinder_loaded" and gun.ammo==7,dominance+" original FORWARD insertion still loads seven finite rounds")
		gun.reload_sample(gun.mirror_point(gun.OPEN_POINT)+Vector3.RIGHT*.06,true,true)
		check(gun.reload_state=="ready" and drum.global_position.distance_to(closed)<.00001,dominance+" original RIGHT closure restores detailed cylinder")
		gun.eject_magazine();gun.insert_magazine();gun.reload_sample(gun.mirror_point(gun.OPEN_POINT),true,true);gun.reload_sample(gun.mirror_point(gun.OPEN_POINT)+Vector3.UP*.06,true,true)
		check(gun.reload_state=="ready",dominance+" retained UP closure remains accepted")
		gun._process(0) # Export the rendered-frame state, after inherited placeholders hide.
		var magnum_budget:=mesh_budget(gun.model);check(magnum_budget.draw_surfaces<45 and magnum_budget.triangles<16000,dominance+" Magnum visual mesh budget remains bounded: "+str(magnum_budget))
		observations.append({"dominance":dominance,"model":"magnum","visible_budget":magnum_budget})
		if dominance=="right":export_visual(gun.model,"user://magnum-063-mesh.json")
		gun.shutdown();gun.free()
		var pair:=Pair.new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);pair.set_physics_process(false);pair.ammo_provider=bank;pair.ammo_slot=0;pair.update_ammo_display()
		for index in 2:
			var child=pair.guns[index];var other=pair.guns[1-index]
			var body=first(child.model,"OriginalUziReceiverDetail063")
			check(body!=null and child.spin_root.is_ancestor_of(body),dominance+" Uzi "+str(index)+" receiver detail follows original full-turn flick root")
			check(child.model.to_local(child.get_shot_transform().origin).distance_to(Vector3(0,.045,-.46))<.00001 and absf(child.model.to_local(child.magazine.global_position).z-.005)<.00001,dominance+" Uzi "+str(index)+" original bore and grip-fed magazine positions retained")
			var mag_detail=first(child.magazine,"OriginalUziMagazineDetail063");var bolt_detail=first(child.bolt,"OriginalUziChargingDetail063");var carrier_detail=first(child.firing_carrier,"OriginalUziCarrierDetail063")
			check(mag_detail!=null and bolt_detail!=null and carrier_detail!=null,dominance+" Uzi "+str(index)+" detail is parented to real magazine, bolt and firing carrier")
			var before:Vector3=bolt_detail.global_position;child.bolt.position.z+=.03
			check(absf(bolt_detail.global_position.distance_to(before)-.03)<.00001,dominance+" Uzi "+str(index)+" charging serrations move with original bolt node");child.bolt.position.z-=.03
			child.magazine.hide();check(not mag_detail.is_visible_in_tree(),dominance+" Uzi "+str(index)+" floorplate hides with actual empty magazine")
			var clone:Node3D=child.model.duplicate(0);root.add_child(clone)
			check(first(clone,"OriginalUziMagazineDetail063")!=null and not first(clone,"OriginalUziMagazineDetail063").is_visible_in_tree(),dominance+" Uzi "+str(index)+" cloned model retains magazine detail visibility state");clone.free();child.magazine.show()
			trackers[child.right_hand].set_input("trigger",0.0);child._process(0);child.cooldown=0
			var amount:int=child.ammo;var other_amount:int=other.ammo
			trackers[child.right_hand].set_input("trigger",1.0);child._process(.001);child.cooldown=0;child._process(.001)
			check(child.ammo==amount-2 and other.ammo==other_amount,dominance+" Uzi "+str(index)+" held trigger remains automatic and independent")
			trackers[child.right_hand].set_input("trigger",0.0);child._process(0);child.ammo=0;child.eject_magazine();child._reset_flick()
			for i in 4:child.flick_sample(Vector3.ZERO,Vector3.FORWARD,.05,true,false)
			child.flick_sample(Vector3.UP*.15,Vector3.FORWARD,.1,true,false)
			check(child.ammo==child.magazine_size and other.ammo==other_amount and child.spin_elapsed==0,dominance+" Uzi "+str(index)+" independent occupied-hand UP flick still reloads")
			child._process(.18)
			check(absf(child.spin_root.rotation.x)>1.0 and child.spin_root.is_ancestor_of(mag_detail),dominance+" Uzi "+str(index)+" magazine detail participates in cosmetic flip")
			child._process(.20);var budget:=mesh_budget(child.model)
			if dominance=="right" and index==0:export_visual(child.model,"user://uzi-063-mesh.json")
			check(budget.draw_surfaces<35 and budget.triangles<12000,dominance+" Uzi "+str(index)+" mesh budget bounded: "+str(budget));observations.append({"dominance":dominance,"model":"uzi","hand":index,"visible_budget":budget})
		pair.shutdown();pair.free()
	var matadors:=Pair.new();matadors.shotgun_mode=true;root.add_child(matadors);matadors.setup(actor,false);matadors.set_process(false);matadors.set_physics_process(false)
	check(first(matadors.guns[0].model,"OriginalUziReceiverDetail063")==null and first(matadors.guns[1].model,"OriginalUziReceiverDetail063")==null,"Matador branch receives no Uzi finish or silhouette changes");matadors.shutdown();matadors.free()
	var file:=FileAccess.open("user://handgun-models-063.json",FileAccess.WRITE);file.store_string(JSON.stringify(observations,"\t"));file.close();print("MODEL_RECORDS=",JSON.stringify(observations))
	for t in trackers.values():XRServer.remove_tracker(t)
	bank.free();actor.free();await create_timer(.1).timeout
	print("HANDGUN_MODELS_063 checks=",checks," failures=",failures," actual_production_model_nodes=true native_rendered=false headset_tested=false")
	quit(failures)
