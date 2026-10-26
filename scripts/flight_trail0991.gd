extends Node3D
## World history, local render vertices: bounded culling and a visible round cross-section in either XR eye.
const LENGTH:=3.0
const RADIUS:=.026
var history:Array[Vector3]=[]
var mesh:=ImmediateMesh.new()
var distance:=0.0
var visual:MeshInstance3D
func _ready()->void:
	top_level=true;global_transform=Transform3D.IDENTITY
	visual=MeshInstance3D.new();visual.name="WhiteElbowWake0991";visual.mesh=mesh;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.custom_aabb=AABB(Vector3.ONE*-3.15,Vector3.ONE*6.3);add_child(visual)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled=true;mat.emission=Color.WHITE;mat.emission_energy_multiplier=.25;visual.material_override=mat
func clear()->void:
	history.clear();distance=0;mesh.clear_surfaces()
func sample_point(point:Vector3,delta:float,enabled:bool,_min_speed:float=0)->void:
	if not enabled or not point.is_finite() or delta<=0 or delta>.5 or (not history.is_empty() and history[-1].distance_to(point)>2):clear();return
	global_position=point
	if history.is_empty():history.append(point);return
	var step:float=history[-1].distance_to(point)
	if step>=.015:history.append(point);distance+=step
	while history.size()>2 and distance-history[0].distance_to(history[1])>=LENGTH:
		distance-=history[0].distance_to(history[1]);history.pop_front()
	if distance>LENGTH and history.size()>1:history[0]=history[0].move_toward(history[1],distance-LENGTH);distance=LENGTH
	while history.size()>256:distance-=history[0].distance_to(history[1]);history.pop_front()
	mesh.clear_surfaces()
	if history.size()<2:return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var along:=0.0
	for i in range(1,history.size()):
		var a:=history[i-1]-point;var b:=history[i]-point;along+=a.distance_to(b)
		var intensity:=clampf(along/maxf(distance,.001),0,1)
		var axis:Vector3=(b-a).normalized();var side:=axis.cross(Vector3.UP).normalized()
		if side.length_squared()<.1:side=axis.cross(Vector3.RIGHT).normalized()
		var up:=axis.cross(side).normalized()
		for j in 6:
			var angle0:=TAU*j/6.0;var angle1:=TAU*(j+1)/6.0
			var offset0:Vector3=(side*cos(angle0)+up*sin(angle0))*RADIUS*intensity
			var offset1:Vector3=(side*cos(angle1)+up*sin(angle1))*RADIUS*intensity
			for vertex in [a+offset0,a+offset1,b+offset1,a+offset0,b+offset1,b+offset0]:
				mesh.surface_set_color(Color(1,1,1,.9*intensity));mesh.surface_add_vertex(vertex)
	mesh.surface_end()
