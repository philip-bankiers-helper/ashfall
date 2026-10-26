extends SceneTree
## Independent stored-array regression, calibrated against Godot's own BoxMesh.
## Legacy classes below are verbatim function bodies from preserved063 helpers,
## indented only for an embedded negative control; production resources stay untouched.
const Heavy=preload("res://scripts/heavy_model_finish.gd")
const Finish=preload("res://scripts/weapon_finish.gd")
class LegacyHeavy063 extends RefCounted:
	static func _group(parent:Node3D,label:String)->Node3D:
		var node:=Node3D.new();node.name=label;node.set_meta("original_heavy_model_detail",true);parent.add_child(node);return node

	static func _quad(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
		var normal:Vector3=(b-a).cross(c-a).normalized()
		for point in [a,b,c,a,c,d]:surface.set_normal(normal);surface.add_vertex(point)

	static func _ring_point(radius:float,angle:float,z:float)->Vector3:return Vector3(cos(angle)*radius,sin(angle)*radius,z)


	static func tube(parent:Node3D,label:String,point:Vector3,length:float,outer:float,inner:float,material:Material,vented:bool=false)->MeshInstance3D:
		# Closed wall thickness, real through apertures and an open bore. Each vent
		# boundary gets its own cut face rather than a dark painted rectangle.
		var sides:=24;var rows:=20 if vented else 1
		var solid:Array[bool]=[]
		for row in rows:
			for sector in sides:solid.append(not (vented and row>0 and row<rows-1 and row%4 in [1,2] and sector%6 in [1,2]))
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in rows:
			var z0:float=-length*.5+length*float(row)/rows;var z1:float=-length*.5+length*float(row+1)/rows
			for sector in sides:
				if not solid[row*sides+sector]:continue
				var a:float=TAU*sector/sides;var b:float=TAU*(sector+1)/sides
				var o0:=_ring_point(outer,a,z0);var o1:=_ring_point(outer,b,z0);var o2:=_ring_point(outer,b,z1);var o3:=_ring_point(outer,a,z1)
				var i0:=_ring_point(inner,a,z0);var i1:=_ring_point(inner,b,z0);var i2:=_ring_point(inner,b,z1);var i3:=_ring_point(inner,a,z1)
				_quad(surface,o0,o1,o2,o3);_quad(surface,i0,i3,i2,i1)
				if row==0 or not solid[(row-1)*sides+sector]:_quad(surface,o0,i0,i1,o1)
				if row==rows-1 or not solid[(row+1)*sides+sector]:_quad(surface,o3,o2,i2,i3)
				if not solid[row*sides+(sector+sides-1)%sides]:_quad(surface,o0,o3,i3,i0)
				if not solid[row*sides+(sector+1)%sides]:_quad(surface,o1,i1,i2,o2)
		surface.index();var mesh:=MeshInstance3D.new();mesh.name=label;mesh.mesh=surface.commit();mesh.material_override=material;mesh.position=point;parent.add_child(mesh)
		mesh.set_meta("open_bore",true);mesh.set_meta("through_vents",vented);return mesh


	static func _foreend(parent:Node3D,point:Vector3,length:float,width:float,height:float,material:Material)->Node3D:
		var node:=_group(parent,"ContouredForeEnd063");node.position=point
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings:Array[PackedVector3Array]=[]
		for station in [[-.5,.70,.76],[-.30,.95,.94],[.23,1.0,1.0],[.5,.76,.86]]:
			var x:float=width*.5*station[1];var y:float=height*.5*station[2];var bevel:float=minf(x,y)*.30
			var ring:=PackedVector3Array()
			for corner in [Vector2(-x+bevel,-y),Vector2(x-bevel,-y),Vector2(x,-y+bevel),Vector2(x,y-bevel),Vector2(x-bevel,y),Vector2(-x+bevel,y),Vector2(-x,y-bevel),Vector2(-x,-y+bevel)]:ring.append(Vector3(corner.x,corner.y,length*station[0]))
			rings.append(ring)
		for station in rings.size()-1:
			for i in 8:_quad(surface,rings[station][i],rings[station][(i+1)%8],rings[station+1][(i+1)%8],rings[station+1][i])
		for i in 8:
			for triangle in [[Vector3(0,0,-length*.5),rings[0][(i+1)%8],rings[0][i]],[Vector3(0,0,length*.5),rings[-1][i],rings[-1][(i+1)%8]]]:
				var normal:Vector3=(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
				for vertex in triangle:surface.set_normal(normal);surface.add_vertex(vertex)
		surface.index();var mesh:=MeshInstance3D.new();mesh.name="SculptedGripShell";mesh.mesh=surface.commit();mesh.material_override=material;node.add_child(mesh);return node


class LegacyStock063 extends RefCounted:
	static func tapered_stock(parent:Node3D,material:Material)->void:
		var vertices:PackedVector3Array=[Vector3(-0.022,-0.025,0.055),Vector3(0.022,-0.025,0.055),Vector3(0.022,0.025,0.055),Vector3(-0.022,0.025,0.055),Vector3(-0.035,-0.08,0.285),Vector3(0.035,-0.08,0.285),Vector3(0.035,0.03,0.285),Vector3(-0.035,0.03,0.285)]
		var triangles:PackedInt32Array=[0,2,1,0,3,2,4,5,6,4,6,7,0,4,7,0,7,3,1,2,6,1,6,5,3,7,6,3,6,2,0,1,5,0,5,4]
		var surface:=SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in triangles:surface.add_vertex(vertices[index])
		surface.generate_normals()
		surface.index()
		var mesh:=MeshInstance3D.new()
		mesh.mesh=surface.commit()
		mesh.material_override=material
		parent.add_child(mesh)


var checks:=0
var failures:=0
var records:Array=[]
var primitive_sign:=0.0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func key(v:Vector3)->String:return "%d,%d,%d"%[roundi(v.x*1000000),roundi(v.y*1000000),roundi(v.z*1000000)]
func triangle_data(mesh:Mesh)->Array:
	var result:Array=[]
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface);var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var n:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if ids.is_empty():
			for i in v.size():ids.append(i)
		for i in range(0,ids.size(),3):result.append({"v":[v[ids[i]],v[ids[i+1]],v[ids[i+2]]],"n":[n[ids[i]],n[ids[i+1]],n[ids[i+2]]]})
	return result
func measure(mesh:Mesh,label:String,flat:bool,interior:Variant=null)->Dictionary:
	var triangles:=triangle_data(mesh);var vertices:Dictionary={};var edges:Dictionary={};var directions:Dictionary={}
	var degenerate:=0;var invalid_vertices:=0;var invalid_normals:=0;var misaligned:=0;var inward:=0;var volume:=0.0;var min_dot:=1.0
	for t in triangles:
		var a:Vector3=t.v[0];var b:Vector3=t.v[1];var c:Vector3=t.v[2]
		for vertex in t.v:
			if not vertex.is_finite():invalid_vertices+=1
			vertices[key(vertex)]=true
		var cross:Vector3=(c-a).cross(b-a)
		if cross.length_squared()<1e-20:degenerate+=1;continue
		var clockwise:=cross.normalized()
		if interior!=null and clockwise.dot((a+b+c)/3-interior)<=0:inward+=1
		for normal in t.n:
			if not normal.is_finite() or absf(normal.length()-1)>.001:invalid_normals+=1
			var dot:float=normal.dot(clockwise);min_dot=minf(min_dot,dot)
			if dot<(.999 if flat else .000001):misaligned+=1
		volume+=a.dot(b.cross(c))/6.0
		for pair in [[a,b],[b,c],[c,a]]:
			var first:=key(pair[0]);var second:=key(pair[1]);var id:=first+"/"+second if first<second else second+"/"+first
			edges[id]=int(edges.get(id,0))+1;directions[first+"/"+second]=int(directions.get(first+"/"+second,0))+1
	var bad_edges:=0;var bad_directions:=0
	for count in edges.values():
		if count!=2:bad_edges+=1
	for id in directions:
		var split:PackedStringArray=id.split("/")
		if directions[id]!=int(directions.get(split[1]+"/"+split[0],0)):bad_directions+=1
	return {"label":label,"triangles":triangles.size(),"vertices":vertices.size(),"edges":edges.size(),"euler":vertices.size()-edges.size()+triangles.size(),"bad_edges":bad_edges,"bad_directions":bad_directions,"degenerate":degenerate,"invalid_vertices":invalid_vertices,"invalid_normals":invalid_normals,"normal_front_mismatches":misaligned,"inward_convex_faces":inward,"min_normal_clockwise_dot":min_dot,"signed_volume":volume}
func accepted(data:Dictionary)->bool:
	return data.bad_edges==0 and data.bad_directions==0 and data.degenerate==0 and data.invalid_vertices==0 and data.invalid_normals==0 and data.normal_front_mismatches==0 and data.inward_convex_faces==0 and signf(data.signed_volume)==primitive_sign
func require_current(data:Dictionary)->void:
	records.append(data);var label:String=data.label
	check(data.bad_edges==0 and data.bad_directions==0,label+" actual triangle shell is closed with consistent cap/side directions")
	check(data.degenerate==0 and data.invalid_vertices==0,label+" stored triangles are finite and nondegenerate")
	check(data.invalid_normals==0 and data.normal_front_mismatches==0,label+" supplied normals align with Godot clockwise negative-cross fronts")
	check(signf(data.signed_volume)==primitive_sign and absf(data.signed_volume)>1e-10,label+" outward signed-volume orientation matches built-in BoxMesh")
	check(data.inward_convex_faces==0,label+" convex face fronts point away from interior datum when applicable")
func segment_hit(tris:Array,from:Vector3,to:Vector3)->bool:
	var delta:=to-from
	for triangle in tris:
		var point:Variant=Geometry3D.ray_intersects_triangle(from,delta.normalized(),triangle.v[0],triangle.v[1],triangle.v[2])
		if point!=null and (point-from).length()<=delta.length()+.0000001:return true
	return false
func tube_faces_outward(tris:Array,outer:float,inner:float,length:float)->int:
	var bad:=0
	for t in tris:
		var a:Vector3=t.v[0];var b:Vector3=t.v[1];var c:Vector3=t.v[2];var centre:Vector3=(a+b+c)/3;var cw:Vector3=(c-a).cross(b-a)
		var all_outer:=true;var all_inner:=true
		for v in [a,b,c]:
			var radius:float=Vector2(v.x,v.y).length();all_outer=all_outer and absf(radius-outer)<.000001;all_inner=all_inner and absf(radius-inner)<.000001
		if all_outer and cw.dot(Vector3(centre.x,centre.y,0))<=0:bad+=1
		if all_inner and cw.dot(Vector3(-centre.x,-centre.y,0))<=0:bad+=1
		if absf(a.z-b.z)<.000001 and absf(a.z-c.z)<.000001 and absf(absf(a.z)-length*.5)<.000001:
			if cw.z*signf(a.z)<=0:bad+=1
	return bad
func run()->void:
	# 077 retained authored asset coverage; downloaded versions have separate tracker/geometry tests.
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var finish:=StandardMaterial3D.new();var box:=BoxMesh.new();box.size=Vector3(.11,.07,.19)
	var calibration:=measure(box,"Primitive BoxMesh calibration",true,Vector3.ZERO);primitive_sign=signf(calibration.signed_volume)
	check(primitive_sign==-1 and absf(absf(calibration.signed_volume)-.11*.07*.19)<1e-9,"built-in BoxMesh independently establishes Godot clockwise outward negative volume")
	require_current(calibration)
	check(segment_hit(triangle_data(box),Vector3(0,0,-.20),Vector3(0,0,.20)),"aperture ray fixture rejects an actually solid box")
	var tube_specs:Array=[
		["M60 vented shroud",.39,.032,.0285,true,Vector3(0,.04,-.545)],
		["M1014 vented shield",.23,.0275,.0235,true,Vector3(0,.045,-.395)],
		["M60 collar",.016,.034,.0215,false,Vector3(0,.04,-.335)],
		["DT11 muzzle crown",.014,.026,.019,false,Vector3(-.027,.155,-.520)]]
	for spec in tube_specs:
		var holder:=Node3D.new();root.add_child(holder);var label:String=spec[0];var length:float=spec[1];var outer:float=spec[2];var inner:float=spec[3];var vented:bool=spec[4]
		var mesh:=Heavy.tube(holder,label,spec[5],length,outer,inner,finish,vented);var current:=measure(mesh.mesh,label,true);require_current(current)
		var tris:=triangle_data(mesh.mesh)
		check(mesh.position==spec[5] and mesh.mesh.get_aabb().size.is_equal_approx(Vector3(outer*2,outer*2,length)),label+" physical length/radius and original mount position are retained")
		var minimum_radius:=INF;var maximum_radius:=0.0
		for t in tris:
			for v in t.v:
				var r:=Vector2(v.x,v.y).length();minimum_radius=minf(minimum_radius,r);maximum_radius=maxf(maximum_radius,r)
		check(absf(minimum_radius-inner)<.000001 and absf(maximum_radius-outer)<.000001,label+" actual inner bore and outer wall radii equal requested dimensions")
		check(tube_faces_outward(tris,outer,inner,length)==0,label+" outer wall, inner bore and both annular ends face their actual outside")
		for xy in [Vector2.ZERO,Vector2(inner*.75,0),Vector2(0,-inner*.75)]:
			check(not segment_hit(tris,Vector3(xy.x,xy.y,-length*.5-.01),Vector3(xy.x,xy.y,length*.5+.01)),label+" bore has real through visibility at "+str(xy))
		check(segment_hit(tris,Vector3((inner+outer)*.5,0,-length*.5-.01),Vector3((inner+outer)*.5,0,length*.5+.01)),label+" annular end wall is real solid material")
		var polygon_volume:=12.0*sin(TAU/24.0)*(outer*outer-inner*inner)*length
		if not vented:check(absf(absf(current.signed_volume)-polygon_volume)<1e-9,label+" material volume equals independent24-gon annulus formula")
		else:check(absf(current.signed_volume)<polygon_volume*.95 and absf(current.signed_volume)>polygon_volume*.5,label+" through windows remove physical wall volume")
		check(current.euler==(-40 if vented else 0),label+" closed shell Euler characteristic proves bore and20vent openings when enabled")
		var filled_control:MeshInstance3D
		var filled_tris:Array=[]
		if vented:
			filled_control=Heavy.tube(holder,"Same-size nonvented control",Vector3.ZERO,length,outer,inner,finish,false);filled_tris=triangle_data(filled_control.mesh)
		for z in [-.40,-.20,0.0,.20,.40] if vented else [0.0]:
			for angle in [30.0,120.0,210.0,300.0]:
				var direction:=Vector3(cos(deg_to_rad(angle)),sin(deg_to_rad(angle)),0);var from:=direction*(outer+.01)+Vector3(0,0,z*length);var to:=direction*(inner*.75)+Vector3(0,0,z*length)
				check(segment_hit(tris,from,to)!=vented,label+" radial aperture/material proof angle="+str(angle)+" z_ratio="+str(z))
				if vented:check(segment_hit(filled_tris,from,to),label+" identical nonvented negative control actually blocks that window")
		# Real old helper, not an artificially flipped copy of the new output.
		var old:=LegacyHeavy063.tube(holder,"Legacy063",spec[5],length,outer,inner,finish,vented);var negative:=measure(old.mesh,label+" old063",true);records.append(negative)
		check(not accepted(negative) and negative.normal_front_mismatches>0 and signf(negative.signed_volume)!=primitive_sign,label+" regression rejects real063 mismatched normals/inward CW fronts")
		check(old.mesh.get_aabb()==mesh.mesh.get_aabb(),label+" old/current bounds match so negative control isolates winding rather than scale")
		holder.free()
	for spec in [["DT11 contoured fore-end",.24,.07,.055,Vector3(0,-.04,-.27)],["M1014 contoured fore-end",.25,.075,.055,Vector3(0,-.05,-.30)]]:
		var holder:=Node3D.new();root.add_child(holder);var node:=Heavy._foreend(holder,spec[4],spec[1],spec[2],spec[3],finish);var mesh:MeshInstance3D=node.get_child(0)
		var current:=measure(mesh.mesh,spec[0],true,Vector3.ZERO);require_current(current)
		check(node.position==spec[4] and mesh.mesh.get_aabb().size.is_equal_approx(Vector3(spec[2],spec[3],spec[1])),str(spec[0])+" contoured shell retains true width/height/length and mount")
		check(current.euler==2,str(spec[0])+" fore-end is one closed genus-zero shell")
		var old_node:=LegacyHeavy063._foreend(holder,spec[4],spec[1],spec[2],spec[3],finish);var old:MeshInstance3D=old_node.get_child(0);var negative:=measure(old.mesh,str(spec[0])+" old063",true,Vector3.ZERO);records.append(negative)
		check(not accepted(negative) and negative.normal_front_mismatches>0 and negative.inward_convex_faces>0,str(spec[0])+" regression rejects real063 side/cap winding-normal mismatch")
		check(old.mesh.get_aabb()==mesh.mesh.get_aabb(),str(spec[0])+" old/current dimensions remain identical")
		holder.free()
	var holder:=Node3D.new();root.add_child(holder);Finish.tapered_stock(holder,finish);var stock:MeshInstance3D=holder.get_child(0)
	# Stock's generated smooth vertex normals may differ from individual flat
	# triangle normals; require the same outward hemisphere, not identical vectors.
	var stock_metrics:=measure(stock.mesh,"Shared tapered stock",false,Vector3(0,-.0125,.17));require_current(stock_metrics)
	check(stock_metrics.euler==2,"tapered stock has one closed genus-zero shell")
	check(stock.mesh.get_aabb().position.is_equal_approx(Vector3(-.035,-.08,.055)) and stock.mesh.get_aabb().end.is_equal_approx(Vector3(.035,.03,.285)),"stock actual bounds preserve front/back height,width and230mm length")
	LegacyStock063.tapered_stock(holder,finish);var old_stock:MeshInstance3D=holder.get_child(1);var negative:=measure(old_stock.mesh,"Shared tapered stock old063",false,Vector3(0,-.0125,.17));records.append(negative)
	check(not accepted(negative) and signf(negative.signed_volume)!=primitive_sign and negative.inward_convex_faces>0,"stock regression rejects actual063 positive-volume inward-clockwise shell")
	check(old_stock.mesh.get_aabb()==stock.mesh.get_aabb(),"stock old/current actual bounds are unchanged")
	holder.free()
	print("MANUFACTURE_GEOMETRY_064_RECORDS ",JSON.stringify(records))
	print("MANUFACTURE_GEOMETRY_064 checks=",checks," failures=",failures," primitive_calibrated=true real063_negative_controls=true stored_arrays=true gpu=false xr=false")
	quit(failures)
