extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	var wall:=StaticBody3D.new();wall.collision_layer=1;wall.position=Vector3(0,2,-10)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6,6,.2);shape.shape=box;wall.add_child(shape);root.add_child(wall)
	await physics_frame;await physics_frame
	var pair=rack.weapons[11];pair.show()
	for i in 2:
		var gun=pair.guns[i];gun.show();gun.model.show();gun.global_transform=Transform3D(Basis.IDENTITY,Vector3(.4 if i==0 else -.4,2,0));gun.model.transform=Transform3D.IDENTITY;gun._update_laser()
		check(gun.get_meta("reference_id")=="uzis" and gun._laser.visible,"per-hand Uzi reference profile and visible loaded beam"+str(i))
		var bounds:AABB=gun._laser_mesh.get_aabb()
		check(absf(bounds.position.z+9.9)<.02 and bounds.size.z<10,"physical beam stops at actual wall"+str(i))
	check(pair.guns[0]._laser_mesh.get_aabb().get_center().x>0 and pair.guns[1]._laser_mesh.get_aabb().get_center().x<0,"independent left/right beam endpoints")
	pair.guns[0].ammo=0;pair.guns[0]._update_laser();pair.guns[1]._update_laser()
	check(not pair.guns[0]._laser.visible and pair.guns[1]._laser.visible,"empty hand does not remove other loaded beam")
	actor.head_obstructed=true;pair.guns[1]._update_laser();check(not pair.guns[1]._laser.visible,"head obstruction suppresses beam")
	actor.head_obstructed=false;pair.hide();pair.guns[1]._update_laser();check(not pair.guns[1]._laser.visible,"holster/hidden pair suppresses beam")
	var metadata=load("res://scripts/reference_response.gd")
	check(metadata.profile(rack.weapons[7]).get("unsupported_yellow",false),"Magnum one-hand yellow / supported red observation configured")
	check(metadata.profile(rack.weapons[8]).shape=="bracket" and metadata.profile(rack.weapons[1]).shape=="bracket","M60 and DT11 use corner geometry")
	wall.free();rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout
	print("REFERENCE_AIM_059 checks=",checks," failures=",failures," actual_world_rays=true native_rendered=false headset_tested=false");quit(failures)
