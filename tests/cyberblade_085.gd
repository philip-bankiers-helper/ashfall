extends SceneTree
const Assets=preload("res://scripts/blade_assets.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	ProjectSettings.set_setting("ashfall/lightweight_models",true)
	var fallback:=Node3D.new();root.add_child(fallback);var original:Dictionary=Assets.build(fallback,"cyberblade")
	var base:Vector3=original.base.position;var tip:Vector3=original.tip.position
	check(not fallback.has_meta("downloaded_blade_077") and fallback.get_node("AuthoredBlade").visible,"original Low-Poly preserved")
	fallback.free();ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var model:=Node3D.new();root.add_child(model);var built:Dictionary=Assets.build(model,"cyberblade")
	var drawn:MeshInstance3D=model.get_node("DownloadedBlade077");var mesh:Mesh=drawn.mesh
	check(model.get_meta("downloaded_model_variant_082","")=="katana","Genji is Cyber Blade per latest correction")
	check(not ResourceLoader.has_cached("res://assets/models/download_cyberblade/model.glb"),"rejected gold source not loaded")
	check(built.base.position==base and built.tip.position==tip and built.grip==Assets.GRIP,"accepted endpoints/grip unchanged")
	check(not model.get_node("AuthoredBlade").visible,"old authored drawing hidden")
	check(mesh.get_surface_count()==4,"four original Genji finishes retained")
	var triangles:=0;var finite:=true;var tip_distance:=INF;var pommel_distance:=INF
	var pommel:=Vector3(0,Assets.GRIP.y-Assets.PRIMARY_POMMEL_DISTANCE,.025)
	for surface in mesh.get_surface_count():
		var a:=mesh.surface_get_arrays(surface);var indices=a[Mesh.ARRAY_INDEX];triangles+=(indices.size() if indices!=null and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
		for n in a[Mesh.ARRAY_NORMAL]:finite=finite and n.is_finite() and absf(n.length()-1)<.02
		for v in a[Mesh.ARRAY_VERTEX]:
			var actual:Vector3=drawn.transform*v;finite=finite and actual.is_finite();tip_distance=minf(tip_distance,actual.distance_to(tip));pommel_distance=minf(pommel_distance,actual.distance_to(pommel))
	check(triangles==3972,"all3972 Genji triangles retained")
	check(finite,"positions and normals finite/unit")
	check(tip_distance<.001,"transformed visible tip meets Cyber collision tip")
	check(pommel_distance<.02,"transformed pommel meets accepted datum")
	check(is_equal_approx(pommel.distance_to(tip),Assets.SWORD_LENGTH),"accepted full sword chord unchanged")
	check(drawn.basis.get_scale().is_equal_approx(Vector3.ONE),"endpoint rotation without length scaling")
	check(drawn.get_meta("long_axis_roll_degrees_084")==180,"long-axis face reversal preserved")
	check((drawn.transform*Assets.GRIP).distance_to(Assets.GRIP)<.025,"handle within2.5cm of accepted grip")
	var second:=Node3D.new();root.add_child(second);Assets.build(second,"cyberblade")
	check(second.get_node("DownloadedBlade077").mesh==mesh,"instances reuse source geometry")
	check(drawn.layers==1<<18,"live visibility layer")
	check(not model.get_node("GripCore").visible,"old handle not layered over Genji")
	second.free();model.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await process_frame
	print("DOWNLOADED_CYBERBLADE_080 checks=",checks," failures=",failures," geometry_only=true headset_verified=false");quit(failures)
