extends RefCounted
## Original elementary meshes in calibrated reference-pixel units.
static func line_mesh(segments:Array,width:float,unit:float,triangles:Array=[])->ArrayMesh:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in segments:
		var a:Vector2=segment[0];var b:Vector2=segment[1]
		var side:Vector2=(b-a).orthogonal().normalized()*width*.5
		for p in [a-side,a+side,b+side,a-side,b+side,b-side]:surface.add_vertex(Vector3(p.x,p.y,0)*unit)
	for triangle in triangles:
		for p in triangle:surface.add_vertex(Vector3(p.x,p.y,0)*unit)
	return surface.commit()
static func rebuild(node:Node3D,p:Dictionary)->void:
	var unit:=1.0/(1147.17*.04) # Existing distance clamp and4x scale remain in aim_reticle.
	var shape:String=p.get("shape","cross")
	for i in 8:
		var part:MeshInstance3D=node.get_child(i);var red:=i>=4;var index:=i%4
		var stroke:float=float(p.get("stroke_px",3.0))+(0.0 if red else 2.0)
		part.rotation=Vector3.ZERO;part.show()
		if shape=="cross":
			var mesh:=QuadMesh.new();var arm:float=float(p.get("arm_px",21.0))+(0.0 if red else 2.0)
			mesh.size=Vector2(arm,stroke)*unit if index<2 else Vector2(stroke,arm)*unit;part.mesh=mesh
		elif shape=="bracket":
			var corner:Vector2=[Vector2(-1,1),Vector2(1,1),Vector2(1,-1),Vector2(-1,-1)][index]
			var leg:float=float(p.get("arm_px",14.0))
			part.mesh=line_mesh([[Vector2.ZERO,Vector2(-corner.x*leg,0)],[Vector2.ZERO,Vector2(0,-corner.y*leg)]],stroke,unit)
		elif shape=="chevron":
			var side:float=-1.0 if index<2 else 1.0
			var up:float=1.0 if index%2==0 else -1.0
			# Reference Magnum opens outwards: left < and right >.
			part.mesh=line_mesh([[Vector2.ZERO,Vector2(-side*float(p.get("chevron_depth_px",15.0)),up*float(p.get("chevron_height_px",32.0))*.5)]],stroke,unit)
static func layout(node:Node3D,p:Dictionary,width:float,colour:Color)->void:
	var unit:=1.0/(1147.17*.04);var shape:String=p.get("shape","cross")
	for i in 8:
		var part:MeshInstance3D=node.get_child(i);var index:=i%4
		var xy:=Vector2.ZERO
		if shape=="cross":
			var direction:Vector2=[Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN][index]
			xy=direction*(width*.5-float(p.get("arm_px",21.0))*.5)
		elif shape=="bracket":xy=([Vector2(-1,1),Vector2(1,1),Vector2(1,-1),Vector2(-1,-1)][index])*((width-float(p.get("stroke_px",3.0)))*.5)
		elif shape=="chevron":xy=Vector2((-1.0 if index<2 else 1.0)*(width-float(p.get("stroke_px",3.0)))*.5,0)
		part.position.x=xy.x*unit;part.position.y=xy.y*unit
		if i>=4:(part.material_override as StandardMaterial3D).albedo_color=colour

static func reload_mesh()->ArrayMesh:
	# Original circular-arrow glyph, observed inside empty Magnum/M60/DT11 cues.
	var unit:=1.0/(1147.17*.04);var segments:Array=[]
	for i in 28:
		var a:float=deg_to_rad(45.0+float(i)*285.0/28.0)
		var b:float=deg_to_rad(45.0+float(i+1)*285.0/28.0)
		segments.append([Vector2(cos(a),sin(a))*12.0,Vector2(cos(b),sin(b))*12.0])
	return line_mesh(segments,3.0,unit,[[Vector2(13,5),Vector2(4,6),Vector2(11,14)]])
