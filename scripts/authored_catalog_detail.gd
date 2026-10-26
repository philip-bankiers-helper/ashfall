extends RefCounted
## Original ASHFALL manufacture detail. Film supplies visible construction cues;
## dimensions and finish design are authored, not measured reference-game assets.
static func build(gun:Node3D,steel:Material,dark:Material,accent:Material)->Node3D:
	var assembly:=Node3D.new();assembly.name="AuthoredCatalogChassis";gun.model.add_child(assembly)
	var recess:Material=gun._material(Color("10191e"),.1,.8)
	var edge:Material=gun._material(Color("78858a"),.65,.38)
	var rubber:Material=gun._material(Color("20272a"),.05,.9)
	var length:float=gun.barrel_length
	# Layered upper receiver and visible side seams, kept below the aiming corridor.
	box(gun,assembly,Vector3(.071,.025,length*.56),Vector3(0,.071,-length*.31),dark)
	if gun.profile_id not in ["mp9","1911","tec9"]:
		# Join the receiver to the seated magazine without a floating visual gap.
		box(gun,assembly,Vector3(.065,.034,length*.50),Vector3(0,-.020,-length*.30),dark,.005)
		var well_z:float=.14 if gun.profile_id=="rfb" else -.15
		for side in [-1.0,1.0]:
			box(gun,assembly,Vector3(.004,.025,.087),Vector3(side*.0245,-.045,well_z),steel,.001)
			box(gun,assembly,Vector3(.045,.025,.004),Vector3(0,-.045,well_z+side*.0415),steel,.001)
	for side in [-1.0,1.0]:
		box(gun,assembly,Vector3(.003,.017,length*.40),Vector3(side*.034,.037,-length*.30),accent)
		box(gun,assembly,Vector3(.002,.003,length*.39),Vector3(side*.036,.052,-length*.30),recess,.0005)
		for z in [-.07,-.21]:rod(gun,assembly,Vector3(side*.034,.036,z),Vector3(side*.038,.036,z),.003,edge,8)
	# A finite rail with separate teeth makes a readable profile at hand distance.
	var rail_teeth:=0 if gun.profile_id=="1911" else (5 if gun.profile_id in ["mp9","tec9"] else 7)
	for i in range(rail_teeth):box(gun,assembly,Vector3(.037,.004,.008),Vector3(0,.086,-.08-i*.028),steel,.001)
	box(gun,assembly,Vector3(.003,.019,.069),Vector3(.037,.037,-.113),recess,.001)
	box(gun,assembly,Vector3(.004,.010,.040),Vector3(.039,.037,-.103),steel,.001)
	# Trigger guard is a genuinely open frame, rather than a solid block.
	# Keep trigger/guard in front of the relocated grip, rather than burying the
	# old trigger inside it. All offsets are visual and leave shot/mag datums intact.
	var guard:=Node3D.new();guard.name="CatalogTrigger076";assembly.add_child(guard)
	guard.position.z=-.065 if gun.profile_id in ["mp5","mp9"] else (-.060 if gun.profile_id in ["1911","tec9"] else 0.0)
	rod(gun,guard,Vector3(-.021,-.029,-.075),Vector3(-.021,-.080,-.075),.003,dark,8)
	rod(gun,guard,Vector3(-.021,-.080,-.075),Vector3(-.021,-.082,.006),.003,dark,8)
	rod(gun,guard,Vector3(.021,-.029,-.075),Vector3(.021,-.080,-.075),.003,dark,8)
	rod(gun,guard,Vector3(.021,-.080,-.075),Vector3(.021,-.082,.006),.003,dark,8)
	rod(gun,guard,Vector3(0,-.035,-.031),Vector3(0,-.066,-.043),.003,steel,8)
	batch(guard)
	for mesh in guard.get_children():
		var at:Transform3D=guard.transform*mesh.transform;mesh.reparent(assembly,false);mesh.transform=at
	guard.free()
	match gun.profile_id:
		"mp5":
			# Round receiver shoulders and a separate fore-end/skeletal butt frame.
			rod(gun,assembly,Vector3(0,.041,-.060),Vector3(0,.041,-.310),.038,steel,16)
			box(gun,assembly,Vector3(.072,.063,.158),Vector3(0,.006,-.350),accent,.012)
			for side in [-1.0,1.0]:
				rod(gun,assembly,Vector3(side*.024,.004,.063),Vector3(side*.024,.004,.224),.005,steel)
				for i in range(6):box(gun,assembly,Vector3(.002,.038,.006),Vector3(side*.0365,.007,-.410+i*.023),recess,.001)
			box(gun,assembly,Vector3(.063,.107,.027),Vector3(0,-.032,.239),rubber,.007)
			box(gun,assembly,Vector3(.045,.018,.099),Vector3(0,.025,.174),dark,.005)
			assembly.set_meta("film_reference_seconds",[450.00668])
		"mp9":
			# Compact molded shell, inset side controls and a distinct suppressor collar.
			box(gun,assembly,Vector3(.074,.059,.188),Vector3(0,.014,-.113),accent,.012)
			for side in [-1.0,1.0]:
				box(gun,assembly,Vector3(.002,.016,.080),Vector3(side*.0375,.023,-.130),dark,.002)
				for i in range(4):box(gun,assembly,Vector3(.002,.028,.005),Vector3(side*.032,-.075+i*.016,-.039),recess,.001)
			box(gun,assembly,Vector3(.034,.062,.044),Vector3(0,-.033,-.252),rubber,.006)
			rod(gun,assembly,Vector3(0,.045,-.280),Vector3(0,.045,-.302),.030,steel,16)
			for z in [-.321,-.353,-.385]:rod(gun,assembly,Vector3(0,.045,z-.004),Vector3(0,.045,z+.004),.0267,dark,16)
			assembly.set_meta("film_reference_seconds",[496.00312])
		"1911":
			# Separate slide shoulders, ejection recess, hammer and fitted grip panels.
			box(gun,assembly,Vector3(.059,.046,.240),Vector3(0,.059,-.112),accent,.006)
			box(gun,assembly,Vector3(.003,.017,.040),Vector3(.030,.065,-.112),recess,.001)
			box(gun,assembly,Vector3(.003,.011,.032),Vector3(.031,.066,-.108),edge,.001)
			box(gun,assembly,Vector3(.011,.017,.012),Vector3(0,.079,.020),dark,.003)
			for side in [-1.0,1.0]:
				for i in range(6):box(gun,assembly,Vector3(.002,.026,.002),Vector3(side*.030,.058,-.044+i*.007),recess,.0005)
				box(gun,assembly,Vector3(.003,.085,.048),Vector3(side*.027,-.071,-.035),rubber,.005)
				for y in [-.045,-.098]:rod(gun,assembly,Vector3(side*.028,y,-.035),Vector3(side*.031,y,-.035),.003,edge,8)
			assembly.set_meta("film_reference_seconds",[278.00613])
		"tec9":
			# Cylindrical upper/shroud with recessed vent rows, separate collar and grip.
			rod(gun,assembly,Vector3(0,.045,-.040),Vector3(0,.045,-.326),.033,steel,16)
			rod(gun,assembly,Vector3(0,.045,-.321),Vector3(0,.045,-.344),.036,dark,16)
			for side in [-1.0,1.0]:
				for i in range(5):
					rod(gun,assembly,Vector3(side*.032,.048,-.180-i*.029),Vector3(side*.034,.048,-.180-i*.029),.008,recess,12)
				box(gun,assembly,Vector3(.003,.067,.039),Vector3(side*.027,-.072,-.035),rubber,.005)
			assembly.set_meta("film_reference_seconds",[320.00285])
		"rfb":
			# Bullpup cheek/shoulder above the actual rear magazine well; no forward well.
			stock(assembly,.062,.052,.002,-.001,.076,.063,.002,.243,accent)
			box(gun,assembly,Vector3(.059,.017,.142),Vector3(0,.044,.145),dark,.005)
			box(gun,assembly,Vector3(.079,.119,.024),Vector3(0,-.024,.254),rubber,.007)
			box(gun,assembly,Vector3(.072,.054,.174),Vector3(0,-.001,-.338),accent,.009)
			for side in [-1.0,1.0]:
				for i in range(5):box(gun,assembly,Vector3(.002,.018,.022),Vector3(side*.0365,.014,-.405+i*.031),recess,.002)
				box(gun,assembly,Vector3(.002,.004,.115),Vector3(side*.0385,.017,.116),recess,.0005)
			assembly.set_meta("film_reference_seconds",[246.00865])
		"fal":
			# Long fore-end, gas tube and a stepped cheek/shoulder silhouette.
			stock(assembly,.044,.048,-.012,.028,.060,.086,-.030,.244,accent)
			box(gun,assembly,Vector3(.062,.112,.026),Vector3(0,-.032,.255),rubber,.006)
			box(gun,assembly,Vector3(.069,.060,.230),Vector3(0,-.002,-.367),accent,.011)
			rod(gun,assembly,Vector3(0,.071,-.275),Vector3(0,.071,-.536),.010,steel)
			rod(gun,assembly,Vector3(0,.045,-.558),Vector3(0,.071,-.524),.013,dark)
			for side in [-1.0,1.0]:
				for i in range(6):box(gun,assembly,Vector3(.002,.014,.021),Vector3(side*.035,.019,-.456+i*.034),recess,.002)
			assembly.set_meta("film_reference_seconds",[173.00045])
		"cx4":
			# Compact molded chassis with a real thumb opening and cheek shoulder.
			box(gun,assembly,Vector3(.067,.050,.20),Vector3(0,.010,.135),accent,.012)
			box(gun,assembly,Vector3(.059,.028,.145),Vector3(0,-.090,.150),accent,.009)
			box(gun,assembly,Vector3(.068,.138,.033),Vector3(0,-.037,.235),rubber,.009)
			box(gun,assembly,Vector3(.051,.016,.108),Vector3(0,.043,.156),dark,.005)
			box(gun,assembly,Vector3(.072,.070,.185),Vector3(0,.009,-.329),accent,.012)
			for side in [-1.0,1.0]:
				for i in range(6):box(gun,assembly,Vector3(.002,.030,.010),Vector3(side*.0365,.018,-.398+i*.022),recess,.001)
				box(gun,assembly,Vector3(.002,.006,.125),Vector3(side*.035,.051,-.327),edge,.001)
			assembly.set_meta("film_reference_seconds",[99.006,104.006,120.004])
		"akm":
			# Long separated gas tube, sloped fore-end and a narrow shoulder stock.
			stock(assembly,.044,.041,-.016,.028,.058,.078,-.032,.243,accent)
			box(gun,assembly,Vector3(.061,.103,.022),Vector3(0,-.038,.252),rubber,.005)
			box(gun,assembly,Vector3(.068,.055,.185),Vector3(0,.005,-.365),accent,.010)
			rod(gun,assembly,Vector3(0,.075,-.285),Vector3(0,.075,-.492),.009,steel)
			rod(gun,assembly,Vector3(0,.045,-.515),Vector3(0,.075,-.483),.012,steel)
			for side in [-1.0,1.0]:
				for i in range(4):box(gun,assembly,Vector3(.002,.011,.023),Vector3(side*.0345,.026,-.420+i*.036),recess,.002)
			assembly.set_meta("film_reference_seconds",[20.97,49.01])
		"s85":
			# Raised cheek, long faceted fore-end, discrete receiver collar and bolt.
			stock(assembly,.044,.050,-.015,.028,.064,.084,-.030,.242,accent)
			box(gun,assembly,Vector3(.052,.020,.115),Vector3(0,.019,.164),dark,.006)
			box(gun,assembly,Vector3(.067,.108,.024),Vector3(0,-.033,.252),rubber,.005)
			box(gun,assembly,Vector3(.064,.049,.255),Vector3(0,-.004,-.386),accent,.010)
			rod(gun,assembly,Vector3(0,.045,-.25),Vector3(0,.045,-.29),.021,steel)
			for side in [-1.0,1.0]:
				for i in range(5):box(gun,assembly,Vector3(.002,.010,.024),Vector3(side*.0325,.014,-.479+i*.039),recess,.002)
			assembly.set_meta("film_reference_seconds",[669.0,674.0,694.0])
	# Muzzle collars and a dark bore leave the production shot origin unchanged.
	rod(gun,assembly,Vector3(0,.045,-length-.085),Vector3(0,.045,-length-.115),.017,dark)
	rod(gun,assembly,Vector3(0,.045,-length-.115),Vector3(0,.045,-length-.1205),.009,recess)
	assembly.set_meta("design_provenance","Original ASHFALL geometry; filmed rail/vent/chassis/bolt cues; absolute dimensions authored")
	batch(assembly)
	return assembly
static func box(gun:Node3D,parent:Node3D,size:Vector3,at:Vector3,material:Material,bevel:float=.003)->void:
	gun._beveled(size,at,material,bevel,parent)
static func rod(gun:Node3D,parent:Node3D,a:Vector3,b:Vector3,radius:float,material:Material,sides:int=12)->void:
	gun._rod(a,b,radius,material,sides,parent)
static func section(width:float,height:float,at:Vector3)->Array[Vector3]:
	var x:=width*.5;var y:=height*.5;var bevel:=minf(x,y)*.22
	var points:Array[Vector3]=[]
	for p in [Vector2(-x+bevel,-y),Vector2(x-bevel,-y),Vector2(x,-y+bevel),Vector2(x,y-bevel),Vector2(x-bevel,y),Vector2(-x+bevel,y),Vector2(-x,y-bevel),Vector2(-x,-y+bevel)]:points.append(at+Vector3(p.x,p.y,0))
	return points
static func triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3)->void:
	# Godot front faces are clockwise: supplied normal points out of the shell.
	var normal:Vector3=(c-a).cross(b-a).normalized()
	for point in [a,b,c]:surface.set_normal(normal);surface.add_vertex(point)
static func stock(parent:Node3D,w0:float,h0:float,y0:float,z0:float,w1:float,h1:float,y1:float,z1:float,finish:Material)->void:
	var start:=section(w0,h0,Vector3(0,y0,z0));var end:=section(w1,h1,Vector3(0,y1,z1))
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var next:=(i+1)%8
		triangle(surface,start[i],end[i],end[next]);triangle(surface,start[i],end[next],start[next])
		triangle(surface,Vector3(0,y0,z0),start[i],start[next]);triangle(surface,Vector3(0,y1,z1),end[next],end[i])
	# Match the indexed primitive fittings before append_from batches them.
	# Otherwise these stored stock vertices can be omitted by the final indices.
	surface.index()
	var part:=MeshInstance3D.new();part.name="TaperedShoulderStock";part.mesh=surface.commit();part.material_override=finish;parent.add_child(part)
static func curved_magazine()->ArrayMesh:
	# One closed continuous original shell replaces the old stack of angled boxes.
	# Its installed pivot, reload target and the three live/offered/ejected owners stay.
	var sections:Array=[];var count:=16
	for i in range(count+1):
		var t:=float(i)/count;var half_width:=lerpf(.0205,.019,t);var half_depth:=.037
		var centre:=Vector3(0,.075-.180*t,-.064*t*t);var rotation:=Basis(Vector3.RIGHT,atan2(.128*t,.180))
		var ring:Array[Vector3]=[];var bevel:=.004
		for p in [Vector2(-half_width+bevel,-half_depth),Vector2(half_width-bevel,-half_depth),Vector2(half_width,-half_depth+bevel),Vector2(half_width,half_depth-bevel),Vector2(half_width-bevel,half_depth),Vector2(-half_width+bevel,half_depth),Vector2(-half_width,half_depth-bevel),Vector2(-half_width,-half_depth+bevel)]:ring.append(centre+rotation*Vector3(p.x,0,p.y))
		sections.append(ring)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count):
		for side in range(8):
			var next:=(side+1)%8
			triangle(surface,sections[i][side],sections[i+1][side],sections[i+1][next]);triangle(surface,sections[i][side],sections[i+1][next],sections[i][next])
	for side in range(8):
		var next:=(side+1)%8
		triangle(surface,Vector3(0,.075,0),sections[0][side],sections[0][next])
		triangle(surface,Vector3(0,-.105,-.064),sections[count][next],sections[count][side])
	return surface.commit()
static func batch(parent:Node3D)->void:
	# Moving magazines, charging parts and sight references live outside this group.
	var groups:Dictionary={}
	for part in parent.get_children():
		if part is MeshInstance3D:
			var material:Material=part.material_override
			if not groups.has(material):groups[material]=[]
			groups[material].append(part)
	for material in groups:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[material]:
			for index in part.mesh.get_surface_count():surface.append_from(part.mesh,index,part.transform)
			part.free()
		var mesh:=MeshInstance3D.new();mesh.name="BatchedChassisFinish";mesh.mesh=surface.commit();mesh.material_override=material
		parent.add_child(mesh)
