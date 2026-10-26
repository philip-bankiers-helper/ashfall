extends RefCounted
## Original manufacture geometry. Dimensions below are authored, not recovered
## from video perspective; this helper has no processing, physics or input.
const Finish=preload("res://scripts/weapon_finish.gd")
const Machined=preload("res://scripts/heavy_model_finish.gd")

static func _finish(color:Color,metal:float,rough:float)->StandardMaterial3D:
	var material:=Finish.finish(color,metal,rough)
	material.uv1_triplanar=true;material.uv1_scale=Vector3(18,18,18)
	return material
static func _group(parent:Node3D,label:String)->Node3D:
	var group:=Node3D.new();group.name=label;group.set_meta("original_remaining_detail064",true);parent.add_child(group);return group
static func _batch(group:Node3D)->void:Machined._batch(group)
static func _clockwise_quad(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
	# Input corners describe the conventional outward perimeter. Godot fronts are
	# clockwise, so stored triangle order is reversed while normals stay outward.
	var normal:Vector3=(b-a).cross(c-a).normalized()
	for vertex in [a,c,b,a,d,c]:surface.set_normal(normal);surface.add_vertex(vertex)
static func _tube(group:Node3D,label:String,point:Vector3,length:float,radius:float,bore:float,material:Material)->void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var a:float=TAU*i/24.0;var b:float=TAU*(i+1)/24.0
		var outer0:=Vector3(cos(a)*radius,sin(a)*radius,-length*.5);var outer1:=Vector3(cos(b)*radius,sin(b)*radius,-length*.5)
		var outer2:=Vector3(outer1.x,outer1.y,length*.5);var outer3:=Vector3(outer0.x,outer0.y,length*.5)
		var inner0:=Vector3(cos(a)*bore,sin(a)*bore,-length*.5);var inner1:=Vector3(cos(b)*bore,sin(b)*bore,-length*.5)
		var inner2:=Vector3(inner1.x,inner1.y,length*.5);var inner3:=Vector3(inner0.x,inner0.y,length*.5)
		_clockwise_quad(surface,outer0,outer1,outer2,outer3);_clockwise_quad(surface,inner0,inner3,inner2,inner1)
		_clockwise_quad(surface,outer0,inner0,inner1,outer1);_clockwise_quad(surface,outer3,outer2,inner2,inner3)
	surface.index();var mesh:=MeshInstance3D.new();mesh.name=label;mesh.mesh=surface.commit();mesh.material_override=material;mesh.position=point;group.add_child(mesh)
static func _pin(w,group:Node3D,point:Vector3,metal:Material,recess:Material,radius:float=.0035)->void:
	var side:=signf(point.x)
	w._rod(point,point+Vector3(side*.002,0,0),radius,metal,10,group)
	w._box(Vector3(.0007,.001,radius*1.4),point+Vector3(side*.0025,0,0),recess,group)
static func _rail(w,group:Node3D,z0:float,z1:float,y:float,material:Material)->void:
	var length:float=absf(z1-z0);var count:=maxi(2,int(length/.024))
	w._beveled(Vector3(.034,.004,length),Vector3(0,y,(z0+z1)*.5),material,.001,group)
	for i in count:
		w._beveled(Vector3(.040,.0035,.010),Vector3(0,y+.003,(z0+z1)*.5-length*.5+.009+float(i)*length/count),material,.0008,group)
static func _slotted_guard(w,group:Node3D,point:Vector3,size:Vector3,material:Material,edge:Material,label:String)->Node3D:
	# Actual open side windows assembled from thin wall webs. Neither dark decals
	# nor an invisible filled box sit behind these apertures.
	var guard:=_group(group,label);guard.position=point
	w._beveled(Vector3(size.x,.004,size.z),Vector3(0,size.y*.5-.002,0),material,.001,guard)
	w._beveled(Vector3(size.x*.88,.004,size.z),Vector3(0,-size.y*.5+.002,0),material,.001,guard)
	for side in [-1.0,1.0]:
		var x:float=side*(size.x*.5-.0015)
		w._beveled(Vector3(.003,.014,size.z),Vector3(x,size.y*.5-.009,0),material,.001,guard)
		w._beveled(Vector3(.003,.010,size.z),Vector3(x,-size.y*.5+.007,0),material,.001,guard)
		for i in 5:
			w._beveled(Vector3(.003,size.y-.014,.006),Vector3(x,0,lerpf(-size.z*.5+.003,size.z*.5-.003,i/4.0)),material,.001,guard)
		for z in [-size.z*.5+.013,size.z*.5-.013]:_pin(w,guard,Vector3(side*(size.x*.5+.0005),size.y*.5-.010,z),edge,material,.0025)
	_batch(guard);return guard
static func _magazine_skin(w,parent:Node3D,size:Vector3,metal:Material,dark:Material)->void:
	var skin:=_group(parent,"MagazineManufacture064")
	w._beveled(Vector3(size.x+.003,.008,size.z+.003),Vector3(0,-size.y*.5+.002,0),dark,.002,skin)
	for side in [-1.0,1.0]:
		for z in [-size.z*.22,size.z*.22]:
			w._beveled(Vector3(.0015,size.y*.68,.0025),Vector3(side*(size.x*.5+.0005),-.002,z),metal,.0005,skin)
	_batch(skin)
static func _charging_detail(w,parent:Node3D,metal:Material,dark:Material)->void:
	var group:=_group(parent,"ChargingHandleManufacture064")
	for z in [-.006,0.0,.006]:w._box(Vector3(.034,.0015,.0018),Vector3(0,.0065,z),dark,group)
	w._beveled(Vector3(.003,.014,.020),Vector3(-.016,0,0),metal,.001,group)
	_batch(group)

static func compact(w)->void:
	var metal:=_finish(Color("515b5c"),.77,.37);var edge:=_finish(Color("87908e"),.82,.32)
	var dark:=_finish(Color("20282a"),.35,.64);var rubber:=_finish(Color("343b37"),.02,.84)
	var root:=_group(w.model,"CompactManufacture064")
	_slotted_guard(w,root,Vector3(0,.035,-.315),Vector3(.061,.071,.18),dark,metal,"SlottedCompactGuard064")
	w._rod(Vector3(0,.045,-.225),Vector3(0,.045,-.392),.010,metal,16,root)
	_tube(root,"CompactMuzzleCrown",Vector3(0,.045,-.455),.010,.0135,.0065,metal)
	_tube(root,"CompactBarrelCollar",Vector3(0,.045,-.404),.018,.018,.0125,dark)
	_rail(w,root,-.225,-.035,.087,dark)
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.002,.034,.16),Vector3(side*.0335,.024,-.115),dark,.002,root)
		w._box(Vector3(.001,.0015,.18),Vector3(side*.035,-.004,-.11),metal,root)
		for z in [-.215,-.025]:_pin(w,root,Vector3(side*.034,.026,z),edge,dark)
		w._beveled(Vector3(.003,.060,.035),Vector3(side*.022,-.080,.007),dark,.003,root)
		for y in [-.062,-.080,-.098]:w._box(Vector3(.001,.0015,.025),Vector3(side*.024,y,.010),rubber,root)
		w._beveled(Vector3(.014,.025,.023),Vector3(side*.026,.035,.028),dark,.003,root)
	w._beveled(Vector3(.061,.103,.006),Vector3(0,-.003,.181),rubber,.002,root)
	for y in [-.04,-.02,0.0,.02,.04]:w._box(Vector3(.058,.002,.002),Vector3(0,y,.185),dark,root)
	for parent in [w.magazine,w.loose_magazine,w.hip_source]:_magazine_skin(w,parent,Vector3(.035,.18,.043),metal,dark)
	_charging_detail(w,w.bolt,metal,dark)
	_batch(root)

static func burst(w)->void:
	var metal:=_finish(Color("536064"),.78,.35);var edge:=_finish(Color("8b9291"),.82,.30)
	var dark:=_finish(Color("202c30"),.45,.58);var rubber:=_finish(Color("293231"),.02,.83)
	var root:=_group(w.model,"BurstManufacture064")
	# Rebuild only inherited stationary mesh batches. The original sight nodes,
	# removable magazines, carrier, charging handle and every target stay intact.
	for child in w.model.get_children():
		if child is MeshInstance3D and child not in [w.magazine,w.bolt,w.firing_carrier,w.guide,w.muzzle_flash] and child.name!="AuthoredReflexRailFoot":child.hide()
	w._beveled(Vector3(.073,.083,.32),Vector3(0,.035,-.11),metal,.012,root)
	w._beveled(Vector3(.068,.034,.25),Vector3(0,-.020,-.10),dark,.006,root)
	_slotted_guard(w,root,Vector3(0,.035,-.405),Vector3(.086,.080,.28),dark,edge,"SlottedBurstGuard064")
	w._rod(Vector3(0,.040,-.266),Vector3(0,.040,-.681),.011,metal,16,root)
	_tube(root,"BurstMuzzleCrown",Vector3(0,.045,-.680),.020,.020,.0115,dark)
	_tube(root,"BurstBarrelCollar",Vector3(0,.040,-.549),.022,.019,.012,metal)
	_rail(w,root,-.520,-.278,.079,dark);_rail(w,root,-.245,.025,.079,dark)
	for side in [-1.0,1.0]:
		w._box(Vector3(.0015,.002,.23),Vector3(side*.0375,-.004,-.105),dark,root)
		w._beveled(Vector3(.003,.018,.065),Vector3(side*.037,.016,-.20),dark,.002,root)
		for z in [-.220,-.035,.025]:_pin(w,root,Vector3(side*.037,.019,z),edge,dark)
		w._beveled(Vector3(.002,.004,.016),Vector3(side*.042,-.002,.014),metal,.0008,root)
		w._beveled(Vector3(.002,.021,.067),Vector3(side*.038,.039,-.11),dark,.001,root)
	w._rod(Vector3(0,.035,.043),Vector3(0,.035,.23),.017,dark,16,root)
	w._beveled(Vector3(.049,.034,.124),Vector3(0,.042,.165),dark,.008,root)
	w._rod(Vector3(0,-.015,.052),Vector3(0,-.052,.234),.007,metal,12,root)
	w._beveled(Vector3(.059,.116,.021),Vector3(0,0,.24),rubber,.006,root)
	for y in [-.04,-.02,0,.02,.04]:w._box(Vector3(.058,.002,.003),Vector3(0,y,.252),dark,root)
	var grip=w._beveled(Vector3(.043,.115,.058),Vector3(0,-.083,.012),rubber,.008,root);grip.rotation.x=-.24
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.002,.066,.036),Vector3(side*.0225,-.083,.016),dark,.003,root)
		for i in 5:w._box(Vector3(.001,.0015,.027),Vector3(side*.024,-.055-i*.014,.015),rubber,root)
	var guard:Array[Vector3]=[Vector3(0,-.025,-.013),Vector3(0,-.068,-.026),Vector3(0,-.068,-.088),Vector3(0,-.025,-.095)]
	for i in guard.size()-1:w._rod(guard[i],guard[i+1],.0035,dark,10,root)
	w._rod(Vector3(0,-.027,-.056),Vector3(0,-.052,-.048),.0025,metal,10,root)
	w._beveled(Vector3(.062,.025,.09),Vector3(0,-.024,-.15),dark,.006,root)
	w._beveled(Vector3(.052,.018,.14),Vector3(0,-.006,-.375),rubber,.006,root)
	for i in 7:w._box(Vector3(.054,.002,.004),Vector3(0,-.016,-.43+i*.018),dark,root)
	_charging_detail(w,w.bolt,metal,dark)
	_batch(root)

static func pistol(w)->void:
	var metal:=_finish(Color("55616a"),.82,.31);var dark:=_finish(Color("20272a"),.25,.72)
	var edge:=_finish(Color("8a9296"),.84,.28);var rubber:=_finish(Color("303738"),.02,.87)
	var root:=_group(w.model,"PistolManufacture064")
	var grip_detail:=_group(w.model.get_node("PX4Grip075"),"PX4GripPanels075")
	# Same slide parent/transform/travel, chamfered instead of a featureless box.
	var slide_shape=w._beveled(Vector3(.052,.058,.27),Vector3.ZERO,metal,.007,root)
	w.bolt.mesh=slide_shape.mesh;slide_shape.free()
	var slide:=_group(w.bolt,"SlideManufacture064")
	for side in [-1.0,1.0]:
		for i in 7:w._beveled(Vector3(.0015,.030,.0025),Vector3(side*.0265,0,.035+i*.007),dark,.0005,slide)
		w._beveled(Vector3(.0015,.006,.17),Vector3(side*.0265,-.021,-.024),dark,.001,slide)
		w._beveled(Vector3(.0015,.010,.031),Vector3(side*.027,.004,-.072),dark,.001,slide)
	w._beveled(Vector3(.019,.0015,.040),Vector3(.009,.029,-.034),dark,.001,slide)
	w._beveled(Vector3(.014,.001,.030),Vector3(.009,.030,-.034),edge,.0005,slide)
	_batch(slide)
	_tube(root,"PistolRecessedCrown",Vector3(0,.040,-.282),.016,.014,.0075,metal)
	w._beveled(Vector3(.046,.006,.11),Vector3(0,-.018,-.177),dark,.002,root)
	for i in 3:w._box(Vector3(.048,.003,.006),Vector3(0,-.022,-.212+i*.025),dark,root)
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.003,.082,.050),Vector3(side*.027,-.001,0),rubber,.005,grip_detail)
		for z in [-.017,.017]:
			for y in [.025,-.028]:_pin(w,grip_detail,Vector3(side*.029,y,z),metal,dark,.0024)
		for i in 6:w._box(Vector3(.0015,.0015,.034),Vector3(side*.029,.025-i*.011,0),dark,grip_detail)
		w._beveled(Vector3(.003,.006,.022),Vector3(side*.028,-.018,-.099),metal,.001,root)
	# -Z is muzzle-forward: the old trigger/guard were behind the grip.
	var trigger_guard:=_group(w.model,"PX4ForwardTrigger075");trigger_guard.position=w.LOWER_ASSEMBLY_SHIFT
	var guard:Array[Vector3]=[Vector3(0,-.018,-.168),Vector3(0,-.066,-.175),Vector3(0,-.066,-.225),Vector3(0,-.018,-.233)]
	for i in guard.size()-1:w._rod(guard[i],guard[i+1],.0032,dark,10,trigger_guard)
	w._rod(Vector3(0,-.020,-.195),Vector3(0,-.047,-.203),.0025,metal,10,trigger_guard)
	_batch(trigger_guard);_batch(grip_detail)
	# Match offered/held magazine appearance to the seated pistol magazine without
	# moving or scaling any existing reload target or moving node.
	var size:=Vector3(.0329,.11625,.0504)
	var shape=w._beveled(size,Vector3.ZERO,dark,.005,root);w.loose_magazine.mesh=shape.mesh;shape.free()
	for child in w.loose_magazine.get_children():
		if child is MeshInstance3D:child.hide()
	for child in w.hip_source.get_children():
		if child is MeshInstance3D:child.hide()
	var offered_body=w._beveled(size,Vector3.ZERO,dark,.005,w.hip_source)
	offered_body.set_meta("original_remaining_detail064",true)
	_magazine_skin(w,w.magazine,Vector3(.047,.155,.072),metal,dark)
	_magazine_skin(w,w.loose_magazine,size,metal,dark);_magazine_skin(w,w.hip_source,size,metal,dark)
	_batch(root)

