extends RefCounted
## Original visual hardware only. No physics, control polling or reload state.
const Finish=preload("res://scripts/weapon_finish.gd")

static func _finish(color:Color,metal:float,rough:float)->StandardMaterial3D:
	var material:=Finish.finish(color,metal,rough)
	material.uv1_triplanar=true;material.uv1_scale=Vector3(18,18,18)
	return material
static func _group(parent:Node3D,label:String)->Node3D:
	var node:=Node3D.new();node.name=label;node.set_meta("original_heavy_model_detail",true);parent.add_child(node);return node
static func _quad(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	var normal:Vector3=(b-a).cross(c-a).normalized()
	# The supplied loop describes the outward geometric normal. Godot's render
	# fronts are clockwise: reverse triangle order, retain that outward normal.
	for point in [a,c,b,a,d,c]:surface.set_normal(normal);surface.add_vertex(point)
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
			for vertex in [triangle[0],triangle[2],triangle[1]]:surface.set_normal(normal);surface.add_vertex(vertex)
	surface.index();var mesh:=MeshInstance3D.new();mesh.name="SculptedGripShell";mesh.mesh=surface.commit();mesh.material_override=material;node.add_child(mesh);return node

static func _batch(parent:Node3D)->void:
	var groups:Dictionary={}
	for child in parent.get_children():
		if child is MeshInstance3D and child.mesh!=null and child.get_child_count()==0:
			var material:Material=child.material_override
			if not groups.has(material):groups[material]=[]
			groups[material].append(child)
	for material in groups:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[material]:
			for index in part.mesh.get_surface_count():surface.append_from(part.mesh,index,part.transform)
			part.free()
		var mesh:=MeshInstance3D.new();mesh.name="BatchedOriginalHardware";mesh.mesh=surface.commit();mesh.material_override=material;parent.add_child(mesh)

static func _fastener(w,parent:Node3D,point:Vector3,material:Material,dark:Material)->void:
	var side:=signf(point.x)
	w._rod(point,point+Vector3(side*.002,0,0),.0033,material,10,parent)
	w._box(Vector3(.0007,.0012,.004),point+Vector3(side*.0025,0,0),dark,parent)

static func m60(w)->void:
	var steel:=_finish(Color("475058"),.84,.34);var edge:=_finish(Color("818780"),.82,.30)
	var dark:=_finish(Color("171e22"),.55,.48);var rubber:=_finish(Color("272b29"),.02,.86)
	var brass:=_finish(Color("b09154"),.78,.30)
	var root:=_group(w.model,"M60OriginalDetail063")
	tube(root,"PerforatedCoolingShroud",Vector3(0,.04,-.545),.39,.032,.0285,steel,true)
	for z in [-.335,-.745]:tube(root,"ShroudRetainingCollar",Vector3(0,.04,z),.016,.034,.0215,dark)
	tube(root,"RecessedMuzzleCrown",Vector3(0,.04,-.900),.020,.024,.014,steel)
	w._rod(Vector3(0,.04,-.889),Vector3(0,.04,-.891),.0145,dark,16,root)
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.003,.052,.25),Vector3(side*.051,.014,-.17),dark,.001,root)
		w._beveled(Vector3(.004,.006,.22),Vector3(side*.051,.045,-.17),edge,.001,root)
		for z in [-.275,-.075]:_fastener(w,root,Vector3(side*.053,.008,z),edge,dark)
		w._box(Vector3(.001,.003,.13),Vector3(side*.054,-.006,-.17),steel,root)
		w._beveled(Vector3(.003,.065,.038),Vector3(side*.024,-.095,0),rubber,.002,root)
	w._beveled(Vector3(.082,.098,.012),Vector3(0,-.025,.294),rubber,.005,root)
	for i in 6:w._box(Vector3(.084,.002,.003),Vector3(0,-.062+i*.014,.301),dark,root)
	var cover:=_group(w.cover,"FeedCoverSkin063")
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.006,.016,.214),Vector3(side*.045,-.005,-.067),dark,.002,cover)
		for z in [-.145,.02]:_fastener(w,cover,Vector3(side*.050,-.002,z),edge,dark)
	w._box(Vector3(.078,.002,.18),Vector3(0,.012,-.07),steel,cover)
	for z in [-.145,-.105,-.065,-.025]:w._box(Vector3(.072,.0015,.002),Vector3(0,.0135,z),dark,cover)
	for box in [w.belt_box,w.offered_box,w.held_box]:
		var skin:=_group(box,"AmmoBoxSkin063")
		for side in [-1.0,1.0]:
			w._beveled(Vector3(.003,.10,.125),Vector3(side*.071,0,0),steel,.001,skin)
			for z in [-.047,0.0,.047]:w._box(Vector3(.004,.092,.003),Vector3(side*.073,0,z),dark,skin)
		w._beveled(Vector3(.13,.008,.15),Vector3(0,.07,0),steel,.002,skin)
		w._beveled(Vector3(.13,.009,.15),Vector3(0,-.07,0),rubber,.002,skin);_batch(skin)
	var linked:=_group(w.belt,"BeltCartridgeDetail063")
	for i in 6:
		var x:float=-.10+i*.018
		w._rod(Vector3(x,.075,-.148),Vector3(x,.075,-.154),.0066,edge,10,linked)
		w._rod(Vector3(x,.075,-.230),Vector3(x,.075,-.239),.0038,brass,10,linked)
		w._box(Vector3(.014,.003,.024),Vector3(x,.083,-.185),steel,linked)
	w._beveled(Vector3(.035,.005,.030),Vector3(-.10,.100,-.19),dark,.002,linked)
	_batch(root);_batch(cover);_batch(linked)

static func dt11(w)->void:
	var steel:=_finish(Color("555d60"),.86,.30);var edge:=_finish(Color("91938b"),.82,.27)
	var dark:=_finish(Color("20272a"),.65,.43);var wood:=_finish(Color("45362b"),.03,.56)
	var root:=_group(w.model,"DT11OriginalDetail063")
	# Replace only the anonymous coarse fore-end/ribs, not markers, mouths,
	# cartridge meshes, cue geometry or any moving parent transform.
	for part in w.hinge.get_children():
		if part is MeshInstance3D and part.mesh is BoxMesh:
			var size:Vector3=part.mesh.size
			if size.is_equal_approx(Vector3(.07,.055,.24)) or size.is_equal_approx(Vector3(.075,.005,.009)):part.hide()
	var fore:=_foreend(w.hinge,w.fore_end_marker.position,.24,.07,.055,wood)
	for side in [-1.0,1.0]:
		for i in 9:
			var groove=w._box(Vector3(.0017,.017,.002),Vector3(side*.033,-.006,-.087+i*.020),dark,fore);groove.rotation.x=.55*side
		w._beveled(Vector3(.0025,.049,.125),Vector3(side*.0435,0,-.055),steel,.001,root)
		for z in [-.104,-.014]:_fastener(w,root,Vector3(side*.045,.001,z),edge,dark)
		w._rod(Vector3(side*.057,-.02,-.13),Vector3(side*.061,-.02,-.13),.010,steel,16,root)
	var barrels:=_group(w.hinge,"BarrelBreechDetail063")
	for x in [-.027,.027]:
		tube(barrels,"MachinedMuzzleCrown",Vector3(x,.155,-.520),.014,.026,.019,edge)
		w._rod(Vector3(x,.155,-.509),Vector3(x,.155,-.511),.018,dark,16,barrels)
		w._box(Vector3(.006,.003,.37),Vector3(x,.179,-.275),steel,barrels)
	w._beveled(Vector3(.037,.012,.014),Vector3(0,.126,.012),steel,.002,barrels)
	for z in [-.17,-.24,-.31,-.38,-.45]:w._box(Vector3(.009,.0025,.017),Vector3(0,.183,z),dark,barrels)
	for i in 6:w._box(Vector3(.068,.002,.002),Vector3(0,-.065+i*.016,.300),dark,root)
	_batch(root);_batch(fore);_batch(barrels)

static func m1014(w)->void:
	var steel:=_finish(Color("5d666b"),.84,.31);var edge:=_finish(Color("94958d"),.82,.26)
	var dark:=_finish(Color("172025"),.48,.52);var polymer:=_finish(Color("2b302e"),.03,.78)
	var root:=_group(w.model,"M1014OriginalDetail063")
	for part in w.model.get_children():
		if part is MeshInstance3D and part.position.is_equal_approx(w.FOREGRIP_POINT) and part.mesh.get_aabb().size.is_equal_approx(Vector3(.075,.055,.25)):part.hide()
	var fore:=_foreend(w.model,w.FOREGRIP_POINT,.25,.075,.055,polymer)
	for side in [-1.0,1.0]:
		for i in 10:w._beveled(Vector3(.002,.030,.003),Vector3(side*.035,0,-.095+i*.020),dark,.0005,fore)
		w._beveled(Vector3(.003,.044,.18),Vector3(side*.041,.035,-.16),steel,.002,root)
		w._beveled(Vector3(.0015,.026,.092),Vector3(side*.043,.039,-.115),dark,.001,root)
		for z in [-.235,-.06]:_fastener(w,root,Vector3(side*.044,.016,z),edge,dark)
		for i in 6:w._box(Vector3(.002,.002,.044),Vector3(side*.028,-.122+i*.014,0),dark,root)
	tube(root,"SlottedBarrelShield",Vector3(0,.045,-.395),.23,.0275,.0235,dark,true)
	tube(root,"MuzzleCrown",Vector3(0,.045,-.764),.012,.025,.015,steel)
	w._rod(Vector3(0,.045,-.7605),Vector3(0,.045,-.762),.0152,dark,16,root)
	for z in [-.58,-.69]:
		w._beveled(Vector3(.043,.024,.018),Vector3(0,.016,z),steel,.004,root)
		for side in [-1.0,1.0]:_fastener(w,root,Vector3(side*.023,.017,z),edge,dark)
	w._rod(Vector3(0,-.008,-.706),Vector3(0,-.008,-.718),.0185,steel,16,root)
	w._rod(Vector3(0,-.008,-.718),Vector3(0,-.008,-.720),.007,dark,12,root)
	w._beveled(Vector3(.071,.105,.012),Vector3(0,-.024,.290),polymer,.005,root)
	for i in 6:w._box(Vector3(.070,.002,.002),Vector3(0,-.065+i*.016,.297),dark,root)
	var handle:=_group(w.bolt,"ChargingKnobSkin063")
	w._rod(Vector3(-.014,0,0),Vector3(.014,0,0),.0105,dark,16,handle)
	for i in 8:
		var angle:float=TAU*i/8
		w._rod(Vector3(-.014,cos(angle)*.010,sin(angle)*.010),Vector3(.014,cos(angle)*.010,sin(angle)*.010),.0012,edge,6,handle)
	# Shell hulls and brass bases stay at the existing pack coordinates; there
	# is no realistic per-shell loading rule added to the observed UP pack.
	var pack:=_group(w.shell_pack,"ShellPackManufacture063")
	for i in 6:
		var point:=Vector3(0,(i-2.5)*.035,0) #0991 one vertical column of six, matching the underlying shells
		w._rod(point+Vector3(0,0,-.008),point+Vector3(0,0,-.055),.0142,polymer,12,pack)
		w._rod(point,point+Vector3(0,0,-.009),.0148,edge,12,pack)
		w._rod(point+Vector3(0,0,.0005),point+Vector3(0,0,.001),.004,dark,10,pack)
	_batch(root);_batch(fore);_batch(handle);_batch(pack)
