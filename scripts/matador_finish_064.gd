extends RefCounted
## Restrained original paired-shotgun manufacture. All dimensions are authored.
## Pure mesh building: no input, state, processing, physics or reload logic.
const Finish=preload("res://scripts/weapon_finish.gd")
static func _finish(color:Color,metal:float,rough:float)->StandardMaterial3D:
	var material:=Finish.finish(color,metal,rough);material.uv1_triplanar=true;material.uv1_scale=Vector3(18,18,18);return material
static func _quad(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	var outward:Vector3=(b-a).cross(c-a).normalized()
	# Godot uses clockwise fronts; preserve outward normals while reversing the
	# conventional outward perimeter. Every generator is indexed before batching.
	for vertex in [a,c,b,a,d,c]:surface.set_normal(outward);surface.add_vertex(vertex)
static func tube(parent:Node3D,label:String,point:Vector3,length:float,outer:float,inner:float,material:Material)->MeshInstance3D:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var a:float=TAU*i/24.0;var b:float=TAU*(i+1)/24.0
		var o0:=Vector3(cos(a)*outer,sin(a)*outer,-length*.5);var o1:=Vector3(cos(b)*outer,sin(b)*outer,-length*.5)
		var o2:=Vector3(o1.x,o1.y,length*.5);var o3:=Vector3(o0.x,o0.y,length*.5)
		var i0:=Vector3(cos(a)*inner,sin(a)*inner,-length*.5);var i1:=Vector3(cos(b)*inner,sin(b)*inner,-length*.5)
		var i2:=Vector3(i1.x,i1.y,length*.5);var i3:=Vector3(i0.x,i0.y,length*.5)
		_quad(surface,o0,o1,o2,o3);_quad(surface,i0,i3,i2,i1);_quad(surface,o0,i0,i1,o1);_quad(surface,o3,o2,i2,i3)
	surface.index();var mesh:=MeshInstance3D.new();mesh.name=label;mesh.mesh=surface.commit();mesh.material_override=material;mesh.position=point;parent.add_child(mesh);return mesh
static func _pin(w,parent:Node3D,side:float,y:float,z:float,metal:Material,dark:Material)->void:
	w._rod(Vector3(side*.037,y,z),Vector3(side*.039,y,z),.003,metal,10,parent)
	w._box(Vector3(.0006,.001,.004),Vector3(side*.0395,y,z),dark,parent)
static func _batch(parent:Node3D)->void:
	var finishes:Dictionary={};var generated:=0
	for child in parent.get_children():
		if not child is MeshInstance3D:continue
		var material:Material=child.material_override
		if not finishes.has(material):finishes[material]=[]
		finishes[material].append(child)
		for surface in child.mesh.get_surface_count():
			var arrays:Array=child.mesh.surface_get_arrays(surface);var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			assert(not indices.is_empty(),"Matador source geometry must be indexed before append_from")
			generated+=indices.size()/3
	for material in finishes:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in finishes[material]:
			for index in part.mesh.get_surface_count():surface.append_from(part.mesh,index,part.transform)
			part.free()
		surface.index();var mesh:=MeshInstance3D.new();mesh.name="IndexedMatadorHardware";mesh.mesh=surface.commit();mesh.material_override=material;parent.add_child(mesh)
	parent.set_meta("generated_indexed_triangles",generated)
static func matador(w)->void:
	var metal:=_finish(Color("56636a"),.80,.35);var edge:=_finish(Color("848e91"),.82,.31)
	var dark:=_finish(Color("1b252a"),.30,.68);var grip:=_finish(Color("303536"),.02,.86)
	var root:=Node3D.new();root.name="MatadorManufacture064";root.set_meta("original_matador_detail064",true);w.model.add_child(root)
	# Keep the existing receiver and grip envelopes, barrel axes and ends. The
	# source footage does not supply physical dimensions for this original model.
	w._beveled(Vector3(.08,.10,.20),Vector3(0,.025,-.10),metal,.012,root)
	w._beveled(Vector3(.055,.12,.065),Vector3(0,-.075,.015),grip,.010,root)
	for x in [-.021,.021]:
		tube(root,"HollowBarrelBody",Vector3(x,.045,-.264),.168,.017,.012,metal)
		tube(root,"RecessedTwinCrown",Vector3(x,.045,-.354),.012,.018,.0124,edge)
		tube(root,"BarrelSeatCollar",Vector3(x,.045,-.189),.018,.018,.0172,dark)
	w._beveled(Vector3(.067,.014,.068),Vector3(0,.035,-.225),dark,.003,root)
	for z in [-.248,-.232,-.216,-.200]:w._box(Vector3(.065,.0015,.002),Vector3(0,.028,z),grip,root)
	w._beveled(Vector3(.050,.009,.012),Vector3(0,.045,-.224),metal,.002,root)
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.002,.037,.138),Vector3(side*.038,.013,-.10),dark,.002,root)
		w._box(Vector3(.001,.0015,.14),Vector3(side*.039,-.006,-.10),metal,root)
		for z in [-.167,-.035]:_pin(w,root,side,.030,z,edge,dark)
		w._beveled(Vector3(.002,.070,.043),Vector3(side*.0265,-.073,.015),dark,.004,root)
		for i in 6:w._box(Vector3(.001,.0015,.035),Vector3(side*.027,-.044-i*.012,.015),grip,root)
	w._beveled(Vector3(.055,.008,.065),Vector3(0,-.131,.015),dark,.002,root)
	w._beveled(Vector3(.038,.005,.132),Vector3(0,.070,-.10),dark,.001,root)
	for z in [-.151,-.125,-.099,-.073,-.047]:w._box(Vector3(.040,.002,.009),Vector3(0,.073,z),metal,root)
	var guard:Array[Vector3]=[Vector3(0,-.022,-.020),Vector3(0,-.077,-.032),Vector3(0,-.077,-.084),Vector3(0,-.025,-.095)]
	for i in guard.size()-1:w._rod(guard[i],guard[i+1],.0032,dark,10,root)
	w._rod(Vector3(0,-.026,-.060),Vector3(0,-.056,-.052),.0022,metal,10,root)
	_batch(root)
