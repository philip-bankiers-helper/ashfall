extends SceneTree
class TestUMP extends "res://scripts/compact_smg.gd":
	func _vr_active()->bool:return true
	func uses_aggressor_model()->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func tris(mesh:Mesh)->int:
	var count:=0
	for s in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(s);count+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	return count
func dump_mesh(node:Node,at:Transform3D,out:Array)->void:
	if node is Node3D:at=at*node.transform
	if node is MeshInstance3D and node.visible and node.mesh:
		for s in node.mesh.get_surface_count():
			var a:Array=node.mesh.surface_get_arrays(s);var points:Array=[];var uv:Array=[]
			for v in a[Mesh.ARRAY_VERTEX]:var p:Vector3=at*v;points.append([p.x,p.y,p.z])
			if a[Mesh.ARRAY_TEX_UV]!=null:for v in a[Mesh.ARRAY_TEX_UV]:uv.append([v.x,v.y])
			var m:Material=node.material_override if node.material_override else node.mesh.surface_get_material(s)
			var c:Color=m.albedo_color if m is StandardMaterial3D else Color(.5,.5,.5)
			out.append({"name":node.name,"positions":points,"uv":uv,"indices":Array(a[Mesh.ARRAY_INDEX]) if a[Mesh.ARRAY_INDEX]!=null else [],"texture":m is StandardMaterial3D and m.albedo_texture!=null,"color":[c.r,c.g,c.b]})
	for child in node.get_children():dump_mesh(child,at,out)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="ump074_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO);trackers[hand]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	var gun:=TestUMP.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);load("res://scripts/arsenal_data.gd").apply(gun,6)
	check(tris(gun.model.get_node("AggressorBody").mesh)==10119,"body contains all non-magazine source triangles")
	check(tris(gun.magazine.mesh)==302,"whole302-triangle source magazine isolated")
	check(gun.hip_source.get_child(0).mesh==gun.loose_magazine.mesh and gun.loose_magazine.mesh.get_aabb().size.distance_to(gun.magazine.mesh.get_aabb().size*.76)<.00001,"held and offered magazines match the uniformly smaller seated magazine")
	check(gun.model.get_node("AggressorBody").mesh.surface_get_material(0).albedo_texture!=null,"original atlas texture retained")
	for mesh in [gun.model.get_node("AggressorBody").mesh,gun.magazine.mesh]:
		var finite:=true;var attributes:Array=mesh.surface_get_arrays(0)
		for point in attributes[Mesh.ARRAY_VERTEX]:finite=finite and point.is_finite()
		for normal in attributes[Mesh.ARRAY_NORMAL]:finite=finite and normal.is_finite() and normal.length()>.99
		check(finite and attributes[Mesh.ARRAY_TEX_UV].size()==attributes[Mesh.ARRAY_VERTEX].size(),"source geometry has finite unit normals and complete texture coordinates")
	check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,.045,-.46)))<.00001,"existing muzzle datum unchanged")
	check(gun.model.to_global(gun.magazine.position).distance_to(gun.to_global(gun.get_magazine_insert_point()))<.00001,"insertion contact exactly matches actual magazine center")
	var shots:Array=[];gun.shot.connect(func(o:Vector3,d:Vector3,_damage:float):shots.append([o,d]))
	for side in ["right","left"]:
		actor.dominant_hand=side;gun.refresh_hands();gun.reset_weapon();load("res://scripts/arsenal_data.gd").apply(gun,6);gun.cooldown=0;gun._requires_trigger_release=false
		check(gun.fire_interval>0 and gun.magazine_size==28,side+" UMP production tuning retained")
		gun.fire();check(shots.size()>0,side+" actual shot emitted")
		gun.eject_magazine();gun._process(0);check(not gun.magazine.visible and gun.hip_source.visible,side+" eject removes all seated magazine geometry and offers new mesh")
		var hand:XRController3D=gun.left_hand;var t=trackers[hand];t.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(gun.get_magazine_offer_point());t.set_input("grip",1.0);gun._poll_vr()
		check(gun.reload_state=="held_mag",side+" actual offhand grip takes source magazine")
		gun._process(0);check(gun.loose_magazine.visible,side+" cut magazine visible in hand")
		hand.global_position=gun.reload_world_point(gun.get_magazine_insert_point());gun._poll_vr();check(gun.reload_state=="needs_rack",side+" upward insertion seats source magazine")
		gun._process(0);check(gun.magazine.visible and not gun.loose_magazine.visible,side+" held copy hidden when seated")
		t.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.model.to_global(Vector3(-.05,.064,-.10));t.set_input("grip",1.0);gun._poll_vr();hand.global_position+=gun.global_basis.z*.04;gun._poll_vr()
		check(gun.reload_state=="needs_rack" and absf(gun.bolt.position.z+.06)<.001,side+" independent bolt follows partial backward pull")
		hand.global_position+=gun.global_basis.z*.04;gun._poll_vr();check(gun.reload_state=="ready" and gun.ammo==28,side+" actual backward bolt stroke finishes reload")
		t.set_input("grip",0.0);gun._poll_vr();gun._process(0)
	var out:=OS.get_environment("UMP074_SNAPSHOT")
	if not out.is_empty():
		var meshes:Array=[];dump_mesh(gun.model,Transform3D.IDENTITY,meshes);var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(meshes))
	for t in trackers.values():XRServer.remove_tracker(t)
	gun.shutdown();gun.queue_free();actor.queue_free();await create_timer(.2).timeout
	print("UMP_ASSET_074 checks=",checks," failures=",failures," xr_off=true headset_verified=false");quit(failures)
