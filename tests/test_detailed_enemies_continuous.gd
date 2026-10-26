extends SceneTree
## Same contracts before/after visual substitution; headless is not GPU evidence.
var failures:=0
var checks:=0
var report_path:=""
var hit_total:=0.0
var variants:Array=[]
var corpse_refs:Array=[]
func check(ok:bool,label:String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func _initialize():call_deferred("run")
func scan_meshes(node:Node,stats:Dictionary):
	if node is MeshInstance3D and node.mesh!=null:
		stats.mesh_nodes+=1
		stats.visible_mesh_nodes+=int(node.is_visible_in_tree())
		if node.mesh is ArrayMesh:
			for property in node.mesh.get_property_list():
				if property.name!="_surfaces":continue
				var stored=node.mesh.get("_surfaces")
				if stored is Array:
					for surface_data in stored:
						if surface_data is Dictionary and surface_data.has("lods"):
							var lods=surface_data.lods
							stats.lod_entries+=lods.size()
							stats.lod_storage_observed=true
		for surface in range(node.mesh.get_surface_count()):
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var indices=arrays[Mesh.ARRAY_INDEX]
			var vertices=arrays[Mesh.ARRAY_VERTEX]
			var triangles:int=(indices.size() if indices!=null and indices.size()>0 else vertices.size())/3
			stats.triangles_all+=triangles
			if node.is_visible_in_tree():stats.triangles_visible+=triangles
			stats.surfaces+=1
			var material=node.get_active_material(surface)
			if material!=null:stats.material_ids[material.get_instance_id()]=true
	for child in node.get_children():scan_meshes(child,stats)
func mesh_stats(node:Node)->Dictionary:
	var stats={"mesh_nodes":0,"visible_mesh_nodes":0,"triangles_all":0,"triangles_visible":0,"surfaces":0,"material_ids":{},"lod_entries":0,"lod_storage_observed":false}
	scan_meshes(node,stats)
	stats.unique_materials=stats.material_ids.size();stats.erase("material_ids")
	return stats
func stop_audio(node:Node):
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop();node.stream=null
	for child in node.get_children():stop_audio(child)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	var world:=Node3D.new();root.add_child(world)
	var floor_body:=StaticBody3D.new();world.add_child(floor_body)
	var floor_shape:=CollisionShape3D.new();var floor_box:=BoxShape3D.new();floor_box.size=Vector3(100,.2,100);floor_shape.shape=floor_box;floor_body.add_child(floor_shape);floor_body.position.y=-.1
	var target:=Node3D.new();world.add_child(target)
	var enemy_script=load("res://scripts/enemy.gd")
	var doll_script=load("res://scripts/ragdoll.gd")
	for variant in range(4):
		var enemy=enemy_script.new();enemy.setup(target,variant);world.add_child(enemy)
		enemy.set_physics_process(false);enemy.set_process(false)
		enemy.position=Vector3(variant*10,0,0);target.position=enemy.position+Vector3(0,0,-8)
		var colliders:Array=[]
		for child in enemy.get_children():
			if child is CollisionShape3D:colliders.append(child)
		check(colliders.size()==1 and colliders[0].shape is CapsuleShape3D,"variant%d retains single capsule hitbox"%variant)
		var shape:CapsuleShape3D=colliders[0].shape
		check(is_equal_approx(shape.radius,[.42,.42,.55,.85][variant]) and is_equal_approx(shape.height,2.2 if variant==3 else 1.65),"variant%d capsule dimensions unchanged"%variant)
		check(is_equal_approx(colliders[0].position.y,1.1 if variant==3 else .88) and enemy.collision_layer==4 and enemy.collision_mask==1,"variant%d capsule origin and layer masks unchanged"%variant)
		check(enemy.health==[85.0,60.0,150.0,350.0][variant],"variant%d health contract unchanged"%variant)
		check(is_equal_approx(enemy._reaction_duration(),1.04),"variant%d default reaction timing unchanged"%variant)
		var aim:Vector3=target.position+Vector3.UP*1.4
		enemy.set_guard_heading(aim-enemy.position)
		enemy.hit_player.connect(func(amount):hit_total+=amount)
		await physics_frame
		var query:=PhysicsRayQueryParameters3D.create(enemy.position+Vector3(0,1,-3),enemy.position+Vector3(0,1,3),4)
		var hit:Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(hit.get("collider")==enemy,"variant%d actual weapon layer ray hits original body"%variant)
		enemy._warden_area=false;enemy.locked_aim=aim;hit_total=0
		enemy._fire(aim)
		check(is_equal_approx(hit_total,[12.0,12.0,19.0,16.0][variant]),"variant%d committed accurate shot damage unchanged"%variant)
		hit_total=0;enemy._fire(aim+Vector3.RIGHT)
		check(hit_total==0,"variant%d lateral dodge evades committed shot"%variant)
		var wall:=StaticBody3D.new();world.add_child(wall);wall.position=enemy.position+Vector3(0,1.4,-4)
		var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3,3,.3);collision.shape=box;wall.add_child(collision)
		await physics_frame
		enemy.locked_aim=aim;hit_total=0;enemy._fire(aim)
		check(hit_total==0,"variant%d solid cover intercepts attack"%variant)
		enemy.state=enemy.State.WINDUP
		var muzzle:Vector3=enemy.position+Vector3.UP*1.4
		enemy._draw_beam(muzzle,aim)
		var beam_start:Vector3=enemy._beam.global_transform*Vector3(0,-.5,0)
		var beam_end:Vector3=enemy._beam.global_transform*Vector3(0,.5,0)
		check(enemy._beam.visible and minf(beam_start.distance_to(muzzle),beam_end.distance_to(muzzle))<.05,"variant%d telegraph begins at unchanged muzzle origin"%variant)
		check(enemy._beam.global_position.distance_to(muzzle)<4,"variant%d telegraph clips to cover"%variant)
		wall.free()
		var geometry:=mesh_stats(enemy._visual)
		geometry.variant=variant;geometry.capsule_radius=shape.radius;geometry.capsule_height=shape.height
		geometry.lod_runtime_api=enemy.has_method("set_visual_lod")
		variants.append(geometry)
		print("GEOMETRY ",JSON.stringify(geometry))
		doll_script.clear_all(world)
		var detail=enemy.get("_detail_visual")
		var originals:Array=[]
		if detail!=null:
			for mesh in detail.source_meshes: originals.append(mesh.mesh)
			check((detail.model.global_basis*Vector3.BACK).normalized().dot((-enemy._turret.global_basis.z).normalized())>.9,"ground model faces same direction as weapon")
		enemy._die()
		var corpse=get_nodes_in_group("ragdolls")[0]
		corpse_refs.append(weakref(corpse))
		if detail!=null:
			var skin=corpse.get_node_or_null("ContinuousCorpseSkin")
			check(skin!=null,"ground enemy death retains continuous skinned model")
			if skin!=null:
				check(skin.skeleton.get_bone_count()==64 and corpse.bodies.size()==8 and corpse.joints.size()==7,"continuous model retains64bones driven by8bodies7joints")
				var visible_meshes:=0
				var visible_surfaces:=0
				for mesh in skin.find_children("*","MeshInstance3D",true,false):
					if not mesh.is_visible_in_tree():continue
					visible_meshes+=1;visible_surfaces+=mesh.mesh.get_surface_count()
					check(mesh.mesh in originals and mesh.skin!=null,"corpse keeps original mesh and skin resources")
				check(visible_meshes==3 and visible_surfaces==3,"three continuous imported mesh surfaces remain intact")
				var max_error:=0.0
				for frame in range(60):
					await physics_frame
					skin.update_skin()
					for bone in range(skin.skeleton.get_bone_count()):
						var actual:Transform3D=skin.skeleton.global_transform*skin.skeleton.get_bone_global_pose(bone)
						var expected:Transform3D=corpse.bodies[skin.body_for_bone[bone]].global_transform*skin.body_offsets[bone]
						max_error=maxf(max_error,actual.origin.distance_to(expected.origin))
				check(max_error<.0001,"all64 bone anchors follow real falling bodies over60physicsframes")
				corpse.set_paused(true)
				var before:Transform3D=skin.skeleton.get_bone_global_pose(3)
				var age_before:float=corpse.age
				await physics_frame;await physics_frame
				check(skin.skeleton.get_bone_global_pose(3).is_equal_approx(before) and corpse.age==age_before,"paused continuous corpse freezes pose and lifetime")
				corpse.set_paused(false)
				geometry.skin_setup_usec=skin.last_setup_usec;geometry.skin_update_usec=skin.last_update_usec;geometry.skin_anchor_error_m=max_error
				print("SKIN_CPU variant=",variant," setup_usec=",skin.last_setup_usec," update_usec=",skin.last_update_usec," headless_cpu_only=true")
		check(corpse.bodies.size()==(6 if variant in [1,3] else 8),"variant%d death keeps rigid anatomy body count"%variant)
		check(not enemy._visual.visible and int(mesh_stats(corpse).mesh_nodes)>corpse.bodies.size(),"variant%d actual death transfers visible meshes"%variant)
		for body in corpse.bodies:check(body.collision_layer==0 and body.collision_mask==1,"corpse world-only collision")
	for i in range(20):doll_script.spawn(world,Transform3D.IDENTITY,Vector3.ZERO,i%4)
	var corpses=get_nodes_in_group("ragdolls");var bodies:=0
	for corpse in corpses:bodies+=corpse.bodies.size()
	check(corpses.size()==6 and bodies<=48,"repeated deaths retain six-corpse /48-body ceiling")
	doll_script.clear_all(world)
	stop_audio(world)
	await create_timer(.2).timeout
	world.free();await process_frame
	check(corpse_refs.all(func(ref):return ref.get_ref()==null),"cleanup frees continuous skeleton hosts and rigid anatomy")
	enemy_script._sound_bank.clear()
	enemy_script.AudioBank._cache.clear()
	await process_frame
	var result={"checks":checks,"failures":failures,"variants":variants,"native_performance_verified":false,"headset_tested":false,"scope":"real physics/rays and mesh resource counts; no GPU draw or frame-time claim"}
	if not report_path.is_empty():
		var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("DETAILED_ENEMIES_CONTINUOUS_RESULT ",JSON.stringify(result))
	quit(failures)
