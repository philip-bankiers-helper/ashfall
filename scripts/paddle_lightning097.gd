extends Node3D
## Local electrode corona follows each paddle during the five-second ready window.
var paddles:Array[Node3D]=[]
var mesh:=ImmediateMesh.new()
var age:=0.0
func setup(values:Array[Node3D])->void:
	paddles=values
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;visual.material_override=mat
func _process(delta:float)->void:
	if not is_visible_in_tree():return
	age+=delta;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for paddle in paddles:
		var rng:=RandomNumberGenerator.new();rng.seed=int(floor(age*28))*7919+int(paddle.get_instance_id())
		for strand in 12:
			var previous:=Vector3.ZERO
			var phase:=rng.randf()*TAU
			var sweep:=rng.randf_range(.7,1.6)*PI
			for j in 21:
				var t:=float(j)/20
				var a:=phase+t*sweep
				var jitter:=rng.randf_range(-.014,.014)
				var point:=Vector3(cos(a)*(.075+jitter),sin(a)*(.10+jitter),-.02+rng.randf_range(-.025,.025))
				point=paddle.to_global(point)
				if j>0:
					var side:=paddle.global_basis.y*.0018
					mesh.surface_set_color(Color.WHITE if strand%4==0 else Color("48baff"))
					for v in [previous-side,previous+side,point+side,previous-side,point+side,point-side]:mesh.surface_add_vertex(to_local(v))
				previous=point
	mesh.surface_end()
