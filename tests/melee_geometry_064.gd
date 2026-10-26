extends SceneTree
const Assets=preload("res://scripts/blade_assets.gd")
# Captured from untouched064 A8351FFC baseline before the visual fix.
# Literal vectors keep the packed CPU test independent of export JSON filters.
const HIT_MARKERS:={
	"katana":[Vector3(0.0,0.125,0.025000000372529),Vector3(0.0,0.956454277038574,-0.053745873272419)],
	"excalibur":[Vector3(0.0,0.125,0.025000000372529),Vector3(0.0,0.958999991416931,0.025000000372529)],
	"cyberblade":[Vector3(0.0,0.125,0.025000000372529),Vector3(0.0,0.958927690982819,0.0117251491174102)],
	"knife":[Vector3(0.0,0.025000000372529,0.025000000372529),Vector3(0.0,0.24600000679493,0.025000000372529)]
}
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func key(v:Vector3)->String:return "%d,%d,%d"%[roundi(v.x*1000000),roundi(v.y*1000000),roundi(v.z*1000000)]
func triangle_data(mesh:Mesh)->Array:
	var triangles:Array=[]
	for surface in mesh.get_surface_count():
		var a:=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
		var indices:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			for i in vertices.size():indices.append(i)
		for i in range(0,indices.size(),3):triangles.append({"v":[vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]]],"n":[normals[indices[i]],normals[indices[i+1]],normals[indices[i+2]]]})
	return triangles
func centre_at(rings:Array,y:float)->Vector3:
	for i in rings.size()-1:
		if y<=rings[i+1].y+.0000001:return rings[i].lerp(rings[i+1],clampf((y-rings[i].y)/(rings[i+1].y-rings[i].y),0,1))
	return rings.back()
func inspect_blade(model:Node3D,kind:String)->Dictionary:
	var triangles:Array=[];var by_y:Dictionary={}
	for part_name in ["AuthoredBlade","ContinuousEdgeBevels"]:
		var part:MeshInstance3D=model.get_node(part_name);var tris:=triangle_data(part.mesh);triangles.append_array(tris)
		for t in tris:
			for v in t.v:
				var y_key:=roundi(v.y*1000000)
				if not by_y.has(y_key):by_y[y_key]=[v.z,v.z,v.y]
				by_y[y_key][0]=minf(by_y[y_key][0],v.z);by_y[y_key][1]=maxf(by_y[y_key][1],v.z)
	var ys:Array=by_y.keys();ys.sort();var rings:Array=[]
	for y in ys:rings.append(Vector3(0,by_y[y][2],(by_y[y][0]+by_y[y][1])*.5))
	var edges:Dictionary={};var direction:Dictionary={};var degenerate:=0;var wrong_front:=0;var inward_normal:=0;var normal_front_mismatch:=0;var volume:=0.0
	for t in triangles:
		var a:Vector3=t.v[0];var b:Vector3=t.v[1];var c:Vector3=t.v[2];var centroid:Vector3=(a+b+c)/3
		var cross:Vector3=(c-a).cross(b-a)
		if cross.length_squared()<1e-18:degenerate+=1;continue
		var normal:=cross.normalized();var outward:Vector3
		if absf(a.y-b.y)<.0000001 and absf(a.y-c.y)<.0000001:outward=Vector3.DOWN if a.y<rings[0].y+.000001 else Vector3.UP
		else:outward=centroid-centre_at(rings,centroid.y);outward.y=0
		if normal.dot(outward)<=0:wrong_front+=1
		for supplied in t.n:
			if supplied.dot(outward)<=0:inward_normal+=1
			if supplied.dot(normal)<.999:normal_front_mismatch+=1
		volume+=a.dot(b.cross(c))/6.0
		for pair in [[a,b],[b,c],[c,a]]:
			var first:=key(pair[0]);var second:=key(pair[1]);var id:=first+"/"+second if first<second else second+"/"+first
			edges[id]=int(edges.get(id,0))+1;direction[first+"/"+second]=int(direction.get(first+"/"+second,0))+1
	var bad_edges:=0;var bad_direction:=0
	for value in edges.values():
		if value!=2:bad_edges+=1
	for id in direction:
		var pair:PackedStringArray=id.split("/")
		if direction[id]!=int(direction.get(pair[1]+"/"+pair[0],0)):bad_direction+=1
	check(degenerate==0,kind+" real blade shell has no degenerate triangles")
	check(bad_edges==0 and bad_direction==0,kind+" real flat/bevel/cap shell is closed with consistent directed edges")
	check(wrong_front==0,kind+" every Godot clockwise face points outward from actual mesh sections")
	check(inward_normal==0,kind+" actual supplied blade normals point outward")
	check(normal_front_mismatch==0,kind+" supplied normals agree with clockwise geometry")
	check(volume<-.000001,kind+" clockwise outward blade has negative conventional signed volume")
	var inward_inlay:=0;var wrong_inlay:=0;var inlay_degenerate:=0
	for child in model.get_children():
		if not child is MeshInstance3D or not ("Inlay" in child.name or child.name.begins_with("EnergyInset")):continue
		for t in triangle_data(child.mesh):
			var a:Vector3=t.v[0];var b:Vector3=t.v[1];var c:Vector3=t.v[2];var middle:Vector3=(a+b+c)/3
			var cross:Vector3=(c-a).cross(b-a)
			if cross.length_squared()<1e-18:inlay_degenerate+=1;continue
			var outward:=1.0 if middle.z>centre_at(rings,middle.y).z else -1.0
			if cross.z*outward<=0:wrong_inlay+=1
			for n in t.n:
				if n.z*outward<=0:inward_inlay+=1
	check(inlay_degenerate==0,kind+" face inlays have no degenerate triangles")
	check(wrong_inlay==0 and inward_inlay==0,kind+" decorative inlays face outward on both blade faces")
	return {"kind":kind,"triangles":triangles.size(),"bad_edges":bad_edges,"bad_direction":bad_direction,"wrong_clockwise_fronts":wrong_front,"inward_supplied_normals":inward_normal,"normal_front_mismatch":normal_front_mismatch,"signed_volume":volume,"wrong_inlay_fronts":wrong_inlay,"inward_inlay_normals":inward_inlay}
func run()->void:
	# 077 retained authored asset coverage; downloaded versions have separate tracker/geometry tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var metrics:Array=[];var poses:Array=[]
	for kind in ["katana","excalibur","cyberblade","knife"]:
		var model:=Node3D.new();root.add_child(model);var built:Dictionary=Assets.build(model,kind)
		metrics.append(inspect_blade(model,kind))
		var old:Array=HIT_MARKERS[kind]
		check(built.base.position==old[0] and (built.tip.position==old[1] if kind=="knife" else built.tip.position.y>old[1].y),kind+" blade base preserved; measured sword tip extends and unmeasured knife unchanged")
		var pommel:MeshInstance3D=model.get_node("Pommel");var end:Vector3=pommel.position-Vector3.UP*pommel.mesh.size.y*.5
		check(absf(end.distance_to(built.tip.position)-(.38 if kind=="knife" else 1.4101590361445784))<.000001,kind+" exact total span preserved")
		check(Assets.GRIP==Vector3(0,-.057,.025),kind+" true-SI tracked fist anchor preserved")
		if kind!="knife":check(absf(Assets.GRIP.distance_to(end)-0.23502650602409636)<.000001,kind+" primary fist is exactly eight inches from outer pommel")
		var grip:MeshInstance3D=model.get_node("GripCore");var low:float=grip.position.y-grip.mesh.size.y*.5;var high:float=grip.position.y+grip.mesh.size.y*.5
		check(Assets.GRIP.y-.05>low and Assets.GRIP.y+.05<high,kind+" actual handle surrounds the primary fist")
		if kind=="knife":
			var guard:MeshInstance3D=model.get_node("KnifeGuard");var guard_bottom:float=guard.position.y-guard.mesh.size.y*.5
			var neck:MeshInstance3D=model.get_node_or_null("KnifeTangNeck")
			check(neck!=null,"knife blade/guard is physically joined to handle rather than floating over 10 mm gap")
			if neck!=null:
				check(absf(neck.position.y-neck.mesh.size.y*.5-high)<.000001 and absf(neck.position.y+neck.mesh.size.y*.5-guard_bottom)<.000001,"knife neck meets actual handle end and guard underside")
				var edges:Dictionary={};var wrong:=0;var degenerate:=0
				for triangle in triangle_data(neck.mesh):
					var a:Vector3=triangle.v[0];var b:Vector3=triangle.v[1];var c:Vector3=triangle.v[2];var cross:Vector3=(c-a).cross(b-a)
					if cross.length_squared()<1e-18:degenerate+=1;continue
					if cross.dot((a+b+c)/3)<=0:wrong+=1
					for n in triangle.n:
						if n.dot(cross.normalized())<.999:wrong+=1
					for pair in [[a,b],[b,c],[c,a]]:
						var first:=key(pair[0]);var second:=key(pair[1]);var id:=first+"/"+second if first<second else second+"/"+first
						edges[id]=int(edges.get(id,0))+1
				check(degenerate==0 and wrong==0,"knife neck actual stored triangles and supplied normals face outward")
				check(edges.values().all(func(n:int):return n==2),"knife tang neck is a real closed solid")
		poses.append({"kind":kind,"base":[built.base.position.x,built.base.position.y,built.base.position.z],"tip":[built.tip.position.x,built.tip.position.y,built.tip.position.z],"grip":[Assets.GRIP.x,Assets.GRIP.y,Assets.GRIP.z],"pommel":[end.x,end.y,end.z]})
		model.free()
	print("MELEE_GEOMETRY_064_POSES ",JSON.stringify(poses))
	print("MELEE_GEOMETRY_064_METRICS ",JSON.stringify(metrics))
	print("MELEE_GEOMETRY_064 checks=",checks," failures=",failures," actual_render_vertices=true gpu=false xr=false")
	quit(failures)
