extends Node3D
## Short white ribbon swept by both blade edges on Cyberblade and Excalibur.
var history:Array[Dictionary]=[]
var mesh:=ImmediateMesh.new()
var trail_color:=Color.WHITE
const DURATION:=.14/3.0
func _ready()->void:
	top_level=true;global_transform=Transform3D.IDENTITY
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;visual.material_override=mat
func sample_blade(base:Vector3,tip:Vector3,delta:float,enabled:bool)->void:
	if not enabled or delta<=0 or delta>.15 or not base.is_finite() or not tip.is_finite():
		history.clear();mesh.clear_surfaces();return
	for entry in history:entry.age+=delta
	while not history.is_empty() and history[0].age>DURATION:history.pop_front()
	if not history.is_empty() and history[-1].tip.distance_to(tip)>2:history.clear()
	if history.is_empty() or history[-1].tip.distance_to(tip)/delta>=.5:history.append({"base":base,"tip":tip,"age":0.0})
	while history.size()>24:history.pop_front()
	mesh.clear_surfaces()
	if history.size()<2:return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,history.size()):
		var a:Dictionary=history[i-1];var b:Dictionary=history[i]
		for vertex in [a.base,a.tip,b.tip,a.base,b.tip,b.base]:
			mesh.surface_set_color(Color(trail_color.r,trail_color.g,trail_color.b,.58*(1-float(a.age)/DURATION)));mesh.surface_add_vertex(vertex)
	mesh.surface_end()
