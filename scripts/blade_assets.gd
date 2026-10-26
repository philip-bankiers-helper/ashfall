extends RefCounted
## Original authored meshes. Reference weapon names identify interaction archetypes only.
## Primary fist agrees with the tracked controller; no borrowed models/textures.
## Qualitative palette/silhouette: Al film10.07s/25.16s/35.23s. Dimensions
## below are authored except the explicit four-foot span/eight-inch pommel datum.
const GRIP:=Vector3(0,-.057,.025)
const LIVE_LAYER:=1<<18
const SWORD_LENGTH:=1.2192 * preload("res://scripts/measurement_calibration.gd").FACTOR # Four feet. Al corrected each formerly labelled1m grid unit to2ft (×0.6096),2026-10-20.
const HILT_LENGTH:=.285
const PRIMARY_POMMEL_DISTANCE:=.2032 * preload("res://scripts/measurement_calibration.gd").FACTOR # Al: primary fist8in from the pommel end,2026-10-20.
const KNIFE_LENGTH:=.38 # Original compact art; reference physical length remains unmeasured.
static func build(parent:Node3D,kind:String)->Dictionary:
	var steel:=material(Color("35434b") if kind=="katana" else (Color("333b44") if kind=="cyberblade" else Color("a8bac5")),.88,.31)
	var edge:=material(Color("dbe8ed"),.94,.22)
	var dark:=material(Color("1c2931"),.52,.57)
	var wrap:=material(Color("40383e") if kind=="katana" else (Color("215979") if kind=="excalibur" else Color("243746")),.02,.90)
	var accent:=material(Color("a9b1b5") if kind=="katana" else (Color("a33b38") if kind=="cyberblade" else Color("b79a59")),.68,.32)
	var light:=material(Color("83d755") if kind=="katana" else Color("d9544c"),.3,.35,true)
	if kind=="knife":return _build_knife(parent,steel,edge,dark,wrap,accent)
	# Datum is the outer pommel end, not the guard. Retain the tracked fist and
	# controller-sized wrap; solve the handle tail around the exact8in distance.
	var bottom_y:=GRIP.y-PRIMARY_POMMEL_DISTANCE
	var pommel_y:=bottom_y+.0145
	var hilt_top:=bottom_y+.029+HILT_LENGTH
	var hilt_centre:=Vector3(0,hilt_top-HILT_LENGTH*.5,GRIP.z)
	var base_to_bottom:=.085-bottom_y
	var curvature:float=.075/.83 if kind=="katana" else (.012/.79 if kind=="cyberblade" else 0.0)
	var square:=1.0+curvature*curvature
	var length:float=(-base_to_bottom+sqrt(base_to_bottom*base_to_bottom+square*(SWORD_LENGTH*SWORD_LENGTH-base_to_bottom*base_to_bottom)))/square
	var curve_gain:float=length/float({"katana":.83,"excalibur":.95,"cyberblade":.79}.get(kind,.83))
	var width:float={"katana":.033,"excalibur":.068,"cyberblade":.055}.get(kind,.033)
	box(parent,"GripCore",Vector3(.032,HILT_LENGTH,.037),hilt_centre,wrap)
	if kind=="excalibur":
		var binding:=material(Color("9cabb2"),.32,.58)
		for i in 6:
			for side in [-1,1]:
				var strip:=box(parent,"GripBinding%d_%d"%[i,side],Vector3(.035,.005,.040),hilt_centre+Vector3(0,-.110+i*.044,0),binding)
				strip.rotation.z=side*.60
	else:
		for i in 12:
			var strip:=box(parent,"GripBinding%d"%i,Vector3(.035,.005,.040),hilt_centre+Vector3(0,-.124+i*.023,0),dark)
			strip.rotation.z=(.42 if i%2==0 else -.42) if kind=="katana" else 0.0
	box(parent,"Pommel",Vector3(.044,.029,.046),Vector3(0,pommel_y,GRIP.z),accent)
	var base:=Vector3(0,.085,.025)
	var collar:=MeshInstance3D.new();var collar_mesh:=CylinderMesh.new();collar_mesh.top_radius=.022;collar_mesh.bottom_radius=.020;collar_mesh.height=base.y-.006-hilt_top;collar_mesh.radial_segments=12
	collar.mesh=collar_mesh;collar.position=Vector3(0,hilt_top+collar_mesh.height*.5,GRIP.z);collar.material_override=accent;add_mesh(parent,collar,"HiltCollar")
	if kind=="katana":
		var guard:=MeshInstance3D.new();var disk:=CylinderMesh.new();disk.top_radius=.048;disk.bottom_radius=.048;disk.height=.012;disk.radial_segments=16;guard.mesh=disk;guard.position=base;guard.scale.z=.72;guard.material_override=accent;add_mesh(parent,guard,"OvalGuard")
		for side in [-1,1]:box(parent,"GuardInset%d"%side,Vector3(.034,.001,.008),base+Vector3(side*.021,.0064,0),light)
	elif kind=="excalibur":
		box(parent,"Quillon",Vector3(.26,.023,.043),base,accent)
		for side in [-1.0,1.0]:
			var hook:=box(parent,"GuardEnd",Vector3(.031,.065,.035),base+Vector3(side*.122,-.014,0),accent);hook.rotation.z=side*.30
	else:
		box(parent,"AsymmetricGuard",Vector3(.155,.026,.05),base+Vector3(.025,0,0),dark)
		box(parent,"PowerCell",Vector3(.028,.085,.044),GRIP+Vector3(.027,.025,0),accent)
		box(parent,"GripStatusLight",Vector3(.004,.055,.045),GRIP+Vector3(.043,.025,0),light)
	var rings:Array[Vector3]=[]
	var sections:=20
	for i in sections+1:
		var t:=float(i)/sections
		var curve:float=(-.075*t*t if kind=="katana" else (-.012*t if kind=="cyberblade" else 0.0))*curve_gain
		rings.append(base+Vector3(0,length*t,curve))
	_blade_meshes(parent,kind,rings,width,steel,edge)
	# Thin original inlays follow the actual face instead of floating boxes.
	if kind=="excalibur":
		for side in [-1,1]:_face_inlay(parent,"ForgedFullerInlay%d"%side,kind,rings,width,side*.18,.060,Vector2(.06,.78),dark)
	elif kind=="cyberblade":
		_face_inlay(parent,"ArmoredSpineInlay",kind,rings,width,-.24,.080,Vector2(.04,.88),dark)
		for i in 7:
			var t:=(i+.8)/9.0
			_face_inlay(parent,"EnergyInset%d"%i,kind,rings,width,.10,.32,Vector2(t-.025,t+.025),light)
	var lower:=Marker3D.new();lower.position=base+Vector3.UP*.04;lower.name="BladeContactBase";parent.add_child(lower)
	var upper:=Marker3D.new();upper.position=rings.back();upper.name="BladeContactTip";parent.add_child(upper)
	if kind in ["katana","excalibur","cyberblade"] and not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/downloaded_blade_model.gd").apply(parent,kind)
	return {"base":lower,"tip":upper,"grip":GRIP,"length":length,"kind":kind}
static func _build_knife(parent:Node3D,steel:Material,edge:Material,dark:Material,wrap:Material,accent:Material)->Dictionary:
	box(parent,"GripCore",Vector3(.033,.130,.036),GRIP,wrap)
	for i in 5:box(parent,"GripBinding%d"%i,Vector3(.035,.008,.039),GRIP+Vector3(0,-.052+i*.026,0),dark)
	var bottom:=GRIP.y-.065-.012
	box(parent,"Pommel",Vector3(.039,.012,.041),Vector3(0,bottom+.006,GRIP.z),accent)
	var base:=Vector3(0,.025,GRIP.z)
	box(parent,"KnifeGuard",Vector3(.080,.014,.044),base,accent)
	# Original exposed tang closes the actual10mm handle-to-guard gap.
	box(parent,"KnifeTangNeck",Vector3(.030,.010,.032),Vector3(0,.013,GRIP.z),steel)
	var tip:=Vector3(0,bottom+KNIFE_LENGTH,GRIP.z)
	var rings:Array[Vector3]=[]
	for i in 13:rings.append(base.lerp(tip,float(i)/12))
	_blade_meshes(parent,"knife",rings,.043,steel,edge)
	_face_inlay(parent,"KnifeSpineInlay","knife",rings,.043,-.22,.045,Vector2(.08,.70),dark)
	for side in [-1,1]:
		var fastener:=MeshInstance3D.new();var rivet:=SphereMesh.new();rivet.radius=.0025;rivet.height=.0015;rivet.radial_segments=8;rivet.rings=4
		fastener.mesh=rivet;fastener.position=GRIP+Vector3(0,side*.038,.0184);fastener.rotation.x=PI*.5;fastener.material_override=accent;add_mesh(parent,fastener,"KnifeGripFastener%d"%side)
	var contact_base:=Marker3D.new();contact_base.name="BladeContactBase";contact_base.position=base;parent.add_child(contact_base)
	var contact_tip:=Marker3D.new();contact_tip.name="BladeContactTip";contact_tip.position=tip;parent.add_child(contact_tip)
	if not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/downloaded_blade_model.gd").apply(parent,"knife")
	return {"base":contact_base,"tip":contact_tip,"grip":GRIP,"length":tip.y-base.y,"kind":"knife"}
static func width_at(kind:String,width:float,t:float)->float:
	var taper:=clampf((1.0-t)/.15,0.0,1.0)
	if kind=="cyberblade":return width*(1.0 if t<.72 else .68)*maxf(taper,.02)
	return width*lerpf(1.0,.72,t)*maxf(taper,.02)
static func half_thickness(kind:String,t:float)->float:
	var root:float={"katana":.0030,"excalibur":.0035,"cyberblade":.0075,"knife":.0024}.get(kind,.0030)
	return lerpf(root,.00015,smoothstep(.70,1.0,t))
static func cross_section(at:Vector3,width:float,half_depth:float=.003)->Array[Vector3]:
	return [at+Vector3(-width*.5,0,0),at+Vector3(-width*.35,0,half_depth),at+Vector3(width*.35,0,half_depth),at+Vector3(width*.5,0,0),at+Vector3(width*.35,0,-half_depth),at+Vector3(-width*.35,0,-half_depth)]
static func _triangle(surface:SurfaceTool,a:Vector3,b:Vector3,c:Vector3)->void:
	# Godot front faces are clockwise. Explicit flat normals keep each broad
	# face/bevel/cap outward, instead of averaging a cutting edge across faces.
	var normal:Vector3=(c-a).cross(b-a).normalized()
	for vertex in [a,b,c]:surface.set_normal(normal);surface.add_vertex(vertex)
static func _blade_meshes(parent:Node3D,kind:String,rings:Array[Vector3],width:float,steel:Material,edge:Material)->void:
	var flats:=SurfaceTool.new();flats.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bevels:=SurfaceTool.new();bevels.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows:Array=[]
	for i in rings.size():
		var t:=float(i)/(rings.size()-1)
		rows.append(cross_section(rings[i],width_at(kind,width,t),half_thickness(kind,t)))
	for i in rings.size()-1:
		var a:Array=rows[i];var b:Array=rows[i+1]
		for face in 6:
			var next:=(face+1)%6;var target:SurfaceTool=flats if face in [1,4] else bevels
			_triangle(target,a[face],b[next],a[next]);_triangle(target,a[face],b[face],b[next])
	# Close both ends; the former constant20mm tip cross-section was blunt/open.
	for end in [0,rings.size()-1]:
		var row:Array=rows[end]
		for face in 6:
			var next:=(face+1)%6
			if end==0:_triangle(flats,rings[end],row[face],row[next])
			else:_triangle(flats,rings[end],row[next],row[face])
	var blade:=MeshInstance3D.new();blade.mesh=flats.commit();blade.material_override=steel;add_mesh(parent,blade,"AuthoredBlade")
	var cutting_edge:=MeshInstance3D.new();cutting_edge.mesh=bevels.commit();cutting_edge.material_override=edge;add_mesh(parent,cutting_edge,"ContinuousEdgeBevels")
static func _point_on_blade(rings:Array[Vector3],t:float)->Vector3:
	var at:=clampf(t,0,1)*(rings.size()-1);var lower:=mini(floori(at),rings.size()-2)
	return rings[lower].lerp(rings[lower+1],at-lower)
static func _face_inlay(parent:Node3D,label:String,kind:String,rings:Array[Vector3],width:float,offset_ratio:float,width_ratio:float,span:Vector2,finish:Material)->void:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for i in 12:
			var t0:=lerpf(span.x,span.y,float(i)/12);var t1:=lerpf(span.x,span.y,float(i+1)/12)
			var w0:=width_at(kind,width,t0);var w1:=width_at(kind,width,t1)
			var a:=_point_on_blade(rings,t0)+Vector3(w0*offset_ratio,0,side*(half_thickness(kind,t0)+.00012))
			var b:=_point_on_blade(rings,t1)+Vector3(w1*offset_ratio,0,side*(half_thickness(kind,t1)+.00012))
			var left0:=a+Vector3.LEFT*w0*width_ratio*.5;var right0:=a+Vector3.RIGHT*w0*width_ratio*.5
			var left1:=b+Vector3.LEFT*w1*width_ratio*.5;var right1:=b+Vector3.RIGHT*w1*width_ratio*.5
			var vertices:=[left0,right1,right0,left0,left1,right1] if side>0 else [left0,right0,right1,left0,right1,left1]
			for triangle in 2:_triangle(surface,vertices[triangle*3],vertices[triangle*3+1],vertices[triangle*3+2])
	var inlay:=MeshInstance3D.new();inlay.mesh=surface.commit();inlay.material_override=finish;add_mesh(parent,inlay,label)
static func material(color:Color,metallic:float,roughness:float,emissive:bool=false)->StandardMaterial3D:
	var result:=StandardMaterial3D.new();result.albedo_color=color;result.metallic=metallic;result.roughness=roughness
	if emissive:result.emission_enabled=true;result.emission=color;result.emission_energy_multiplier=1.4
	return result
static func add_mesh(parent:Node3D,mesh:MeshInstance3D,label:String)->void:
	mesh.name=label;mesh.layers=LIVE_LAYER;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
static func box(parent:Node3D,label:String,size:Vector3,at:Vector3,finish:Material)->MeshInstance3D:
	var part:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;part.mesh=mesh;part.position=at;part.material_override=finish;add_mesh(parent,part,label);return part
