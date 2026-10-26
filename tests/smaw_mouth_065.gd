extends SceneTree
var checks:=0
var failures:=0
var records:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func faces(node:Node3D)->Array:
	var result:Array=[];var frame:=node.global_transform.affine_inverse()
	for part in node.find_children("*","MeshInstance3D",true,false):
		var transform:Transform3D=frame*part.global_transform
		for surface in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids=arrays[Mesh.ARRAY_INDEX]
			if ids==null or ids.is_empty():
				ids=PackedInt32Array()
				for index in vertices.size():ids.append(index)
			for j in range(0,ids.size(),3):
				var triangle:Array[Vector3]=[]
				for k in 3:triangle.append(transform*vertices[ids[j+k]])
				result.append({"v":triangle,"color":part.material_override.albedo_color,"part":str(part.name)})
	return result
func nearest(triangles:Array,origin:Vector3,direction:Vector3,limit:float=10.0)->Dictionary:
	var result:Dictionary={};var best:=limit
	for face in triangles:
		var a:Vector3=face.v[0];var b:Vector3=face.v[1];var c:Vector3=face.v[2];var clockwise_normal:Vector3=-(b-a).cross(c-a)
		if clockwise_normal.length_squared()<1e-16 or clockwise_normal.dot(direction)>=-1e-10:continue
		var point=Geometry3D.ray_intersects_triangle(origin,direction,a,b,c)
		if point==null:continue
		var distance:float=(point-origin).length()
		if distance<best:best=distance;result={"point":point,"distance":distance,"part":face.part}
	return result
func point_key(point:Vector3)->String:return str(Vector3i(roundi(point.x*1000000),roundi(point.y*1000000),roundi(point.z*1000000)))
func geometry_audit(node:Node3D)->Dictionary:
	var unused:=0;var unindexed:=0;var invalid:=0;var triangles:=0;var clockwise:=0;var nondegenerate:=0
	for part in node.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var ids=arrays[Mesh.ARRAY_INDEX];var referenced:Dictionary={}
			if ids==null or ids.is_empty():unindexed+=1;continue
			for index in ids:
				if index<0 or index>=vertices.size():invalid+=1
				referenced[index]=true
			unused+=vertices.size()-referenced.size();triangles+=ids.size()/3
			for j in range(0,ids.size(),3):
				var cross:Vector3=(vertices[ids[j+1]]-vertices[ids[j]]).cross(vertices[ids[j+2]]-vertices[ids[j]])
				if cross.length_squared()<1e-16:continue
				nondegenerate+=1
				if cross.dot(normals[ids[j]])<0:clockwise+=1
	return {"unreferenced_vertices":unused,"unindexed_surfaces":unindexed,"invalid_indices":invalid,"triangles":triangles,"clockwise_fraction":float(clockwise)/maxi(nondegenerate,1)}
func closure(triangles:Array)->Dictionary:
	var edges:Dictionary={}
	for face in triangles:
		for j in 3:
			var a:=point_key(face.v[j]);var b:=point_key(face.v[(j+1)%3])
			if a==b:continue
			var key:=a+"|"+b if a<b else b+"|"+a
			edges[key]=edges.get(key,0)+1
	var boundary:=0;var nonmanifold:=0
	for count in edges.values():
		if count==1:boundary+=1
		elif count!=2:nonmanifold+=1
	return {"boundary_edges":boundary,"nonmanifold_edges":nonmanifold,"position_weld_precision_metres":.000001}
func export_mesh(triangles:Array,path:String)->void:
	var data:Array=[]
	for face in triangles:
		var points:Array=[]
		for p in face.v:points.append([p.x,p.y,p.z])
		data.append({"v":points,"color":[face.color.r,face.color.g,face.color.b],"part":face.part})
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
func bounds(triangles:Array)->AABB:
	var result:=AABB(triangles[0].v[0],Vector3.ZERO)
	for face in triangles:
		for point in face.v:result=result.expand(point)
	return result
func canonical_signature(node:Node3D)->String:
	var data:Array=[]
	for part in node.find_children("*","MeshInstance3D",true,false):
		for surface in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(surface);var material:StandardMaterial3D=part.material_override
			data.append([part.transform,arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_INDEX],material.albedo_color,material.metallic,material.roughness,material.emission_enabled,material.emission_energy_multiplier])
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(var_to_bytes(data));return hash.finish().hex_encode()
func radial_clearance(point:Vector3)->float:
	var radial:=Vector2(point.x,point.y-.045);var answer:=INF
	for side in 16:
		var angle:=TAU*(side+.5)/16.0
		answer=minf(answer,.048*cos(PI/16.0)-radial.dot(Vector2(cos(angle),sin(angle))))
	return answer
func run()->void:
	ProjectSettings.set_setting("ashfall/lightweight_models",true) # authored065 geometry rollback;085tests actual Jinx
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var weapon=load("res://scripts/explosive_weapon.gd").new();weapon.profile_id="smaw";root.add_child(weapon);weapon.setup(actor,false);weapon.set_process(false);weapon.set_physics_process(false);weapon._process(0)
	var old=load("res://tests/fixtures/explosive_weapon_064.gd").new();old.profile_id="smaw";root.add_child(old);old.setup(actor,false);old.set_process(false);old.set_physics_process(false);old._process(0)
	var tube:Node3D=weapon.payload.find_child("OriginalSmawTube065",true,false);var triangles:=faces(tube);var old_faces:=faces(old.payload)
	var audit:=geometry_audit(tube);records["tube_geometry"]=audit
	check(audit.unreferenced_vertices==0 and audit.unindexed_surfaces==0 and audit.invalid_indices==0,"all tube/rim/collar vertices have valid referenced final indices")
	check(audit.clockwise_fraction==1.0,"every nondegenerate tube/rim/collar triangle follows Godot clockwise front faces")
	var core:Array=[];var collars:Array=[]
	for face in triangles:
		if face.part.begins_with("AnnularTubeCollar"):collars.append(face)
		else:core.append(face)
	var core_closure:=closure(core);var collar_closure:=closure(collars);records["core_closure"]=core_closure;records["collar_closure"]=collar_closure
	check(core_closure.boundary_edges==0 and core_closure.nonmanifold_edges==0,"open-bore cup has a closed material boundary, including annular lip and rear plate")
	check(collar_closure.boundary_edges==0 and collar_closure.nonmanifold_edges==0,"both annular external collars have closed indexed boundaries")
	check(tube.get_parent()==weapon.payload and tube.find_children("*","CollisionObject3D",true,false).is_empty() and tube.find_children("*","CollisionShape3D",true,false).is_empty(),"visual tube belongs to original payload and adds no physical body/collider")
	var front:=Vector3(0,.045,-.90);var back:=nearest(triangles,front,Vector3.BACK);var old_front:=nearest(old_faces,front,Vector3.BACK)
	records["axis_ray"]={"old_first_hit":str(old_front.get("point",null)),"new_first_hit":str(back.get("point",null)),"new_part":back.get("part",null)}
	check(not old_front.is_empty() and absf(old_front.point.z+.834)<.00001,"064 fixture reproduces its original shallow closed mouth face")
	check(not back.is_empty() and absf(back.point.z-.19)<.00001 and back.part=="BoreWallAndRear","new centreline stays open to the actual recessed rear plate at z=+.19")
	for radius in [0.0,.032,.0431]:
		var clear:=true
		for side in 16:
			var angle:=TAU*side/16.0;var origin:=front+Vector3(cos(angle)*radius,sin(angle)*radius,0)
			if not nearest(triangles,origin,Vector3.BACK,1.08).is_empty():clear=false
		check(clear,"axial bore rays stay clear through both collar positions at radius="+str(radius))
	var inside:=nearest(triangles,Vector3(0,.045,-.70),Vector3.RIGHT)
	check(not inside.is_empty() and absf(inside.point.x-.048)<.00001 and inside.part=="BoreWallAndRear","actual inward-facing bore wall is present, not a deleted front cap alone")
	var exterior_back:=nearest(triangles,Vector3(0,.045,.30),Vector3.FORWARD)
	check(not exterior_back.is_empty() and absf(exterior_back.point.z-.20)<.00001,"original outside rear face remains at +.20 and closes the authored 10 mm rear plate")
	var outer_equal:=true
	for z in [-.60,-.30,.0]:
		for side in 16:
			var angle:=TAU*(side+.5)/16.0;var radial:=Vector3(cos(angle),sin(angle),0);var origin:=Vector3(0,.045,z)+radial*.20
			var a:=nearest(triangles,origin,-radial);var b:=nearest(old_faces,origin,-radial)
			if a.is_empty() or b.is_empty() or a.point.distance_to(b.point)>.000001:outer_equal=false
	check(outer_equal,"actual outer-tube facets match 064 side rays at 48 adjacent solid tube samples")
	var minimum_wall:=INF;var body_wall:=INF
	for z in [-.83899,-.838,-.836,-.834,-.830,-.825,-.821,-.70,.0,.18]:
		for side in 16:
			var angle:=TAU*(side+.5)/16.0;var radial:=Vector3(cos(angle),sin(angle),0);var center:=Vector3(0,.045,z)
			var inner:=nearest(triangles,center,radial);var outer:=nearest(triangles,center+radial*.2,-radial)
			if not inner.is_empty() and not outer.is_empty():
				var wall:float=outer.point.distance_to(inner.point);minimum_wall=minf(minimum_wall,wall)
				if z==0:body_wall=minf(body_wall,wall)
	records["actual_wall_ray_measurements"]={"minimum_sampled_radial_wall":minimum_wall,"body_facet_normal_wall":body_wall,"sample_count":160,"rear_plate_depth":.01}
	check(minimum_wall>.0048 and minimum_wall<.0051,"actual bevelled rim minimum sampled radial wall exceeds 4.8 mm")
	check(absf(body_wall-.007*cos(PI/16.0))<.000001,"actual main wall is 6.8655 mm normal to its preserved facets")
	var rocket_points:Array[Vector3]=[]
	for face in faces(weapon.rocket_held):
		for point in face.v:rocket_points.append(point)
	var max_radius:=0.0;var rocket_min_z:=INF;var rocket_max_z:=-INF
	for point in rocket_points:max_radius=maxf(max_radius,Vector2(point.x,point.y).length());rocket_min_z=minf(rocket_min_z,point.z);rocket_max_z=maxf(rocket_max_z,point.z)
	var min_margin:=INF;var sampled_inside:=0
	for step in 81:
		var center:Vector3=weapon.ROCKET_OFFER.lerp(weapon.ROCKET_MOUTH+Vector3(0,0,.08),step/80.0)
		for point in rocket_points:
			var placed:Vector3=center+point
			if placed.z>=-.839 and placed.z<=.19:min_margin=minf(min_margin,radial_clearance(placed));sampled_inside+=1
	records["rocket_fit"]={"actual_max_radius_including_fins":max_radius,"actual_axial_bounds":[rocket_min_z,rocket_max_z],"minimum_bore_inradius":.048*cos(PI/16.0),"conservative_radial_clearance":.048*cos(PI/16.0)-max_radius,"minimum_actual_vertex_to_bore_facet_clearance":min_margin,"sampled_inside_vertices":sampled_inside,"aligned_center_samples":81,"path_start":str(weapon.ROCKET_OFFER),"path_end":str(weapon.ROCKET_MOUTH+Vector3(0,0,.08)),"input_radial_acceptance_unchanged":.14}
	check(max_radius>.043 and max_radius<.0431,"clearance uses actual rocket fins, beyond its nominal 32 mm body radius")
	check(min_margin>.004 and sampled_inside>0,"actual carried-rocket vertices fit the bore across the complete aligned accepted +Z stroke")
	check(.048*cos(PI/16.0)-max_radius>.004,"every rocket triangle is conservatively inside the polygonal bore, not just the sampled nose")
	var old_rim_min:=INF
	for part in old.payload.get_children():
		if part is MeshInstance3D and part.mesh is TorusMesh and part.position.distance_to(old.ROCKET_MOUTH)<.00001:
			for point in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p:Vector3=part.transform*point;old_rim_min=minf(old_rim_min,Vector2(p.x,p.y-.045).length())
	records["old_rim_clearance"]={"actual_inner_radius":old_rim_min,"rocket_radial_envelope":max_radius,"nominal_gap":old_rim_min-max_radius}
	check(old_rim_min<max_radius and absf(old_rim_min-.041)<.000001,"actual old 41 mm torus opening was narrower than the 43.026 mm rocket fin envelope")
	check(weapon.rocket_offer.get_parent()==weapon and weapon.rocket_held.get_parent()==weapon,"actual offered/carried roots retain their original weapon ownership")
	check(weapon.ROCKET_MOUTH==old.ROCKET_MOUTH and weapon.ROCKET_OFFER==old.ROCKET_OFFER and weapon.ROCKET_INSERT==old.ROCKET_INSERT and absf(weapon.ROCKET_GRIP.z-(.20-.839)*.5)<.000001 and (weapon.model.global_transform.affine_inverse()*weapon.get_shot_transform()).orthonormalized().is_equal_approx((old.model.global_transform.affine_inverse()*old.get_shot_transform()).orthonormalized()),"mouth/offer/insert/muzzle unchanged; 076 primary grip at tube midpoint")
	var rocket_signature:=canonical_signature(weapon.rocket_held);var old_rocket_signature:=canonical_signature(old.rocket_held)
	records["canonical_rocket_geometry"]={"held_new":rocket_signature,"held_064":old_rocket_signature,"offer_new":canonical_signature(weapon.rocket_offer),"offer_064":canonical_signature(old.rocket_offer)}
	check(rocket_signature==old_rocket_signature and canonical_signature(weapon.rocket_offer)==canonical_signature(old.rocket_offer),"all offered/carried rocket mesh arrays/transforms/materials retain exact canonical 064 geometry")
	weapon.reload_state="needs_mag";weapon._process(0)
	var offered_in_model:Transform3D=weapon.model.global_transform.affine_inverse()*weapon.rocket_offer.global_transform
	check(offered_in_model.origin.distance_to(weapon.ROCKET_OFFER)<.000001 and offered_in_model.basis.is_equal_approx(Basis.IDENTITY),"actual offered root still uses the unchanged aligned offer transform")
	weapon.rocket_held.global_transform=Transform3D(weapon.model.global_basis,weapon.model.to_global(weapon.ROCKET_INSERT))
	var carried_in_model:Transform3D=weapon.model.global_transform.affine_inverse()*weapon.rocket_held.global_transform
	check(carried_in_model.origin.distance_to(weapon.ROCKET_INSERT)<.000001 and carried_in_model.basis.is_equal_approx(Basis.IDENTITY),"actual carried visual can occupy the unchanged insert transform without reparenting or scale changes")
	var nose_at_insert:Vector3=carried_in_model*Vector3(0,0,rocket_min_z)
	check(nose_at_insert.z<weapon.ROCKET_MOUTH.z and absf(nose_at_insert.z+1.17)<.000001,"086actual carried nose faces forward; unchanged insertion accepts the same centre")
	var body_bounds:=AABB(Vector3(0,.045,.20),Vector3.ZERO)
	for face in triangles:
		for point in face.v:body_bounds=body_bounds.expand(point)
	records["tube_bounds"]={"position":str(body_bounds.position),"size":str(body_bounds.size)}
	check(body_bounds.position.distance_to(Vector3(-.067,-.022,-.839))<.000001 and body_bounds.end.distance_to(Vector3(.067,.112,.20))<.000001,"tube/collar/rim envelope preserves outer maxima and rear profile")
	var payload_bounds:=bounds(faces(weapon.payload));var old_payload_bounds:=bounds(old_faces)
	records["payload_bounds"]={"old_position":str(old_payload_bounds.position),"old_size":str(old_payload_bounds.size),"new_position":str(payload_bounds.position),"new_size":str(payload_bounds.size)}
	check(payload_bounds.position.distance_to(old_payload_bounds.position)<.000001 and payload_bounds.size.distance_to(old_payload_bounds.size)<.000001,"actual complete payload dimensions match 064 including grips, sights and fittings")
	export_mesh(faces(weapon.payload),"user://smaw-065-mesh.json");export_mesh(old_faces,"user://smaw-064-baseline-mesh.json");export_mesh(faces(weapon.rocket_held),"user://rocket-064-mesh.json")
	var loaded:=faces(weapon.payload)
	for face in faces(weapon.rocket_held):
		var points:Array[Vector3]=[]
		for point in face.v:points.append(carried_in_model*point)
		loaded.append({"v":points,"color":face.color,"part":"CarriedRocket_AtUnchangedInsert"})
	export_mesh(loaded,"user://smaw-065-insertion-mesh.json")
	var file:=FileAccess.open("user://smaw-mouth-065.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close();print("MOUTH_RECORDS=",JSON.stringify(records))
	weapon.shutdown();weapon.free();old.shutdown();old.free();actor.free();await create_timer(.1).timeout
	print("SMAW_MOUTH_065 checks=",checks," failures=",failures," actual_referenced_triangles=true clockwise_rays=true native_rendered=false")
	ProjectSettings.set_setting("ashfall/lightweight_models",null)
	quit(failures)
