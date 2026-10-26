extends Node3D
## Arc-length history retains three metres at any flight speed.
const LENGTH:=3.0
var history:Array[Vector3]=[]
var mesh:=ImmediateMesh.new()
var distance:=0.0
func _ready()->void:
	top_level=true;global_transform=Transform3D.IDENTITY
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;visual.material_override=mat
func sample_point(point:Vector3,delta:float,enabled:bool,_min_speed:float=0)->void:
	if not enabled or not point.is_finite() or delta<=0 or delta>.15 or (not history.is_empty() and history[-1].distance_to(point)>2):
		history.clear();distance=0;mesh.clear_surfaces();return
	if history.is_empty():history.append(point);return
	var step:float=history[-1].distance_to(point)
	if step>=.015:
		history.append(point);distance+=step
	while history.size()>2 and distance-history[0].distance_to(history[1])>=LENGTH:
		distance-=history[0].distance_to(history[1]);history.pop_front()
	if distance>LENGTH and history.size()>1:
		history[0]=history[0].move_toward(history[1],distance-LENGTH);distance=LENGTH
	while history.size()>256:distance-=history[0].distance_to(history[1]);history.pop_front()
	mesh.clear_surfaces()
	if history.size()<2:return
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var length_so_far:=0.0
	for i in range(1,history.size()):
		var a:=history[i-1];var b:=history[i];length_so_far+=a.distance_to(b)
		var side:Vector3=(b-a).cross(camera.global_position-(a+b)*.5).normalized()
		if side.length_squared()<.001:side=camera.global_basis.x
		var intensity:=clampf(length_so_far/maxf(distance,.001),.0,1.0)
		var half:=side*.035*intensity
		for vertex in [a-half,a+half,b+half,a-half,b+half,b-half]:
			mesh.surface_set_color(Color(1,1,1,.88*intensity));mesh.surface_add_vertex(vertex)
	mesh.surface_end()
