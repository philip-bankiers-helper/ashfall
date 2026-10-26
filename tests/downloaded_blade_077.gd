extends SceneTree
const Assets=preload("res://scripts/blade_assets.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	for kind in ["katana","excalibur","knife"]:
		var expected_base:=Vector3.ZERO;var expected_tip:=Vector3.ZERO
		for lightweight in [true,false]:
			ProjectSettings.set_setting("ashfall/lightweight_models",lightweight)
			var model:=Node3D.new();root.add_child(model);var built:Dictionary=Assets.build(model,kind)
			if lightweight:
				expected_base=built.base.position;expected_tip=built.tip.position
				check(not model.has_meta("downloaded_blade_077"),kind+" authored fallback retained and selected by Low-Poly")
				check(model.get_node("AuthoredBlade").visible,kind+" authored fallback is visible")
			else:
				var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_"+preload("res://scripts/model_variants.gd").choose(kind)+"/asset-provenance.json"))
				check(model.get_meta("downloaded_blade_077","")==kind,kind+" downloaded model selected")
				check(built.base.position==expected_base and built.tip.position==expected_tip,kind+" accepted collision endpoints exactly unchanged")
				check(built.grip==Assets.GRIP,kind+" accepted tracked primary grip exactly unchanged")
				check(not model.get_node("AuthoredBlade").visible and not model.get_node("GripCore").visible,kind+" old rendered blade and grip hidden")
				var mesh:Mesh=model.get_node("DownloadedBlade077").mesh
				check(mesh.get_surface_count()==1,kind+" all source finishes retained")
				var triangles:=0;var tip_distance:=INF
				var p:Array=data.get("target_pommel",data.target);var pommel:=Vector3(p[0],p[1],p[2])
				for surface in mesh.get_surface_count():
					var a:=mesh.surface_get_arrays(surface);var indices=a[Mesh.ARRAY_INDEX];triangles+=(indices.size() if indices!=null and not indices.is_empty() else a[Mesh.ARRAY_VERTEX].size())/3
					for v in a[Mesh.ARRAY_VERTEX]:tip_distance=minf(tip_distance,v.distance_to(expected_tip))
				check(triangles==int(data.get("visible_source_triangles",data.source_triangles)),kind+" all original source triangles retained exactly once")
				check(tip_distance<.001 and absf(mesh.get_aabb().position.y-pommel.y)<.001,kind+" actual tip and pommel end plane meet preserved datums")
				check(is_equal_approx(pommel.distance_to(expected_tip),float(data.target_chord)),kind+" final visible pommel-to-tip chord preserves calibrated length")
				check(mesh.get_aabb().size.x<.12 and mesh.get_aabb().size.y<1.43,kind+" no accidental import hierarchy scale multiplier")
				check(model.get_node("DownloadedBlade077").layers==1<<18,kind+" same live-weapon visibility layer")
			model.free()
	ProjectSettings.set_setting("ashfall/lightweight_models",null);await process_frame
	print("DOWNLOADED_BLADE_077 checks=",checks," failures=",failures," cpu_only=true headset_verified=false");quit(failures)
