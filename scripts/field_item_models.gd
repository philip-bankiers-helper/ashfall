extends RefCounted
## Original ASHFALL item meshes. Reference observations and inferred details are
## recorded in workers/equipment-models/reports/MODEL-REFERENCE-064.md.
const REVISION := "equipment-models-064-a"

static func material(tint:Color,metallic:float=0.0,roughness:float=.65)->StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=tint;mat.metallic=metallic;mat.roughness=roughness
	return mat

static func _mesh(parent:Node3D,title:String,mesh:Mesh,at:Vector3,finish:Material)->MeshInstance3D:
	var part:=MeshInstance3D.new();part.name=title;part.mesh=mesh;part.position=at;part.material_override=finish
	parent.add_child(part);return part

static func _box(parent:Node3D,title:String,size:Vector3,at:Vector3,finish:Material,bevel:float=.004)->MeshInstance3D:
	return _mesh(parent,title,rounded_box(size,bevel),at,finish)

static func _ring(parent:Node3D,title:String,radius:float,thickness:float,at:Vector3,finish:Material)->MeshInstance3D:
	var mesh:=TorusMesh.new();mesh.inner_radius=radius-thickness*.5;mesh.outer_radius=radius+thickness*.5
	mesh.rings=24;mesh.ring_segments=6
	return _mesh(parent,title,mesh,at,finish)

static func _cylinder(parent:Node3D,title:String,radius:float,height:float,at:Vector3,finish:Material)->MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height
	mesh.radial_segments=24;mesh.rings=1
	return _mesh(parent,title,mesh,at,finish)

static func consumable(kind:String,titles:Dictionary)->Node3D:
	var prop:=Node3D.new();prop.name="Field_"+kind;prop.set_meta("model_revision",REVISION)
	match kind:
		"soda":_soda(prop)
		"shaker":_shaker(prop)
		"banana":_banana(prop)
		"backpack":_backpack(prop)
		_:_box(prop,"UnknownItem",Vector3(.08,.08,.08),Vector3.ZERO,material(Color(.4,.5,.6)))
	if kind in ["soda","shaker"]:
		for part in prop.get_children():
			if part.name.begins_with("Shield") or part.name.begins_with("SideBand") or part.name.begins_with("LabelRule") or part.name.begins_with("MeasureTick") or part.name.begins_with("GripInset"):part.rotate_y(-PI*.5)
	_bake_static(prop)
	# Preserve the existing world label, physical origin, and direct-child Cap contract.
	var label:=Label3D.new();label.name="ItemTitle";label.text=titles.get(kind,"BACKPACK +1 POUCH")
	label.font_size=28;label.pixel_size=.0014;label.outline_size=5;label.position.y=.25
	label.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;prop.add_child(label);label.hide()
	return prop

static func _soda(prop:Node3D)->void:
	var blue:=material(Color(.10,.52,.78),.42,.34)
	var silver:=material(Color(.72,.79,.82),.78,.28)
	var pale:=material(Color(.87,.94,.92),.1,.48)
	var ink:=material(Color(.035,.12,.18),.1,.5)
	# 02:15/02:20 film: short blue can, silver rolled end, inset ring and pull tab.
	var profile:Array[Vector2]=[Vector2(0,-.067),Vector2(.031,-.067),Vector2(.035,-.062),Vector2(.037,-.054),Vector2(.037,.048),Vector2(.034,.059),Vector2(.031,.064),Vector2(.030,.064)]
	_mesh(prop,"CanBody",lathe(profile,32),Vector3.ZERO,blue)
	_ring(prop,"BottomRolledSeam",.032,.0035,Vector3(0,-.064,0),silver)
	_ring(prop,"TopRolledSeam",.032,.0035,Vector3(0,.065,0),silver)
	# Source141.003s retains the silver end and pull ring around the opening.
	# The previous whole-lid Cap removal exposed a large black disc instead.
	# A true annular lid and open body neck leave no opaque face across the hole.
	var cavity:Array[Vector2]=[Vector2(.029,.063),Vector2(.029,.043),Vector2(0,.042)]
	_mesh(prop,"RecessedInterior",lathe(cavity,32),Vector3.ZERO,ink)
	_mesh(prop,"PermanentEndPlate",can_lid_with_opening(),Vector3(0,.0646,0),silver)
	_ring(prop,"LidPressGroove",.026,.0008,Vector3(0,.0648,0),silver)
	var tab:=_ring(prop,"PermanentPullTab",.008,.0025,Vector3(0,.067,-.005),silver);tab.scale=Vector3(.65,.30,1.10)
	_cylinder(prop,"PermanentRivet",.0028,.0022,Vector3(0,.066,-.010),silver)
	var cap:=Node3D.new();cap.name="Cap";prop.add_child(cap)
	var seal:=_cylinder(cap,"RemovableOpeningSeal",.0104,.0010,Vector3(0,.0652,.010),silver);seal.scale.x=.71154
	# Original small shield emblem and alternating label bands, no source logo/text.
	for side in [-1,1]:
		_wrapped_panel(prop,"SideBand",Vector2(.03745,.03745),Vector2(-.042,.042),Vector2(side*.60-.28,side*.60+.28),pale)
	_wrapped_panel(prop,"ShieldMark",Vector2(.03750,.03750),Vector2(-.0105,.0205),Vector2(-.30,.30),pale)
	_wrapped_panel(prop,"ShieldInset",Vector2(.03765,.03765),Vector2(-.0035,.0155),Vector2(-.16,.16),blue)
	for i in range(3):
		var half_angle:float=(.018-i*.003)/(.03745*2)
		_wrapped_panel(prop,"LabelRule%d"%i,Vector2(.03745,.03745),Vector2(-.024-i*.004-.0006,-.024-i*.004+.0006),Vector2(-half_angle,half_angle),pale,8)

static func _shaker(prop:Node3D)->void:
	var blue:=material(Color(.10,.44,.60),.15,.42)
	var rubber:=material(Color(.045,.09,.115),0,.86)
	var silver:=material(Color(.58,.69,.72),.62,.36)
	var pale:=material(Color(.68,.88,.89),.1,.52)
	# A clear shaker close-up is absent from the provided loco film: ergonomic
	# taper, cap ribs and graduation marks below are original inferred detail.
	var profile:Array[Vector2]=[Vector2(0,-.102),Vector2(.030,-.102),Vector2(.039,-.093),Vector2(.043,-.077),Vector2(.047,.070),Vector2(.044,.092),Vector2(.038,.103),Vector2(.030,.103)]
	_mesh(prop,"BottleBody",lathe(profile,28),Vector3.ZERO,blue)
	_ring(prop,"HeelBumper",.036,.006,Vector3(0,-.094,0),rubber)
	_ring(prop,"NeckCollar",.041,.004,Vector3(0,.095,0),silver)
	# The independent cap must uncover a real neck, not an opaque rubber disc.
	# This cavity is an authored geometry correction, not a measured film detail.
	var interior:Array[Vector2]=[Vector2(.0295,.103),Vector2(.0295,.080),Vector2(0,.079)]
	_mesh(prop,"OpenMouth",lathe(interior,28),Vector3.ZERO,rubber)
	var cap:=Node3D.new();cap.name="Cap";prop.add_child(cap)
	_cylinder(cap,"RibbedLid",.047,.025,Vector3(0,.108,0),rubber)
	for i in range(16):
		var angle:=TAU*i/16
		var rib:=_box(cap,"LidRib%d"%i,Vector3(.004,.019,.003),Vector3(sin(angle)*.047,.108,cos(angle)*.047),silver,.001)
		rib.rotation.y=angle
	_box(cap,"FlipSpout",Vector3(.026,.012,.038),Vector3(0,.127,.008),blue,.005)
	for i in range(6):
		var y:float=-.057+i*.022;var radius:=_bottle_radius(y)+.00045
		var half_angle:float=(.009 if i%2 else .015)/(radius*2);var center_angle:=asin(.014/radius)
		_wrapped_panel(prop,"MeasureTick%d"%i,Vector2(_bottle_radius(y-.0009)+.00045,_bottle_radius(y+.0009)+.00045),Vector2(y-.0009,y+.0009),Vector2(center_angle-half_angle,center_angle+half_angle),pale,6)
	for side in [-1,1]:
		_wrapped_panel(prop,"GripInset",Vector2(_bottle_radius(-.060)+.0008,_bottle_radius(.040)+.0008),Vector2(-.060,.040),Vector2(side*.75-.11,side*.75+.11),rubber,8)
	_wrapped_panel(prop,"ShieldMark",Vector2(_bottle_radius(.0045)+.00045,_bottle_radius(.0315)+.00045),Vector2(.0045,.0315),Vector2(-.35,.08),pale,8)

static func _banana(prop:Node3D)->void:
	# Continuous tapered curve replaces stacked boxes. General fruit silhouette,
	# peel seams and stem are inferred; the film does not establish a close-up.
	var flesh:=material(Color(.93,.86,.59),0,.8)
	var yellow:=material(Color(.94,.70,.065),0,.59)
	var seam:=material(Color(.56,.37,.055),0,.8)
	var stem:=material(Color(.22,.14,.055),0,.95)
	_mesh(prop,"FruitCore",banana_tube(.021),Vector3.ZERO,flesh)
	var cap:=Node3D.new();cap.name="Cap";prop.add_child(cap)
	_mesh(cap,"PeelShell",banana_tube(.0255),Vector3.ZERO,yellow)
	for side in [-1,1]:
		var vertices:PackedVector3Array=[]
		for i in range(17):
			var t:=float(i)/16;var center:=_banana_center(t)
			vertices.append(center+Vector3(side*.017,0,.018*sin(PI*t)))
		_mesh(cap,"PeelSeam",tube(vertices,.0008,5),Vector3.ZERO,seam)
	_box(cap,"Stem",Vector3(.013,.030,.014),Vector3(.048,.112,0),stem,.003).rotation.z=-.25
	_box(cap,"BlossomTip",Vector3(.010,.008,.010),Vector3(.048,-.113,0),stem,.003)

static func _backpack(prop:Node3D)->void:
	var fabric:=material(Color(.60,.13,.085),0,.9)
	var side_fabric:=material(Color(.36,.08,.055),0,.93)
	var webbing:=material(Color(.10,.13,.13),0,.95)
	var seam:=material(Color(.83,.35,.16),0,.82)
	var buckle:=material(Color(.36,.4,.39),.45,.46)
	# 00:00: red rounded pack, dark horizontal webbing and top carry loop.
	_box(prop,"PaddedBody",Vector3(.263,.33,.128),Vector3.ZERO,fabric,.025)
	_box(prop,"BackPadding",Vector3(.23,.29,.026),Vector3(0,.002,-.075),webbing,.012)
	_box(prop,"FrontPanel",Vector3(.222,.235,.030),Vector3(0,.026,.074),side_fabric,.018)
	_box(prop,"FrontPocket",Vector3(.223,.084,.044),Vector3(0,-.117,.079),fabric,.014)
	# Source3.200s resolves six rows; source1.6s shows the broad pocket bands.
	for i in range(6):_box(prop,"WebbingRow%d"%i,Vector3(.180,.012,.004),Vector3(0,.108-i*.032,.092),webbing,.002)
	for side in [-1,1]:
		_box(prop,"Piping",Vector3(.004,.210,.004),Vector3(side*.098,.024,.091),seam,.0015)
		_box(prop,"SidePocket",Vector3(.026,.12,.075),Vector3(side*.137,-.048,0),side_fabric,.009)
		var strap:=_box(prop,"PaddedShoulderStrap",Vector3(.035,.33,.022),Vector3(side*.073,.035,-.102),fabric,.010)
		strap.rotation.z=-side*.09
		_box(prop,"StrapBuckle",Vector3(.040,.032,.026),Vector3(side*.084,-.102,-.107),buckle,.004)
		_box(prop,"ZipperPull",Vector3(.006,.020,.006),Vector3(side*.092,.138,.086),buckle,.002)
	var handle_points:=PackedVector3Array([Vector3(-.042,.157,0),Vector3(-.042,.184,0),Vector3(-.024,.198,0),Vector3(.024,.198,0),Vector3(.042,.184,0),Vector3(.042,.157,0)])
	_mesh(prop,"CarryLoop",tube(handle_points,.006,6),Vector3.ZERO,webbing)
	for i in range(2):_box(prop,"LowerPocketWebbing%d"%i,Vector3(.180,.012,.004),Vector3(0,-.100-i*.029,.104),webbing,.002)

static func ammo_supply(box:Node3D,index:int)->void:
	box.set_meta("model_revision",REVISION)
	var family:=clampi(index,0,2)
	var base:=material(Color(.065,.10,.12),.45,.62)
	var rail:=material(Color(.27,.34,.36),.60,.43)
	var dark:=material(Color(.025,.038,.043),.2,.75)
	var accent:=material([Color(.12,.65,.73),Color(.83,.57,.12),Color(.84,.24,.13)][family],.23,.49)
	var brass:=material(Color(.64,.47,.19),.72,.38)
	# 01:00/02:05 resource crates show a dark frame, recessed panels and slats.
	# Ammo family colours/raised round glyphs remain the established ASHFALL scheme.
	# Stop the body at the inset seam. The previous full-height body overlapped
	# the lid's front/side planes once the legacy omitted lid triangles returned.
	_box(box,"SupplyBody",Vector3(.32,.162,.23),Vector3(0,-.019,0),base,.012)
	_box(box,"LidSeam",Vector3(.315,.008,.225),Vector3(0,.066,0),dark,.003)
	_box(box,"Lid",Vector3(.32,.027,.23),Vector3(0,.085,0),rail,.007)
	for side in [-1,1]:
		_box(box,"CornerRail",Vector3(.017,.178,.237),Vector3(side*.147,-.005,0),rail,.004)
		_box(box,"Latch",Vector3(.028,.040,.012),Vector3(side*.096,.056,.12),rail,.004)
		_box(box,"LatchInset",Vector3(.015,.017,.004),Vector3(side*.096,.054,.128),dark,.002)
	_box(box,"FrontInset",Vector3(.245,.080,.005),Vector3(0,-.004,.117),dark,.005)
	_box(box,"FamilyStripe",Vector3(.237,.026,.006),Vector3(0,-.009,.121),accent,.003)
	for i in range(5):_box(box,"FrontRib%d"%i,Vector3(.008,.057,.006),Vector3((i-2)*.044,-.004,.125),rail,.002)
	for side in [-1,1]:_box(box,"EndInset",Vector3(.004,.10,.145),Vector3(side*.161,-.005,0),dark,.002)
	for slot in range(3):
		var glyph:=Node3D.new();glyph.name="RoundGlyph%d"%slot;glyph.position=Vector3((slot-1)*.060,.103,0);glyph.rotation.x=PI/2;box.add_child(glyph)
		var radius:=.012 if family!=2 else .017
		var height:float=[.095,.060,.075][family]
		_cylinder(glyph,"Case",radius,height,Vector3.ZERO,accent if family==2 else brass)
		_ring(glyph,"Rim",radius+.001,.002,Vector3(0,-height*.5+.003,0),rail)
		if family!=2:
			var tip:=CylinderMesh.new();tip.top_radius=.001;tip.bottom_radius=radius*.94;tip.height=.018;tip.radial_segments=12
			_mesh(glyph,"Bullet",tip,Vector3(0,height*.5+.009,0),brass)
	_bake_static(box)

static func can_lid_with_opening()->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(40):
		var a:=TAU*i/40;var b:=TAU*(i+1)/40
		var outer_a:=Vector3(sin(a)*.0304,0,cos(a)*.0304)
		var outer_b:=Vector3(sin(b)*.0304,0,cos(b)*.0304)
		var inner_a:=Vector3(sin(a)*.007,0,.010+cos(a)*.010)
		var inner_b:=Vector3(sin(b)*.007,0,.010+cos(b)*.010)
		var vertices:Array[Vector3]=[outer_a,outer_b,inner_b,inner_a]
		for q in [0,2,1,0,3,2]:surface.set_normal(Vector3.UP);surface.add_vertex(vertices[q])
		# Real depth around the aperture, not an opaque dark decal over a full lid.
		var wall:Array[Vector3]=[inner_a,inner_b,inner_b-Vector3.UP*.0018,inner_a-Vector3.UP*.0018]
		for q in [0,2,1,0,3,2]:
			var v:Vector3=wall[q];var inward:=Vector3(-v.x/(.007*.007),0,-(v.z-.010)/(.010*.010)).normalized()
			surface.set_normal(inward);surface.add_vertex(v)
	# Batching with indexed rings/cylinders requires indices for this custom mesh.
	surface.index()
	return surface.commit()

static func _bottle_radius(y:float)->float:
	return lerpf(.043,.047,clampf((y+.077)/.147,0,1))

static func _wrapped_panel(parent:Node3D,title:String,radii:Vector2,heights:Vector2,angles:Vector2,finish:Material,segments:int=10)->void:
	# Printed/rubber surface follows the actual lathed cylinder/taper. The prior
	# flat boxes intersected near their inner edge and floated off the outer edge.
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(segments):
		var a:=lerpf(angles.x,angles.y,float(i)/segments);var b:=lerpf(angles.x,angles.y,float(i+1)/segments)
		var vertices:Array[Vector3]=[Vector3(sin(a)*radii.x,heights.x,cos(a)*radii.x),Vector3(sin(b)*radii.x,heights.x,cos(b)*radii.x),Vector3(sin(b)*radii.y,heights.y,cos(b)*radii.y),Vector3(sin(a)*radii.y,heights.y,cos(a)*radii.y)]
		var slope:=Vector2(heights.y-heights.x,radii.x-radii.y).normalized()
		for q in [0,2,1,0,3,2]:
			var radial:=Vector3(vertices[q].x,0,vertices[q].z).normalized()
			surface.set_normal(Vector3(radial.x*slope.x,slope.y,radial.z*slope.x));surface.add_vertex(vertices[q])
	surface.index()
	_mesh(parent,title,surface.commit(),Vector3.ZERO,finish)

static func _bake_static(container:Node3D)->void:
	# Preserve the independently removable Cap while batching static details by
	# finish. A detailed item needs at most six body surfaces, not dozens of draws.
	var groups:Dictionary={};var parts:Array[String]=[];var meshes:Array[MeshInstance3D]=[]
	_collect_meshes(container,Transform3D.IDENTITY,groups,parts,meshes)
	var combined:=ArrayMesh.new()
	for finish in groups:
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(finish)
		for entry in groups[finish]:
			for index in range(entry.mesh.get_surface_count()):surface.append_from(entry.mesh,index,entry.transform)
		surface.commit(combined)
	for old in meshes:old.get_parent().remove_child(old);old.free()
	if combined.get_surface_count()>0:_mesh(container,"ModelSurfaces",combined,Vector3.ZERO,null)
	container.set_meta("visual_parts",parts)

static func _collect_meshes(node:Node3D,transform:Transform3D,groups:Dictionary,parts:Array[String],meshes:Array[MeshInstance3D])->void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var finish:Material=child.material_override
			if not groups.has(finish):groups[finish]=[]
			groups[finish].append({"mesh":child.mesh,"transform":transform*child.transform});parts.append(str(child.name));meshes.append(child)
		elif child is Node3D and not child is Label3D:
			if child.name=="Cap":_bake_static(child)
			else:_collect_meshes(child,transform*child.transform,groups,parts,meshes)

static func rounded_box(size:Vector3,bevel:float)->ArrayMesh:
	var half:=size*.5;var radius:=minf(maxf(bevel,.00001),minf(half.x,minf(half.y,half.z))*.8)
	var inner:=half-Vector3.ONE*radius;var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axes:Array[Vector3]=[Vector3.RIGHT,Vector3.UP,Vector3.BACK]
	for axis in range(3):
		var u:Vector3=axes[(axis+1)%3];var v:Vector3=axes[(axis+2)%3];var normal:Vector3=axes[axis]
		var us:float=half[(axis+1)%3];var vs:float=half[(axis+2)%3]
		var ug:Array[float]=[-us,-us+radius,us-radius,us];var vg:Array[float]=[-vs,-vs+radius,vs-radius,vs]
		for sign_value in [-1,1]:
			for j in range(3):
				for k in range(3):
					var positions:Array[Vector3]=[normal*half[axis]*sign_value+u*ug[j]+v*vg[k],normal*half[axis]*sign_value+u*ug[j+1]+v*vg[k],normal*half[axis]*sign_value+u*ug[j+1]+v*vg[k+1],normal*half[axis]*sign_value+u*ug[j]+v*vg[k+1]]
					for q in ([0,2,1,0,3,2] if sign_value>0 else [0,1,2,0,2,3]):
						var point:Vector3=positions[q];var core:=point.clamp(-inner,inner);var outward:Vector3=(point-core).normalized()
						surface.set_normal(outward);surface.add_vertex(core+outward*radius)
	surface.index()
	return surface.commit()

static func lathe(profile:Array[Vector2],segments:int)->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size()-1):
		var from:=profile[ring];var to:=profile[ring+1]
		for side in range(segments):
			var a:=TAU*side/segments;var b:=TAU*(side+1)/segments
			var points:Array[Vector3]=[Vector3(sin(a)*from.x,from.y,cos(a)*from.x),Vector3(sin(b)*from.x,from.y,cos(b)*from.x),Vector3(sin(b)*to.x,to.y,cos(b)*to.x),Vector3(sin(a)*to.x,to.y,cos(a)*to.x)]
			for q in [0,2,1,0,3,2]:
				var at:Vector3=points[q];var radial:=Vector3(at.x,0,at.z).normalized();var slope:=Vector2(to.y-from.y,from.x-to.x).normalized()
				surface.set_normal(Vector3(radial.x*slope.x,slope.y,radial.z*slope.x));surface.add_vertex(at)
	# Keep custom lathed surfaces present when batched with indexed primitives.
	surface.index()
	return surface.commit()

static func _banana_center(t:float)->Vector3:
	return Vector3(.050*pow(2*t-1,2),lerpf(-.11,.11,t),0)

static func banana_tube(radius:float)->ArrayMesh:
	var centers:PackedVector3Array=[]
	for i in range(19):centers.append(_banana_center(float(i)/18))
	return tube(centers,radius,10,true)

static func tube(points:PackedVector3Array,radius:float,sides:int,taper:bool=false)->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array[PackedVector3Array]=[]
	for i in range(points.size()):
		var tangent:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var side:=tangent.cross(Vector3.FORWARD).normalized()
		if side.length_squared()<.1:side=Vector3.RIGHT
		var second:=tangent.cross(side).normalized();var ring:PackedVector3Array=[]
		var r:=radius*(.15+.85*pow(sin(PI*float(i)/(points.size()-1)),.45) if taper else 1.0)
		for k in range(sides):ring.append(points[i]+(side*cos(TAU*k/sides)+second*sin(TAU*k/sides))*r)
		rings.append(ring)
	for i in range(points.size()-1):
		for k in range(sides):
			var n:=(k+1)%sides
			var verts:Array[Vector3]=[rings[i][k],rings[i][n],rings[i+1][n],rings[i+1][k]]
			for q in [0,2,1,0,3,2]:
				var ring_index:=i if q<2 else i+1
				surface.set_normal((verts[q]-points[ring_index]).normalized());surface.add_vertex(verts[q])
	for endpoint in [0,points.size()-1]:
		var outward:Vector3=(points[endpoint]-points[1 if endpoint==0 else endpoint-1]).normalized()
		for k in range(sides):
			var a:Vector3=rings[endpoint][k];var b:Vector3=rings[endpoint][(k+1)%sides]
			if (a-points[endpoint]).cross(b-points[endpoint]).dot(outward)>0:
				var swap:=a;a=b;b=swap
			for point in [points[endpoint],a,b]:surface.set_normal(outward);surface.add_vertex(point)
	surface.index()
	return surface.commit()
