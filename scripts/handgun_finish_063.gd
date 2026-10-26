extends RefCounted
## Original 063 manufacture detail. All added nodes are visual and have no input.
## Keep movable detail below its real cylinder, round, magazine, bolt or carrier.
static func _root(parent:Node3D,label:String)->Node3D:
	var root:=Node3D.new();root.name=label;parent.add_child(root);return root
static func _ring(parent:Node3D,position:Vector3,inner:float,outer:float,finish:Material)->void:
	var part:=MeshInstance3D.new();var shape:=TorusMesh.new();shape.inner_radius=inner;shape.outer_radius=outer;shape.rings=24;shape.ring_segments=8
	part.mesh=shape;part.material_override=finish;part.position=position;part.rotation.x=PI*.5;parent.add_child(part)
static func _batch(root:Node3D,excluded:Array=[])->void:
	var groups:Dictionary={}
	for child in root.get_children():
		if child is MeshInstance3D and child not in excluded:
			if not groups.has(child.material_override):groups[child.material_override]=[]
			groups[child.material_override].append(child)
	for finish in groups:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[finish]:
			for index in part.mesh.get_surface_count():surface.append_from(part.mesh,index,part.transform)
			part.free()
		var merged:=MeshInstance3D.new();merged.name="BatchedVisualFinish";merged.mesh=surface.commit();merged.material_override=finish;root.add_child(merged)

static func magnum(gun)->void:
	var steel=gun._material(Color("65727a"),.82,.34)
	var edge=gun._material(Color("8c9698"),.86,.29)
	var recess=gun._material(Color("20272b"),.36,.57)
	var panel=gun._material(Color("493c32"),.08,.74)
	var brass=gun._material(Color("ad8545"),.78,.38)
	var body:=_root(gun.model,"OriginalMagnumFrameDetail063")
	# Long rib and underlug retain the original bore and front/rear sight zero.
	gun._beveled(Vector3(.030,.009,.195),Vector3(0,.0875,-.274),steel,.003,body)
	gun._beveled(Vector3(.033,.021,.175),Vector3(0,.037,-.275),steel,.004,body)
	for side in [-1.0,1.0]:
		gun._beveled(Vector3(.0015,.008,.125),Vector3(side*.017,.037,-.277),recess,.0003,body)
		gun._beveled(Vector3(.003,.099,.052),Vector3(side*.026,-.046,-.065),panel,.001,body)
		for row in 6:gun._box(Vector3(.0015,.002,.043),Vector3(side*.0276,-.084+row*.014,-.065),recess,body)
		for y in [-.079,-.014]:
			gun._rod(Vector3(side*.027,y,-.065),Vector3(side*.029,y,-.065),.003,edge,8,body)
	# Open trigger bow, rear hammer spur and understated side plate fasteners.
	var bow:Array[Vector3]=[Vector3(0,-.006,-.116),Vector3(0,-.044,-.131),Vector3(0,-.067,-.112),Vector3(0,-.068,-.058)]
	for i in range(1,bow.size()):gun._rod(bow[i-1],bow[i],.0035,recess,8,body)
	gun._rod(Vector3(0,-.012,-.101),Vector3(0,-.042,-.108),.0025,edge,8,body)
	gun._beveled(Vector3(.022,.018,.025),Vector3(0,.091,.003),recess,.004,body)
	for z in [-.003,.005,.013]:gun._box(Vector3(.024,.002,.002),Vector3(0,.101,z),steel,body)
	for side in [-1.0,1.0]:
		gun._beveled(Vector3(.002,.022,.033),Vector3(side*.0248,.040,-.021),recess,.0005,body)
		gun._rod(Vector3(side*.025,.028,-.022),Vector3(side*.027,.028,-.022),.0028,edge,8,body)
	_ring(body,Vector3(0,.065,-.3905),.0125,.0195,edge)
	_batch(body)
	var drum:=_root(gun.cylinder,"OriginalMagnumCylinderDetail063")
	for z in [-.153,-.066]:_ring(drum,Vector3(0,.035,z),.040,.0445,edge)
	for index in gun.CAPACITY:
		var angle:float=TAU*index/gun.CAPACITY
		var flute=gun._beveled(Vector3(.010,.0015,.057),Vector3(cos(angle)*.043,.035+sin(angle)*.043,-.110),recess,.0004,drum)
		flute.rotation.z=angle-PI*.5
		var p:=Vector3(cos(angle)*.027,sin(angle)*.027,0)
		var cartridge:MeshInstance3D=gun.cartridges[index]
		var primer:=_root(cartridge,"LiveRoundPrimer063")
		# Rod axis is local Y; the original cartridge node supplies its Z alignment.
		gun._rod(Vector3(0,.0035,0),Vector3(0,.0040,0),.003,brass,8,primer)
		var offered:=_root(gun.offered_rounds[index],"OfferedCaseRim063")
		_ring(offered,p+Vector3(0,0,-.002),.008,.010,brass)
		_ring(offered,p+Vector3(0,0,-.037),.008,.0093,recess)
		_batch(offered)
	_batch(drum)
	# Original chamber recesses are static, while live round nodes stay separate.
	_batch(gun.cylinder,gun.cartridges)

static func uzi(gun)->void:
	var metal=gun._material(Color("505e63"),.75,.39)
	var edge=gun._material(Color("778186"),.8,.34)
	var dark=gun._material(Color("192326"),.3,.61)
	var rubber=gun._material(Color("2a3330"),.02,.82)
	var body:=_root(gun.model,"OriginalUziReceiverDetail063")
	# Stamped cover ribs and seam breaks, with a clear line through existing sights.
	gun._beveled(Vector3(.061,.006,.245),Vector3(0,.0865,-.104),metal,.0015,body)
	for side in [-1.0,1.0]:
		gun._beveled(Vector3(.005,.004,.210),Vector3(side*.025,.091,-.108),edge,.001,body)
		gun._box(Vector3(.0015,.003,.235),Vector3(side*.0338,.063,-.102),dark,body)
		for z in [-.019,-.21]:gun._rod(Vector3(side*.0337,.028,z),Vector3(side*.0353,.028,z),.0032,edge,8,body)
		# Rear protective wings are cosmetic; aiming references stay in place.
		gun._rod(Vector3(side*.020,.094,-.030),Vector3(side*.020,.123,-.030),.0026,metal,8,body)
		gun._rod(Vector3(side*.020,.123,-.030),Vector3(side*.013,.128,-.030),.0026,edge,8,body)
		gun._rod(Vector3(side*.019,.094,-.360),Vector3(side*.019,.120,-.360),.0022,metal,8,body)
		# The existing open stock remains; reinforce its hinges and pressed edges.
		gun._rod(Vector3(side*.029,.031,.028),Vector3(side*.034,.031,.028),.010,metal,12,body)
		gun._box(Vector3(.004,.006,.108),Vector3(side*.025,.025,.094),metal,body)
		for row in 5:gun._box(Vector3(.0015,.002,.037),Vector3(side*.0225,-.114+row*.014,.005),dark,body)
	gun._box(Vector3(.054,.003,.040),Vector3(0,-.0315,-.367),rubber,body)
	_batch(body)
	var mag:=_root(gun.magazine,"OriginalUziMagazineDetail063")
	gun._beveled(Vector3(.041,.008,.049),Vector3(0,-.094,0),metal,.002,mag)
	for y in [-.025,-.052,-.077]:gun._box(Vector3(.005,.007,.0015),Vector3(0,y,.0222),dark,mag)
	_batch(mag)
	var charge:=_root(gun.bolt,"OriginalUziChargingDetail063")
	for x in [-.011,-.004,.003,.010]:gun._box(Vector3(.002,.002,.016),Vector3(x,.0068,0),dark,charge)
	_batch(charge)
	var carrier:=_root(gun.firing_carrier,"OriginalUziCarrierDetail063")
	gun._box(Vector3(.001,.003,.033),Vector3(.0015,.003,0),edge,carrier)
	_batch(carrier)
