extends Node3D
## Short, bounded original blue-white arcs at successful rescue contacts.
var remaining:=.55
var ends:Array[Vector3]=[]
var mesh:=ImmediateMesh.new()
var age:=0.0
func start(left:Vector3,right:Vector3,pads:Array)->void:
	ends.assign([left,pads[0],right,pads[1],pads[0],pads[1]])
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;visual.material_override=mat
	_draw()
func _process(delta:float)->void:
	age+=maxf(0,delta);remaining-=maxf(0,delta)
	if remaining<=0:queue_free();return
	_draw()
func _draw()->void:
	if ends.size()<4:return
	mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for path in ends.size()/2:
		var start:Vector3=ends[path*2];var finish:Vector3=ends[path*2+1];var direction:Vector3=(finish-start).normalized()
		var side:=direction.cross(Vector3.UP).normalized()
		if side.length_squared()<.001:side=Vector3.RIGHT
		for strand in 5:
			var previous:=start
			for segment in range(1,13):
				var t:=float(segment)/12
				var jitter:=sin(t*81+strand*7+floor(age*35)*11)*.045*sin(t*PI)
				var next:=start.lerp(finish,t)+side*jitter+Vector3.UP*cos(t*63+strand+floor(age*35)*13)*.02*sin(t*PI)
				var width:=side*(.003 if strand==0 else .0015)
				mesh.surface_set_color(Color(0.4,0.8,1.0,clampf(remaining/.2,0,1)) if strand else Color(1,1,1,clampf(remaining/.2,0,1)))
				for point in [previous-width,previous+width,next+width,previous-width,next+width,next-width]:mesh.surface_add_vertex(to_local(point))
				previous=next
	mesh.surface_end()
