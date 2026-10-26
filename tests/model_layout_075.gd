extends SceneTree
var checks:=0
var failures:=0
var excluded_nodes:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func vertices(node:Node,at:Transform3D=Transform3D.IDENTITY)->Array[Vector3]:
	var result:Array[Vector3]=[]
	if node in excluded_nodes:return result
	if node is Node3D:
		if not node.visible:return result
		at=at*node.transform
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			for v in node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:result.append(at*v)
	for child in node.get_children():result.append_array(vertices(child,at))
	return result
func run()->void:
	# 077 retained authored asset coverage; downloaded versions have separate tracker/geometry tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false);game.field_menu.set_open(false)
	var px4=game.weapon.weapons[2];px4.show();px4.model.show();px4.set_process(false)
	var grip:Node3D=px4.model.get_node("PX4Grip075");var trigger:Node3D=px4.model.get_node("PX4ForwardTrigger075")
	var guard_max:float=-INF
	for point in vertices(trigger):guard_max=maxf(guard_max,point.z)
	check(guard_max<grip.position.z-.025,"actual PX4 trigger and guard lie muzzle-forward of grip")
	check((grip.transform*Vector3(0,-.05,0)).z>(grip.transform*Vector3(0,.05,0)).z,"actual PX4 lower grip slopes rearward")
	check(px4.get_magazine_insert_point().is_equal_approx(Vector3(0,-.18,-.11)) and px4.get_shot_transform().origin.distance_to(px4.model.to_global(Vector3(0,.045,-.29)))<.00001,"PX4 magazine follows requested rearward shift; shot datum preserved")
	for index in [20]: # Imported1911 and its lightweight version covered in model_adjustments_076.
		var gun=game.weapon.weapons[index];gun.show();gun.model.show();gun.set_process(false)
		var core:Node3D=gun.model.get_node("CatalogGripCore")
		check(absf(core.position.z-(gun.magazine.position.z-.020))<.00001,gun.profile_id+" lower grip moved another2cm forward of magazine")
		var max_rear:float=-INF
		excluded_nodes=[gun.magazine]
		for point in vertices(gun.model):
			if point.y<-.04 and absf(point.x)>.01:max_rear=maxf(max_rear,point.z)
		check(max_rear<.020,gun.profile_id+" no old rearward protruding lower grip section")
		check(absf(gun.get_magazine_insert_point().z-gun.magazine_home.z)<.00001,gun.profile_id+" reload target remains at unchanged magazine")
	excluded_nodes=[]
	ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var ump=load("res://scripts/compact_smg.gd").new();root.add_child(ump);ump.setup(game.player,false);ump.show();ump.model.show();ump.set_process(false);ump._process(0)
	check(ump.model.scale.is_equal_approx(Vector3.ONE*.76),"UMP exactly35percent smaller than original in every axis")
	check(ump.get_shot_transform().basis.get_scale().is_equal_approx(Vector3.ONE),"resized UMP preserves unit ballistic direction basis")
	check(ump.get_shot_transform().origin.distance_to(ump.model.to_global(Vector3(0,.045,-.46)))<.00001,"UMP shot starts at scaled visible muzzle")
	check(ump.guide.global_position.distance_to(ump.to_global(ump.get_magazine_insert_point()))<.00001,"UMP insertion cue and input target have no double scaling")
	check(ump.loose_magazine.mesh.get_aabb().size.distance_to(ump.magazine.mesh.get_aabb().size*.76)<.00001,"loose magazine scaled once independently of tracked hand transform")
	var glove:Node3D=ump.left_hand.get_node_or_null("ArticulatedGlove")
	if glove==null:glove=Node3D.new();glove.name="ArticulatedGlove";ump.left_hand.add_child(glove)
	var glove_scale:Vector3=glove.global_basis.get_scale();ump.supported=true;ump._update_support_visual()
	check(glove.global_basis.get_scale().distance_to(glove_scale)<.00001,"resizing UMP does not shrink supporting player hand")
	ump._release_support_visual()
	ump.shutdown();ump.free()
	game._quitting=true;game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.2).timeout
	print("MODEL_LAYOUT_075 checks=",checks," failures=",failures," cpu_only=true headset_verified=false");quit(failures)
