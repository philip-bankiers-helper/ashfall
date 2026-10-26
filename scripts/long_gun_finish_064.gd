extends RefCounted
## Original visual manufacture only. Film constrains visible feature families,
## not physical dimensions. Existing shot/reload/optic APIs remain untouched.
const Finish = preload("res://scripts/weapon_finish.gd")
static func material(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := Finish.finish(color,metal,rough)
	m.uv1_triplanar = true; m.uv1_scale = Vector3(17,17,17)
	return m
static func group(parent: Node3D, label: String) -> Node3D:
	var node := Node3D.new(); node.name = label
	node.set_meta("original_long_gun_detail_064",true)
	node.set_meta("dimension_provenance","authored SI dimensions within existing weapon envelope; not reconstructed from film pixels")
	parent.add_child(node); return node
static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	# Godot's front face is CLOCKWISE. Keep the outward conventional normal,
	# reverse emitted winding: normal.dot(-cross(emitted edges)) must be positive.
	for v in [a,c,b,a,d,c]: surface.set_normal(normal); surface.add_vertex(v)
static func loft(parent: Node3D, label: String, stations: Array, m: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	# Each station is [z, full width, full height, centre y].
	for s in stations:
		var x: float = s[1]*.5; var y: float = s[2]*.5; var bevel := minf(x,y)*.32
		var ring := PackedVector3Array()
		for p in [Vector2(-x+bevel,-y),Vector2(x-bevel,-y),Vector2(x,-y+bevel),Vector2(x,y-bevel),Vector2(x-bevel,y),Vector2(-x+bevel,y),Vector2(-x,y-bevel),Vector2(-x,-y+bevel)]: ring.append(Vector3(p.x,p.y+s[3],s[0]))
		rings.append(ring)
	for n in rings.size()-1:
		for i in 8: quad(surface,rings[n][i],rings[n][(i+1)%8],rings[n+1][(i+1)%8],rings[n+1][i])
	for i in 8:
		for triangle in [[Vector3(0,stations[0][3],stations[0][0]),rings[0][(i+1)%8],rings[0][i]],[Vector3(0,stations[-1][3],stations[-1][0]),rings[-1][i],rings[-1][(i+1)%8]]]:
			var normal: Vector3 = (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
			for v in [triangle[0],triangle[2],triangle[1]]: surface.set_normal(normal); surface.add_vertex(v)
	surface.index()
	var mesh := MeshInstance3D.new(); mesh.name = label; mesh.mesh = surface.commit(); mesh.material_override = m
	parent.add_child(mesh); return mesh
static func ring(parent: Node3D, label: String, at: Vector3, inner: float, outer: float, m: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new(); mesh.name = label
	var shape := TorusMesh.new(); shape.inner_radius = inner; shape.outer_radius = outer; shape.rings = 32; shape.ring_segments = 8
	mesh.mesh = shape; mesh.position = at; mesh.rotation.x = PI*.5; mesh.material_override = m; parent.add_child(mesh); return mesh
static func batch(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for child in parent.get_children():
		if child is MeshInstance3D and child.mesh != null and child.get_child_count() == 0 and not child.get_meta("real_through_aperture",false):
			if not groups.has(child.material_override): groups[child.material_override] = []
			groups[child.material_override].append(child)
	for m in groups:
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[m]:
			for index in part.mesh.get_surface_count(): surface.append_from(part.mesh,index,part.transform)
			part.free()
		var mesh := MeshInstance3D.new(); mesh.name = "BatchedOriginalManufacture"
		mesh.mesh = surface.commit(); mesh.material_override = m; parent.add_child(mesh)
static func fastener(w, parent: Node3D, at: Vector3, steel: Material, dark: Material) -> void:
	var side := signf(at.x)
	w._rod(at,at+Vector3(side*.002,0,0),.0033,steel,10,parent)
	w._box(Vector3(.001,.0014,.0044),at+Vector3(side*.0024,0,0),dark,parent)
static func hide_primitive(w, at: Vector3, size: Vector3) -> void:
	for part in w.model.get_children():
		if part is MeshInstance3D and part.mesh != null and part.position.is_equal_approx(at) and part.mesh.get_aabb().size.is_equal_approx(size):
			part.hide(); part.set_meta("replaced_only_by_original_visual_064",true)
static func magazine_detail(w, parent: Node3D, label: String, size: Vector3, steel: Material, dark: Material) -> Node3D:
	var root := group(parent,label)
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.0018,size.y*.68,size.z*.72),Vector3(side*(size.x*.5+.0007),0,0),steel,.0005,root)
		for i in 3: w._box(Vector3(.0022,size.y*.62,.0018),Vector3(side*(size.x*.5+.0017),0,-size.z*.25+i*size.z*.25),dark,root)
	w._beveled(Vector3(size.x+.004,.008,size.z+.004),Vector3(0,-size.y*.5+.003,0),dark,.002,root)
	batch(root); return root
static func awp(w) -> void:
	var steel := material(Color("465159"),.84,.34); var edge := material(Color("8b938d"),.8,.29)
	var dark := material(Color("172126"),.4,.48); var polymer := material(Color("4c5a50"),.04,.73)
	var rubber := material(Color("292d2b"),.01,.84)
	var root := group(w.model,"AWPOriginalChassis064")
	# Replace only the existing coarse stock/fore-end skins, retaining action,
	# bore, all references, bolt root, magazine root, arrows and chamber window.
	hide_primitive(w,Vector3(0,-.022,-.43),Vector3(.068,.075,.35))
	hide_primitive(w,Vector3(0,-.045,.13),Vector3(.065,.10,.21))
	hide_primitive(w,Vector3(0,-.045,.246),Vector3(.08,.12,.025))
	hide_primitive(w,Vector3(0,.024,.13),Vector3(.064,.032,.125))
	loft(root,"TaperedPrecisionForeEnd",[[-.605,.046,.055,-.022],[-.56,.066,.073,-.022],[-.31,.069,.075,-.022],[-.255,.056,.066,-.022]],polymer)
	loft(root,"SculptedPrecisionStock",[[.025,.043,.064,-.035],[.065,.058,.078,-.046],[.20,.071,.106,-.043],[.239,.070,.111,-.043]],polymer)
	loft(root,"TexturedButtPad",[[.235,.073,.115,-.043],[.255,.078,.119,-.043],[.261,.067,.106,-.043]],rubber)
	loft(root,"SeparateCheekRiser",[[.068,.050,.021,.026],[.105,.061,.029,.027],[.202,.058,.026,.027]],dark)
	for side in [-1.0,1.0]:
		for z in [-.53,-.47,-.41,-.35]: w._beveled(Vector3(.002,.014,.031),Vector3(side*.034,-.018,z),dark,.002,root)
		for z in [.087,.20]: fastener(w,root,Vector3(side*.037,-.047,z),edge,dark)
		w._beveled(Vector3(.002,.006,.13),Vector3(side*.036,-.024,.14),steel,.001,root)
		w._rod(Vector3(side*.024,.012,.12),Vector3(side*.024,.022,.12),.0035,edge,8,root)
		for z in [-.235,-.08]: fastener(w,root,Vector3(side*.036,.022,z),edge,dark)
	for i in 6: w._box(Vector3(.075,.002,.002),Vector3(0,-.083+i*.016,.2615),dark,root)
	# Supports remain below the existing .151m optic axis; annuli add no disk.
	var mounts := group(root,"AWPExternalScopeSupports064")
	for z in [-.035,-.245]:
		w._beveled(Vector3(.052,.011,.045),Vector3(0,.081,z),dark,.002,mounts)
		for side in [-1.0,1.0]:
			w._box(Vector3(.007,.021,.038),Vector3(side*.025,.094,z),steel,mounts)
			fastener(w,mounts,Vector3(side*.030,.095,z),edge,dark)
		ring(mounts,"OpenScopeClamp",Vector3(0,.151,z),.0258,.029,steel)
	# Genuine moving hardware detail belongs under the unchanged bolt handle.
	var bolt := group(w.bolt_handle,"AWPMovingBoltManufacture064")
	for angle in range(10):
		var a := TAU*angle/10.0
		w._rod(Vector3(.022+cos(a)*.015,-.025+sin(a)*.015,-.007),Vector3(.022+cos(a)*.015,-.025+sin(a)*.015,.007),.0012,steel,6,bolt)
	ring(bolt,"BoltKnobEndRim",Vector3(.022,-.025,.009),.009,.013,edge)
	for child in w.magazine.get_children(): child.hide()
	magazine_detail(w,w.magazine,"AWPSeatedMagazine064",Vector3(.050,.095,.090),steel,dark)
	magazine_detail(w,w.loose_magazine,"AWPHeldMagazine064",Vector3(.050,.095,.090),steel,dark)
	# Keep the offer's owning node and pose; use the same short magazine shell.
	for child in w.hip_source.get_children(): child.hide()
	var offer := group(w.hip_source,"AWPOfferedMagazine064")
	w._beveled(Vector3(.050,.095,.090),Vector3.ZERO,dark,.006,offer)
	magazine_detail(w,offer,"AWPOfferedMagazineSkin064",Vector3(.050,.095,.090),steel,dark)
	batch(root); batch(mounts); batch(bolt); batch(offer)
static func spr(w) -> void:
	var steel := material(Color("626d70"),.8,.34); var edge := material(Color("a3a69a"),.78,.29)
	var dark := material(Color("172227"),.42,.48); var stock := material(Color("7d7763"),.03,.73)
	var rubber := material(Color("2b302d"),.01,.84)
	# SPR had no local builder. Preserve every inherited mechanism/reference;
	# only anonymous generic rifle skins give way to this SPR-specific chassis.
	var keep := [w.magazine,w.bolt,w.firing_carrier,w.guide,w.muzzle_flash,w.ammo_label,w.insertion_arrow,w.charging_arrow,w.sight_rear.get_parent()]
	for child in w.model.get_children():
		if child not in keep: child.hide()
	var root := group(w.model,"SPROriginalChassis064")
	loft(root,"PrecisionReceiver",[[-.28,.057,.073,.029],[-.23,.076,.082,.029],[-.045,.073,.082,.029],[.03,.052,.072,.022]],steel)
	loft(root,"TaperedSPRMuzzleForeEnd",[[-.58,.047,.060,.012],[-.53,.065,.078,.009],[-.29,.068,.081,.009],[-.25,.059,.072,.009]],stock)
	loft(root,"LongThumbRestStock",[[.015,.045,.072,-.043],[.068,.061,.086,-.048],[.22,.068,.112,-.043],[.25,.065,.112,-.043]],stock)
	loft(root,"SPRButtPad",[[.244,.070,.114,-.043],[.265,.071,.115,-.043]],rubber)
	loft(root,"SPRGrip",[[-.02,.045,.118,-.076],[.026,.048,.122,-.079],[.047,.039,.103,-.079]],rubber)
	w._rod(Vector3(0,.045,-.27),Vector3(0,.045,-.69),.0115,steel,16,root)
	for side in [-1.0,1.0]:
		for z in [-.49,-.43,-.37]:
			w._beveled(Vector3(.002,.016,.030),Vector3(side*.034,.025,z),dark,.002,root)
		for z in [-.22,-.06,.17]: fastener(w,root,Vector3(side*.039,.011,z),edge,dark)
		w._beveled(Vector3(.003,.016,.19),Vector3(side*.034,-.020,-.15),dark,.001,root)
		for i in 6: w._box(Vector3(.002,.002,.045),Vector3(side*.025,-.122+i*.014,.006),steel,root)
	for i in 7: w._box(Vector3(.071,.002,.002),Vector3(0,-.082+i*.014,.266),dark,root)
	w._rod(Vector3(0,-.027,-.022),Vector3(0,-.095,-.040),.0035,dark,8,root)
	w._rod(Vector3(0,-.095,-.040),Vector3(0,-.095,-.107),.0035,dark,8,root)
	w._rod(Vector3(0,-.095,-.107),Vector3(0,-.030,-.114),.0035,dark,8,root)
	# Open rectangular hood/supports stay outside unchanged .11 x .065 lens.
	var hood := group(root,"SPROpenOpticHood064")
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.007,.081,.095),Vector3(side*.067,.151,.018),dark,.002,hood)
		w._beveled(Vector3(.010,.030,.039),Vector3(side*.024,.099,-.035),steel,.002,hood)
	w._beveled(Vector3(.132,.008,.097),Vector3(0,.195,.018),dark,.002,hood)
	w._beveled(Vector3(.126,.008,.073),Vector3(0,.107,.017),dark,.002,hood)
	for x in [-.020,0.0,.020]: w._beveled(Vector3(.012,.003,.012),Vector3(x,.201,.012),steel,.001,hood)
	var handle := group(w.bolt,"SPRMovingChargingHandle064")
	for i in 5: w._box(Vector3(.034,.0015,.0018),Vector3(0,.0065,-.008+i*.004),dark,handle)
	var carrier := group(w.firing_carrier,"SPRMovingCarrierDetail064")
	w._box(Vector3(.0007,.003,.029),Vector3(.0012,0,0),dark,carrier)
	magazine_detail(w,w.magazine,"SPRSeatedMagazine064",Vector3(.047,.155,.072),steel,dark)
	magazine_detail(w,w.loose_magazine,"SPRHeldMagazine064",Vector3(.047,.155,.072),steel,dark)
	magazine_detail(w,w.hip_source,"SPROfferedMagazine064",Vector3(.047,.155,.072),steel,dark)
	batch(root); batch(hood); batch(handle); batch(carrier)
static func p90_frame(parent: Node3D, m: Material) -> void:
	# Authored compact bullpup stock: long upper edge, clipped forward heel,
	# short flat butt and planar chamfers. Film crops this hidden profile;
	# these are original choices, not recovered reference dimensions.
	# Keep the exact prior envelope and the ORIGINAL 32-sided thumb hole.
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2(.095,-.060) # (z,y)
	var profile := PackedVector2Array([Vector2(.205,-.074),Vector2(.205,.037),Vector2(.178,.062),Vector2(-.055,.080),Vector2(-.095,.055),Vector2(-.095,.021),Vector2(-.055,-.002),Vector2(-.033,-.104),Vector2(-.015,-.130),Vector2(.025,-.130),Vector2(.177,-.099)])
	var aperture := PackedVector2Array()
	var angles: Array[float] = []
	for i in 32:
		var angle := TAU*i/32.0
		aperture.append(center+Vector2(cos(angle)*.044,sin(angle)*.031))
	# Include every corner of BOTH loops. Added inner points are collinear on
	# the old aperture edges, so its physical boundary stays unchanged.
	for loop in [profile,aperture]:
		for point in loop:
			var offset: Vector2 = point-center
			angles.append(fposmod(atan2(offset.y,offset.x),TAU))
	angles.sort()
	var boundary := func(loop: PackedVector2Array, angle: float) -> Vector2:
		var end := center+Vector2(cos(angle),sin(angle))
		var nearest := end; var distance := 1.0
		for i in loop.size():
			var hit = Geometry2D.segment_intersects_segment(center,end,loop[i],loop[(i+1)%loop.size()])
			if hit != null and center.distance_squared_to(hit)<distance:
				nearest=hit;distance=center.distance_squared_to(hit)
		return nearest
	var outer: PackedVector3Array = []; var inner: PackedVector3Array = []
	for angle in angles:
		var a: Vector2 = boundary.call(profile,angle);var b: Vector2 = boundary.call(aperture,angle)
		outer.append(Vector3(0,a.y,a.x));inner.append(Vector3(0,b.y,b.x))
	for i in outer.size():
		var j := (i+1)%outer.size()
		var a := outer[i]; var b := outer[j]; var c := inner[j]; var d := inner[i]
		for side in [-1.0,1.0]:
			var x := Vector3(side*.043,0,0)
			if side>0: quad(surface,d+x,c+x,b+x,a+x)
			else: quad(surface,a+x,b+x,c+x,d+x)
		quad(surface,a+Vector3(.043,0,0),b+Vector3(.043,0,0),b-Vector3(.043,0,0),a-Vector3(.043,0,0))
		quad(surface,d-Vector3(.043,0,0),c-Vector3(.043,0,0),c+Vector3(.043,0,0),d+Vector3(.043,0,0))
	surface.index();var mesh := MeshInstance3D.new();mesh.name = "ThroughApertureBullpupFrame";mesh.mesh = surface.commit();mesh.material_override = m;parent.add_child(mesh)
	mesh.set_meta("thumb_aperture_center",Vector3(0,-.060,.095)); mesh.set_meta("real_through_aperture",true)
static func p90_magazine(w, parent: Node3D, label: String, steel: Material, dark: Material) -> void:
	var root := group(parent,label)
	for side in [-1.0,1.0]:
		w._beveled(Vector3(.002,.015,.207),Vector3(side*.042,0,0),steel,.001,root)
		for z in [-.087,-.044,0.0,.044,.087]: w._box(Vector3(.003,.018,.002),Vector3(side*.0432,0,z),dark,root)
	for z in [-.107,.106]: w._beveled(Vector3(.074,.004,.009),Vector3(0,.019,z),dark,.001,root)
	for x in [-.025,.025]: w._box(Vector3(.003,.002,.19),Vector3(x,.0195,0),steel,root)
	batch(root)
static func p90(w) -> void:
	var steel := material(Color("646d67"),.78,.35); var edge := material(Color("a19f84"),.7,.31)
	var dark := material(Color("222a2c"),.38,.54); var polymer := material(Color("5d6250"),.04,.76)
	var root := group(w.model,"P90OriginalBullpupChassis064")
	p90_frame(root,polymer)
	loft(root,"LowBroadReceiverSaddle",[[-.33,.075,.045,.055],[-.28,.088,.052,.055],[-.070,.088,.050,.055],[-.03,.074,.042,.055]],polymer)
	for side in [-1.0,1.0]:
		for z in [-.265,-.205,-.145]: fastener(w,root,Vector3(side*.045,.035,z),edge,dark)
		for z in [-.28,-.23,-.18]: w._beveled(Vector3(.002,.018,.025),Vector3(side*.045,.060,z),dark,.0015,root)
		w._beveled(Vector3(.003,.018,.095),Vector3(side*.045,-.025,.082),steel,.002,root)
	for i in 6: w._box(Vector3(.074,.002,.003),Vector3(0,-.099+i*.024,.205),dark,root)
	var handle := group(w.bolt,"P90MovingChargeGrip064")
	for i in 5: w._box(Vector3(.033,.0015,.0017),Vector3(0,.0065,-.008+i*.004),dark,handle)
	p90_magazine(w,w.magazine,"P90SeatedTopMagazine064",steel,dark)
	p90_magazine(w,w.loose_magazine,"P90HeldTopMagazine064",steel,dark)
	p90_magazine(w,w.hip_source,"P90OfferedTopMagazine064",steel,dark)
	batch(root); batch(handle)
