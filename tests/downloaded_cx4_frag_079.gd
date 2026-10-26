extends SceneTree
class Gun extends "res://scripts/catalog_firearm.gd":
	func _vr_active()->bool:return true
class Sandbox extends Node:
	var player:Node3D
	var paused:=false
	var dead:=false
	var complete:=false
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
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	var trackers:Dictionary={}
	for hand in [actor.left_hand,actor.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="asset079_"+str(hand.get_instance_id());XRServer.add_tracker(tracker);hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);trackers[hand]=tracker
	await process_frame;actor.update_hand_input_rearm(.2)
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var fallback:=Gun.new();root.add_child(fallback);fallback.setup(actor,false);fallback.set_process(false);fallback.set_physics_process(false)
	check(not fallback.has_meta("downloaded_model_077") and not ResourceLoader.has_cached("res://assets/models/download_cx4/model.glb"),"CX4 authored fallback avoids downloaded mesh")
	fallback.shutdown();fallback.free()
	var holder:=Node3D.new();root.add_child(holder)
	var original:Node3D=load("res://scripts/explosive_finish_064.gd").grenade(holder,"frag")
	check(not original.has_meta("downloaded_grenade_079") and not ResourceLoader.has_cached("res://assets/models/download_frag/model.glb"),"normal frag authored fallback avoids downloaded mesh")
	original.free();ProjectSettings.set_setting("ashfall/lightweight_models",false)
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.left_hand_reserved=false
		for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0)
		var gun:=Gun.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		if side=="left":gun.right_hand=actor.left_hand;gun.left_hand=actor.right_hand
		gun._desktop_signals=true
		var body:MeshInstance3D=gun.model.get_node("DownloadedBody077")
		check(gun.get_meta("downloaded_model_077","")=="cx4",side+" actual MX4 visual selected on CX4 archetype")
		check(triangles(body.mesh)+triangles(gun.magazine.mesh)==6060 and triangles(gun.magazine.mesh)==299,side+" entire source retained with magazine/floorplate separated")
		check(gun.magazine.mesh==gun.loose_magazine.mesh and gun.hip_source.get_child(0).mesh==gun.magazine.mesh,side+" seated held offered magazine geometry agrees")
		check(absf(gun.get_magazine_insert_point().z-gun.magazine.position.z)<.00001,side+" reload route follows actual grip-fed magazine")
		check(gun.get_shot_transform().origin.distance_to(gun.model.to_global(Vector3(0,.045,-.62)))<.00001,side+" CX4 ballistic muzzle and direction retained")
		var rings:Node3D=gun.get_meta("ring_sight");check(rings.visible,side+" accepted three-depth sights visible")
		var rear:Vector3=gun.model.to_local(gun.sight_rear.global_position);var front:Vector3=gun.model.to_local(gun.sight_front.global_position);var clear:=true;var faces:=body.mesh.get_faces()
		for i in range(0,faces.size(),3):
			if Geometry3D.segment_intersects_triangle(rear,front,faces[i],faces[i+1],faces[i+2])!=null:clear=false;break
		check(clear,side+" actual sight corridor clears imported body")
		gun.eject_magazine();var hand:XRController3D=gun.left_hand;var tracker:XRControllerTracker=trackers[hand]
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(gun.get_magazine_offer_point());tracker.set_input("grip",1.0);gun._poll_vr();check(gun.reload_state=="held_mag",side+" actual tracker acquires magazine")
		hand.global_position=gun.reload_world_point(gun.get_magazine_insert_point());gun._poll_vr();check(gun.reload_state=="needs_rack",side+" upward insertion into new mag well works")
		tracker.set_input("grip",0.0);gun._poll_vr();hand.global_position=gun.reload_world_point(Vector3(-.05,.064,-.10));tracker.set_input("grip",1.0);gun._poll_vr();hand.global_position+=gun.global_basis*Vector3.BACK*.1;gun._poll_vr()
		check(gun.reload_state=="ready" and gun.ammo>0,side+" authored charging handle still chambers weapon")
		gun.shutdown();gun.free()
	var held:Node3D=load("res://scripts/explosive_finish_064.gd").grenade(holder,"zone")
	var mesh:Mesh=held.get_node("DownloadedGrenade079").mesh
	check(held.get_meta("downloaded_grenade_079",false) and triangles(mesh)==2434 and mesh.get_surface_count()==6,"zone uses sci-fi source triangles and six source finishes")
	check(absf(mesh.get_aabb().size.y-.14)<.00001 and held.scale.is_equal_approx(Vector3.ONE*2.0),"grenade visible fit is14cm with no double scaling")
	var duplicate:=held.duplicate();holder.add_child(duplicate);check(duplicate.get_node("DownloadedGrenade079").mesh==mesh,"inert pickup clone retains same downloaded resource")
	var game:=Sandbox.new();game.player=actor;root.add_child(game)
	var projectile=load("res://scripts/explosive_projectile.gd").new();root.add_child(projectile);projectile.setup(game,{"kind":"zone","origin":Vector3(3,2,1),"velocity":Vector3(1,2,3)});projectile.set_physics_process(false)
	var flight:Node3D=projectile.get_node("DownloadedGrenadeArt079")
	check(flight.get_node("DownloadedGrenade079").mesh==mesh,"held and real rigid-body flight use same cached imported mesh")
	check(flight.scale.is_equal_approx(Vector3.ONE*(.035/.047)*2.0),"existing held-to-projectile display ratio retained")
	var collision:CollisionShape3D
	for child in projectile.get_children():
		if child is CollisionShape3D:collision=child
	check(collision!=null and is_equal_approx(collision.shape.radius,.035) and projectile.continuous_cd,"real projectile collider and continuous collision retained")
	check(projectile.linear_velocity==Vector3(1,2,3) and is_equal_approx(projectile.gravity_scale,1.0) and is_equal_approx(projectile.mass,.35),"new art does not change flight physics: "+str([projectile.linear_velocity,projectile.gravity_scale,projectile.mass]))
	var zone:Node3D=load("res://scripts/explosive_finish_064.gd").grenade(holder,"frag");check(zone.get_meta("downloaded_model_variant_082","")=="frag_alt","normal frag has distinct red source visual")
	projectile.warning_sound.stop();projectile.free();game.free();holder.free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("DOWNLOADED_CX4_FRAG_079 checks=",checks," failures=",failures," synthetic_tracking=true xr_off=true headset_verified=false");quit(failures)
