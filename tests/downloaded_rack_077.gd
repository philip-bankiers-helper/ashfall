extends SceneTree
const IDS={2:"px4",17:"mp5",18:"mp9",20:"tec9",23:"rfb",24:"fal"}
const BLADES={14:"katana",15:"excalibur",29:"knife"}
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func clear_body(mesh:Mesh,a:Vector3,b:Vector3)->bool:
	var faces:=mesh.get_faces()
	for i in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(a,b,faces[i],faces[i+1],faces[i+2])!=null:return false
	return true
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for lightweight in [true,false]:
		ProjectSettings.set_setting("ashfall/lightweight_models",lightweight)
		var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
		for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
		for index in IDS:
			var gun=rack.weapons[index];var id:String=IDS[index]
			check(gun.has_meta("downloaded_model_077")!=lightweight,id+" actual production rack chooses requested quality mode")
			if lightweight:
				check(not ResourceLoader.has_cached("res://assets/models/download_"+id+"/model.glb"),id+" lightweight startup avoids downloaded mesh/textures")
			else:
				check(rack.select_inventory_weapon(index) and rack.selected==index and gun.visible,id+" actual equipment selection displays imported instance")
				check(gun.get_meta("one_star_profile",{}).id==id,id+" accepted handling profile remains attached")
				if id in ["mp5","rfb"]:
					var sight:Node3D=gun.get_meta("reflex_sight");var body:MeshInstance3D=gun.model.get_node("DownloadedBody077")
					check(sight.position.y>body.mesh.get_aabb().end.y,id+" reflex window clears imported receiver and old iron sights")
					check(clear_body(body.mesh,Vector3(0,sight.position.y,.2),Vector3(0,sight.position.y-.002,-.8)),id+" actual optical corridor does not intersect imported triangles")
					check(gun.allows_world_reticle(),id+" existing alignment-driven reticle suppression contract retained")
		for index in BLADES:
			var gun=rack.weapons[index];var kind:String=BLADES[index]
			check(gun.model.has_meta("downloaded_blade_077")!=lightweight,kind+" actual melee rack chooses requested quality mode")
			if lightweight:check(not ResourceLoader.has_cached("res://assets/models/download_"+kind+"/model.glb"),kind+" fallback avoids downloaded asset load")
			else:check(rack.select_inventory_weapon(index) and gun.model.get_node("DownloadedBlade077").visible,kind+" production selection displays imported blade")
		rack.shutdown();rack.free()
	actor.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);await create_timer(.2).timeout
	print("DOWNLOADED_RACK_077 checks=",checks," failures=",failures," actual_production_rack=true xr_off=true headset_verified=false");quit(failures)
