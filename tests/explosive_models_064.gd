extends SceneTree
class Host extends Node:
	var player
	var paused:=false
	var dead:=false
	var complete:=false
	func apply_explosive_damage(_point:Vector3,_radius:float,_amount:float,_instant:bool)->void:pass
var checks:=0
var failures:=0
var records:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func art(node:Node,label:String)->Node3D:return node.find_child(label,true,false)
func signature(node:Node3D)->String:
	var data:Array=[]
	for part in node.find_children("*","MeshInstance3D",true,false):
		var finish:StandardMaterial3D=part.material_override
		for i in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(i)
			data.append([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_INDEX],finish.albedo_color,finish.metallic,finish.roughness,finish.emission_enabled,finish.emission_energy_multiplier])
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(data));return hash.finish().hex_encode()
func budget(node:Node3D)->Dictionary:
	var surfaces:=0;var triangles:=0;var faces:=0;var clockwise:=0
	for part in node.find_children("*","MeshInstance3D",true,false):
		for i in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(i);var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var n:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var ids=arrays[Mesh.ARRAY_INDEX]
			if ids==null or ids.is_empty():
				ids=PackedInt32Array()
				for j in v.size():ids.append(j)
			surfaces+=1;triangles+=ids.size()/3
			for j in range(0,ids.size(),3):
				var cross:Vector3=(v[ids[j+1]]-v[ids[j]]).cross(v[ids[j+2]]-v[ids[j]])
				if cross.length_squared()<.00000000000001:continue
				faces+=1
				if cross.dot(n[ids[j]])<0:clockwise+=1
	return {"surfaces":surfaces,"triangles":triangles,"clockwise_fraction":float(clockwise)/maxi(1,faces)}
func export_visual(node:Node3D,path:String)->void:
	var triangles:Array=[];var frame:=node.global_transform.affine_inverse()
	for part in node.find_children("*","MeshInstance3D",true,false):
		if not part.is_visible_in_tree() or part.mesh==null:continue
		var relative:Transform3D=frame*part.global_transform;var finish:StandardMaterial3D=part.material_override
		for i in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(i);var v=arrays[Mesh.ARRAY_VERTEX];var ids=arrays[Mesh.ARRAY_INDEX]
			if ids==null or ids.is_empty():
				ids=PackedInt32Array()
				for j in v.size():ids.append(j)
			for j in range(0,ids.size(),3):
				var face:Array=[]
				for k in 3:
					var point:Vector3=relative*v[ids[j+k]];face.append([point.x,point.y,point.z])
				triangles.append({"v":face,"color":[finish.albedo_color.r,finish.albedo_color.g,finish.albedo_color.b]})
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(triangles));file.close()
func run()->void:
	# Retained authored explosive geometry; downloaded shared held/flight art tested separately.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var host:=Host.new();host.player=actor;root.add_child(host)
	for kind in ["frag","zone","smaw"]:
		var weapon=load("res://scripts/explosive_weapon.gd").new();weapon.profile_id=kind;root.add_child(weapon);weapon.setup(actor,false);weapon.set_process(false);weapon.set_physics_process(false);weapon._process(0)
		var shot:Vector3=weapon.model.to_local(weapon.get_shot_transform().origin)
		check(shot.distance_to(Vector3(0,.045,-.85 if kind=="smaw" else -.10))<.00001,kind+" shot origin and muzzle/launch transform unchanged")
		var projectile=load("res://scripts/explosive_projectile.gd").new();host.add_child(projectile);projectile.setup(host,{"kind":kind,"origin":Vector3(10,4,3),"velocity":Vector3(5,2,-7)});projectile.set_physics_process(false)
		var colliders:Array=projectile.find_children("*","CollisionShape3D",true,false)
		check(colliders.size()==1 and colliders[0].shape is SphereShape3D and is_equal_approx(colliders[0].shape.radius,.035) and colliders[0].position==Vector3.ZERO,kind+" original collision shape/radius/local position preserved")
		check(is_equal_approx(projectile.mass,.35) and projectile.collision_layer==16 and projectile.collision_mask==15 and projectile.continuous_cd and projectile.linear_damp==0 and projectile.linear_velocity==Vector3(5,2,-7),kind+" original mass/masks/CCD/velocity/undamped flight preserved")
		check(projectile.gravity_scale==(0 if kind=="smaw" else 1),kind+" original gravity scale preserved")
		var held:Node3D;var flying:Node3D
		if kind=="smaw":
			held=art(weapon.rocket_offer,"OriginalRocketArt064");flying=art(projectile,"OriginalRocketArt064")
			check(weapon.rocket_offer.get_parent()==weapon and weapon.rocket_held.get_parent()==weapon and art(weapon.rocket_held,"OriginalRocketArt064")!=null,"offered and carried rocket art belong to original reload item roots")
			check(signature(held)==signature(art(weapon.rocket_held,"OriginalRocketArt064")),"offered and carried rocket have identical original mesh/material identity")
			var direction:Vector3=projectile.global_basis*flying.basis*Vector3.BACK
			check(direction.normalized().dot(projectile.linear_velocity.normalized())>.99999,"flying rocket nose follows original negative-Z flight axis")
			check(weapon.ROCKET_MOUTH==Vector3(0,.045,-.83) and weapon.ROCKET_OFFER==Vector3(0,.045,-1.15) and weapon.ROCKET_INSERT==Vector3(0,.045,-.96) and weapon.hand_grip_center==Vector3(0,-.075,-.3195),"launcher exact mouth/offer/insertion unchanged;076 grip at tube center")
			check(art(weapon.payload,"OriginalLauncherDetail064")!=null and projectile.flight_sound!=null and projectile.warning_sound==null,"launcher detail stays with payload; existing rocket flight sound remains separate")
			export_visual(weapon.payload,"user://launcher-064-mesh.json");export_visual(held,"user://rocket-064-mesh.json")
			weapon.ammo=0;weapon._process(0);check(weapon.payload.is_visible_in_tree(),"empty launcher retains its original persistent tube/payload visibility")
		else:
			held=art(weapon.payload,"OriginalGrenadeArt064");flying=art(projectile,"OriginalGrenadeArt064")
			check(held.get_parent()==weapon.payload and flying.get_parent()==projectile,kind+" held and flying item art have actual lifecycle parents")
			check(held.position==Vector3(0,-.015,-.03) and held.scale==Vector3.ONE and flying.position==Vector3.ZERO and flying.scale.distance_to(Vector3.ONE*(.035/.047))<.000001,kind+" original held center and authored uniform flying-size distinction retained")
			weapon.ammo=0;weapon._process(0);check(not held.is_visible_in_tree(),kind+" depletion hides all nested held art through original payload visibility")
			weapon.ammo=1;weapon.reload_state="ready";weapon._process(0);check(held.is_visible_in_tree(),kind+" funded payload restores complete held art")
			check(projectile.warning_sound!=null and projectile.tuning.frag_fuse_seconds==3.5 and projectile.tuning.zone_activation_delay==2.7 and projectile.tuning.zone_lifetime==10,kind+" warning sound, authored fuse and zone timings unchanged")
			export_visual(held,"user://"+kind+"-064-mesh.json")
		check(signature(held)==signature(flying),kind+" held and flying geometry/material fingerprints are identical before authored transform/scale")
		var held_meshes:Array=held.find_children("*","MeshInstance3D",true,false);var flight_meshes:Array=flying.find_children("*","MeshInstance3D",true,false)
		check(held_meshes.size()==flight_meshes.size() and held_meshes[0].mesh==flight_meshes[0].mesh and held_meshes[0].material_override==flight_meshes[0].material_override,kind+" flight reuses cached canonical mesh/material resources instead of rebuilding on throw")
		var amount:=budget(held);check(amount.surfaces<=4 and amount.triangles<4500,kind+" batched visual budget bounded: "+str(amount))
		check(amount.clockwise_fraction>.98,kind+" mesh winding agrees with outward normals and Godot clockwise front faces")
		check(held.find_children("*","CollisionObject3D",true,false).is_empty() and flying.find_children("*","CollisionObject3D",true,false).is_empty(),kind+" visual helper adds no physical body or collider")
		records.append({"kind":kind,"canonical_mesh_sha256":signature(held),"budget":amount})
		if kind=="zone":
			projectile._on_contact(null);projectile._physics_process(2.7)
			check(flying.is_visible_in_tree() and projectile.zone_visual.visible,"zone item art remains during activation and existing field visibility")
			projectile._physics_process(10.0)
			check(projectile.finished and projectile.is_queued_for_deletion() and flying.get_parent()==projectile,"zone item art shares original field/projectile lifetime")
		elif kind=="frag":
			projectile._physics_process(3.49);check(not projectile.finished and flying.is_visible_in_tree(),"frag art persists through original pre-fuse lifetime")
			projectile._physics_process(.02);check(projectile.finished and projectile.is_queued_for_deletion(),"frag art retires with original fuse detonation")
		else:
			projectile._on_contact(null);check(projectile.finished and projectile.is_queued_for_deletion() and flying.get_parent()==projectile,"rocket art retires with original contact detonation")
		projectile.free();weapon.shutdown();weapon.free()
	var file:=FileAccess.open("user://explosive-models-064.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close();print("MODEL_RECORDS=",JSON.stringify(records))
	host.free();actor.free();await create_timer(.1).timeout
	print("EXPLOSIVE_MODELS_064 checks=",checks," failures=",failures," production_node_geometry=true native_rendered=false headset_tested=false")
	quit(failures)
