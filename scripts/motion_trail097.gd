extends Node3D
## Bounded world-space history. Teleports, tracking loss and pauses clear it.
var history:Array[Dictionary]=[]
var duration:=.3
var width:=.025
var ink:=Color.WHITE
var mesh:=ImmediateMesh.new()
var previous:=Vector3.ZERO
var have_previous:=false
func setup(color:Color,seconds:float,radius:float)->void:
	ink=color;duration=seconds;width=radius;top_level=true;global_transform=Transform3D.IDENTITY
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;visual.material_override=mat
func sample_point(point:Vector3,delta:float,enabled:bool,min_speed:float)->void:
	if not enabled or not point.is_finite() or delta<=0 or delta>.15 or (have_previous and previous.distance_to(point)>2):
		history.clear();mesh.clear_surfaces();have_previous=false;return
	for sample in history:sample.age+=delta
	while not history.is_empty() and history[0].age>duration:history.pop_front()
	if have_previous and previous.distance_to(point)>.001 and previous.distance_to(point)/delta>=min_speed:history.append({"point":point,"age":0.0})
	previous=point;have_previous=true
	while history.size()>64:history.pop_front()
	mesh.clear_surfaces()
	if history.size()<2:return
	var camera:=get_viewport().get_camera_3d()
	if camera==null:return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,history.size()):
		var a:Vector3=history[i-1].point;var b:Vector3=history[i].point
		var side:Vector3=(b-a).cross(camera.global_position-(a+b)*.5).normalized()
		if side.length_squared()<.001:side=camera.global_basis.x
		var wa:Vector3=side*width*.5*(1-history[i-1].age/duration)
		var wb:Vector3=side*width*.5*(1-history[i].age/duration)
		for v in [a-wa,a+wa,b+wb,a-wa,b+wb,b-wb]:
			var color:=ink;color.a=.72*(1-history[i-1].age/duration);mesh.surface_set_color(color);mesh.surface_add_vertex(v)
	mesh.surface_end()
