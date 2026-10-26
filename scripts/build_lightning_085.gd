extends MeshInstance3D
##088 Ten irregular ribbons around the hand's straight aim ray, with depth testing.
const STRAND_COUNT:=10
const HALF_WIDTH:=.004 # Twice087 width:8mm full ribbon.
const MAX_PERIOD_M:=.4572
var points:=PackedVector3Array()
var strands:Array[PackedVector3Array]=[]
var strand_colors:Array[Color]=[]
var strand_spacings:Array[PackedFloat32Array]=[]
func _init()->void:
	name="BuildLightning088";cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh=ImmediateMesh.new()
	var finish:=StandardMaterial3D.new();finish.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;finish.albedo_color=Color.WHITE;finish.vertex_color_use_as_albedo=true;finish.cull_mode=BaseMaterial3D.CULL_DISABLED;material_override=finish
func _noise(strand:int,knot:int,tick:int)->Vector2:
	var rng:=RandomNumberGenerator.new();rng.seed=88217+strand*15737+knot*379+tick*577
	return Vector2(rng.randf_range(-1,1),rng.randf_range(-1,1))
func update_bolt(start:Vector3,end:Vector3,enabled:bool)->void:
	visible=enabled;points.clear();strands.clear();strand_colors.clear();strand_spacings.clear();(mesh as ImmediateMesh).clear_surfaces()
	if not enabled or not start.is_finite() or not end.is_finite():visible=false;return
	var ray:=end-start
	if ray.length()<.0001:visible=false;return
	var axis:=ray.normalized();var side:=axis.cross(Vector3.UP)
	if side.length_squared()<.001:side=axis.cross(Vector3.RIGHT)
	side=side.normalized();var up:=side.cross(axis).normalized()
	var clock:=float(Time.get_ticks_msec())*.006;var tick:=floori(clock);var blend:=smoothstep(0,1,fposmod(clock,1))
	#087 used12 nodes with2.4rad angular advance. Keep that short-scale reference,
	# bounded below18in so the new random intervals have a useful mixed range.
	var minimum_period:=clampf(ray.length()*TAU/(12.0*2.4),.025,MAX_PERIOD_M*.5)
	var immediate:=mesh as ImmediateMesh;immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in STRAND_COUNT:
		var color:=Color("58ff44") if strand<6 else (Color("050706") if strand<8 else Color.WHITE)
		strand_colors.append(color)
		var spacing:=PackedFloat32Array();var rng:=RandomNumberGenerator.new();rng.seed=88271+strand*1471
		var path:=PackedVector3Array([start]);var distance:=0.0;var knot:=0
		while distance<ray.length():
			var step:=minf(rng.randf_range(minimum_period,MAX_PERIOD_M),ray.length()-distance);distance+=step;spacing.append(step)
			var t:=distance/ray.length();var envelope:=minf(1,minf(t,1-t)*6)
			var irregular:=_noise(strand,knot,tick).lerp(_noise(strand,knot,tick+1),blend)
			var offset:Vector3=(side*irregular.x+up*irregular.y)*minf(.12,ray.length()*.075)*envelope
			path.append(end if distance>=ray.length()-.00001 else start+axis*distance+offset);knot+=1
		strands.append(path);strand_spacings.append(spacing)
		immediate.surface_set_color(color)
		for i in range(1,path.size()):
			for width in [side*HALF_WIDTH,up*HALF_WIDTH]:
				for vertex in [path[i-1]-width,path[i-1]+width,path[i]+width,path[i-1]-width,path[i]+width,path[i]-width]:immediate.surface_add_vertex(to_local(vertex))
	points=strands[0];immediate.surface_end()
