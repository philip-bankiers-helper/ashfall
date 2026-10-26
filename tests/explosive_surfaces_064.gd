extends SceneTree
var checks:=0
var failures:=0
var records:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func audit(node:Node3D)->Dictionary:
	var surfaces:Array=[];var unused_total:=0;var unindexed:=0
	for part in node.find_children("*","MeshInstance3D",true,false):
		for i in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(i);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids=arrays[Mesh.ARRAY_INDEX];var used:Dictionary={}
			if ids==null or ids.is_empty():unindexed+=1
			else:
				for index in ids:used[index]=true
			var unused:=vertices.size()-used.size() if ids!=null and not ids.is_empty() else 0
			unused_total+=unused
			surfaces.append({"color":part.material_override.albedo_color.to_html(),"vertices":vertices.size(),"indices":ids.size() if ids!=null else 0,"unreferenced_vertices":unused})
	return {"surfaces":surfaces,"unreferenced_vertices":unused_total,"unindexed_surfaces":unindexed}
func nearest(node:Node3D,origin:Vector3,direction:Vector3,color:String="",limit:float=10.0)->Dictionary:
	var result:Dictionary={};var best:=limit;var frame:=node.global_transform.affine_inverse()
	for part in node.find_children("*","MeshInstance3D",true,false):
		if color!="" and part.material_override.albedo_color.to_html(false)!=color:continue
		var transform:Transform3D=frame*part.global_transform
		for surface in part.mesh.get_surface_count():
			var arrays:Array=part.mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids=arrays[Mesh.ARRAY_INDEX]
			# For the regression run, unindexed surfaces are rendered sequentially.
			# Indexed surfaces deliberately use ONLY their referenced triangles.
			if ids==null or ids.is_empty():
				ids=PackedInt32Array()
				for j in vertices.size():ids.append(j)
			for j in range(0,ids.size(),3):
				var a:Vector3=transform*vertices[ids[j]];var b:Vector3=transform*vertices[ids[j+1]];var c:Vector3=transform*vertices[ids[j+2]]
				var clockwise_normal:Vector3=-(b-a).cross(c-a)
				if clockwise_normal.length_squared()<1e-15 or clockwise_normal.dot(direction)>=-.000000001:continue
				var point=Geometry3D.ray_intersects_triangle(origin,direction,a,b,c)
				if point==null:continue
				var distance:float=(point-origin).length()
				if distance<best:best=distance;result={"point":point,"distance":distance,"color":part.material_override.albedo_color.to_html(false)}
	return result
func probe(node:Node3D,label:String,origin:Vector3,direction:Vector3,color:String="")->Dictionary:
	var hit:=nearest(node,origin,direction,color)
	records.append({"probe":label,"hit":not hit.is_empty(),"point":str(hit.get("point",null)),"distance":hit.get("distance",null),"color":hit.get("color",null)})
	return hit
func run()->void:
	var finish=load("res://scripts/explosive_finish_064.gd");var holder:=Node3D.new();root.add_child(holder)
	for kind in ["frag","zone"]:
		var item:Node3D=finish.grenade(holder,kind);var state:=audit(item)
		check(state.unreferenced_vertices==0 and state.unindexed_surfaces==0,kind+" all final vertices are indexed and referenced: "+str(state))
		records.append({"kind":kind,"index_audit":state})
		if kind=="zone":
			for radial in [Vector3.RIGHT,Vector3(.5,0,-.8660254),Vector3(-.5,0,-.8660254)]:
				var hit:=probe(item,"zone plain dark shell "+str(radial),radial*.15+Vector3.UP*.008,-radial,"263034")
				check(not hit.is_empty() and absf(Vector2(hit.point.x,hit.point.z).length()-.039)<.0005,"zone solid shell has a positive CLOCKWISE indexed face away from panel/slat geometry")
			var bottom:=probe(item,"zone closed bottom",Vector3(.003,-.2,0),Vector3.UP,"263034")
			check(not bottom.is_empty() and absf(bottom.point.y+.0525)<.0005,"zone dark body has a real indexed bottom closure")
			var cap:=probe(item,"zone closed emitter cap",Vector3(0,.2,0),Vector3.DOWN,"9875d2")
			check(not cap.is_empty() and absf(cap.point.y-.064)<.0005,"zone top emitter cap is closed by referenced front-facing triangles")
		else:
			var body:=probe(item,"frag solid body",Vector3(.15,.008,.018),Vector3.LEFT,"66784b")
			check(not body.is_empty() and body.point.x>.037,"frag solid body is rendered by its actual indexed shell")
			var bottom:=probe(item,"frag lower closure",Vector3(.003,-.2,0),Vector3.UP,"66784b")
			check(not bottom.is_empty() and bottom.point.y<-.050,"frag lower shell is closed with positive referenced faces")
			var cap:=probe(item,"frag neck cap closure",Vector3(-.012,.2,0),Vector3.DOWN,"b09256")
			check(not cap.is_empty() and absf(cap.point.y-.061)<.0005,"frag neck cap is closed independently of decorative lever")
		item.free()
	var rocket:Node3D=finish.rocket(holder);var rocket_state:=audit(rocket)
	check(rocket_state.unreferenced_vertices==0 and rocket_state.unindexed_surfaces==0,"rocket final geometry has no unreferenced or unindexed vertices");records.append({"kind":"rocket","index_audit":rocket_state})
	var body:=probe(rocket,"rocket body",Vector3(.15,0,-.05),Vector3.LEFT,"708458")
	check(not body.is_empty() and absf(body.point.x-.032)<.0005,"rocket cylindrical body has positive referenced side faces")
	var nose:=probe(rocket,"rocket closed nose",Vector3(.003,0,.3),Vector3.FORWARD,"bf9b58")
	check(not nose.is_empty() and nose.point.z>.195 and nose.point.z<.21,"rocket nose cone closes with clockwise indexed triangles")
	var nozzle:=probe(rocket,"rocket recessed nozzle backplate",Vector3(.003,0,-.25),Vector3.BACK,"29363b")
	check(not nozzle.is_empty() and nozzle.point.z<-.123,"rocket nozzle is an authored closed dark recess, not a missing triangle hole")
	rocket.free()
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var launcher=load("res://scripts/explosive_weapon.gd").new();launcher.profile_id="smaw";root.add_child(launcher);launcher.setup(actor,false);launcher.set_process(false);launcher.set_physics_process(false)
	var detail:Node3D=launcher.payload.find_child("OriginalLauncherDetail064",true,false);var detail_state:=audit(detail)
	check(detail_state.unreferenced_vertices==0 and detail_state.unindexed_surfaces==0,"launcher added detail has no unused or unindexed vertices")
	records.append({"kind":"launcher_detail","index_audit":detail_state})
	var tube:=probe(launcher.payload,"launcher tube shell",Vector3(.2,.045,-.3),Vector3.LEFT,"708458")
	check(not tube.is_empty() and absf(tube.point.x-.055)<.0005,"launcher existing tube shell remains solid")
	var mouth:=probe(launcher.payload,"launcher original dark mouth recess",Vector3(0,.045,-.9),Vector3.BACK,"101010")
	check(not mouth.is_empty() and absf(mouth.point.z+.834)<.0005,"launcher mouth retains the original closed dark recessed face; it is not an open through-bore")
	var entrance:=nearest(detail,Vector3(0,.045,-.9),Vector3.BACK,"",.10)
	check(entrance.is_empty(),"new launcher detail leaves the original mouth entrance clear")
	records.append({"probe":"added launcher detail entrance clearance","expected_hit":false,"hit":not entrance.is_empty(),"maximum_distance":.10})
	launcher.shutdown();launcher.free();actor.free();holder.free();await create_timer(.1).timeout
	var file:=FileAccess.open("user://explosive-surfaces-064.json",FileAccess.WRITE);file.store_string(JSON.stringify(records,"\t"));file.close();print("SURFACE_RECORDS=",JSON.stringify(records))
	print("EXPLOSIVE_SURFACES_064 checks=",checks," failures=",failures," referenced_index_triangles_only=true clockwise_front_faces=true native_rendered=false")
	quit(failures)
