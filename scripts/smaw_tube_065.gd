extends RefCounted
## Original visual manufacture. This cup-shaped shell has an open loading bore.
## All dimensions here are authored; none change loading targets or collisions.
const SIDES:=16
const AXIS_Y:=.045
const BORE_RADIUS:=.048
const OUTER_RADIUS:=.055
const BORE_REAR_Z:=.19
const OUTER_REAR_Z:=.20
const LIP_FRONT_Z:=-.839

static func _point(profile:Vector2,angle:float)->Vector3:
	return Vector3(cos(angle)*profile.x,AXIS_Y+sin(angle)*profile.x,profile.y)

static func _strip(parent:Node3D,label:String,profile:Array[Vector2],finish:Material)->MeshInstance3D:
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(1,profile.size()):
		var a:Vector2=profile[row-1];var b:Vector2=profile[row]
		var normal:=Vector2(a.y-b.y,b.x-a.x).normalized()
		for side in SIDES:
			var angles:=[TAU*side/SIDES,TAU*(side+1)/SIDES]
			for samples in [[[0,0],[0,1],[1,1]],[[0,0],[1,1],[1,0]]]:
				var points:Array[Vector3]=[];var normals:Array[Vector3]=[]
				for sample in samples:
					var p:Vector2=a if sample[0]==0 else b;var angle:float=angles[sample[1]]
					points.append(_point(p,angle));normals.append(Vector3(cos(angle)*normal.x,sin(angle)*normal.x,normal.y))
				var cross:Vector3=(points[1]-points[0]).cross(points[2]-points[0])
				if cross.length_squared()<1e-16:continue
				# Godot's front-facing triangles are clockwise.
				var order:=[0,2,1] if cross.dot(normals[0])>0 else [0,1,2]
				for index in order:surface.set_normal(normals[index]);surface.add_vertex(points[index])
	surface.index()
	var mesh:=MeshInstance3D.new();mesh.name=label;mesh.mesh=surface.commit();mesh.material_override=finish;parent.add_child(mesh)
	return mesh

static func build(payload:Node3D,alloy:Material,band:Material)->Node3D:
	var root:=Node3D.new();root.name="OriginalSmawTube065";payload.add_child(root)
	root.set_meta("authored_bore_radius",BORE_RADIUS);root.set_meta("bore_rear_z",BORE_REAR_Z)
	var inner:=StandardMaterial3D.new();inner.albedo_color=Color("182024");inner.metallic=.10;inner.roughness=.85
	# Preserve the 16-sided outer tube radius and original rear face at +.20.
	_strip(root,"TubeExterior",[Vector2(OUTER_RADIUS,OUTER_REAR_Z),Vector2(OUTER_RADIUS,-.821)],alloy)
	_strip(root,"TubeRearExterior",[Vector2(0,OUTER_REAR_Z),Vector2(OUTER_RADIUS,OUTER_REAR_Z)],alloy)
	# A bevelled annular lip stays inside the old .059 radial / +-.009 axial rim envelope.
	_strip(root,"OpenLoadingLip",[Vector2(.055,-.821),Vector2(.059,-.825),Vector2(.059,-.834),Vector2(.054,LIP_FRONT_Z),Vector2(.049,LIP_FRONT_Z),Vector2(BORE_RADIUS,-.836),Vector2(BORE_RADIUS,-.821)],band)
	# The long inner wall is continuous through both collar positions. The rear
	# plate closes the cavity at +.19, leaving the original outside rear at +.20.
	_strip(root,"BoreWallAndRear",[Vector2(BORE_RADIUS,-.821),Vector2(BORE_RADIUS,BORE_REAR_Z),Vector2(0,BORE_REAR_Z)],inner)
	for z in [.17,-.65]:
		_strip(root,"AnnularTubeCollar",[Vector2(.067,z),Vector2(.067,z-.04),Vector2(OUTER_RADIUS,z-.04),Vector2(OUTER_RADIUS,z),Vector2(.067,z)],band)
	return root
