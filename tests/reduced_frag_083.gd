extends SceneTree
class Sandbox extends Node3D:
	var player:Node3D
	var complete:=false
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func triangles(mesh:Mesh)->int:
	var count:=0
	for surface in mesh.get_surface_count():
		var indices=mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		count+=(indices.size() if indices!=null and not indices.is_empty() else mesh.surface_get_array_len(surface))/3
	return count
func run()->void:
	var finish=load("res://scripts/explosive_finish_064.gd")
	var holder:=Node3D.new();root.add_child(holder)
	ProjectSettings.set_setting("ashfall/lightweight_models",true);ProjectSettings.set_setting("ashfall/model_alternatives",true)
	var authored:Node3D=finish.grenade(holder,"frag")
	check(not authored.has_meta("downloaded_grenade_079") and not ResourceLoader.has_cached("res://assets/models/download_frag_alt/model.glb"),"Low-Poly avoids red frag import even with alternatives requested")
	authored.free();ProjectSettings.set_setting("ashfall/lightweight_models",false);ProjectSettings.set_setting("ashfall/model_alternatives",false)
	var original:Node3D=finish.grenade(holder,"zone");var original_mesh:Mesh=original.get_node("DownloadedGrenade079").mesh
	check(triangles(original_mesh)==2434 and original.get_meta("downloaded_model_variant_082")=="frag","sci-fi source now belongs to zone grenade")
	ProjectSettings.set_setting("ashfall/model_alternatives",true)
	var held:Node3D=finish.grenade(holder,"frag");var mesh:Mesh=held.get_node("DownloadedGrenade079").mesh
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/download_frag_alt/asset-provenance.json"))
	check(held.get_meta("downloaded_model_variant_082")=="frag_alt" and mesh!=original_mesh,"normal frag selects independent cached red grenade")
	check(triangles(mesh)==34634 and int(data.source_triangles)==277095 and int(data.body_triangles)+int(data.decimated_triangles)==277095,"exact reduced triangle and source accounting")
	check(float(triangles(mesh))/int(data.source_triangles)<.13,"triangle count reduced by more than87percent")
	check(float(data.maximum_source_vertex_displacement_m)<.0023 and float(data.rms_source_vertex_displacement_m)<.0008,"recorded clustering displacement bound under2.3mm and RMS under.8mm")
	check(absf(mesh.get_aabb().size.y-.14)<.00001 and held.scale.is_equal_approx(Vector3.ONE*.9),"final14cm held art with no double scaling")
	check(mesh.get_surface_count()==1 and mesh.surface_get_material(0).albedo_texture!=null and mesh.surface_get_material(0).roughness_texture!=null,"source PBR albedo and metallic/roughness textures retained")
	var normals_ok:=true;var finite:=true
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		for n in arrays[Mesh.ARRAY_NORMAL]:normals_ok=normals_ok and n.is_finite() and absf(n.length()-1)<.02
		for p in arrays[Mesh.ARRAY_VERTEX]:finite=finite and p.is_finite()
	check(normals_ok and finite,"all imported reduced positions finite and normals normalized")
	var duplicate:=held.duplicate();holder.add_child(duplicate)
	check(duplicate.get_node("DownloadedGrenade079").mesh==mesh,"inert pickup clone shares reduced cached mesh")
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var game:=Sandbox.new();game.player=actor;root.add_child(game)
	for side in ["right","left"]:
		actor.dominant_hand=side
		var projectile=load("res://scripts/explosive_projectile.gd").new();root.add_child(projectile);projectile.setup(game,{"kind":"frag","origin":Vector3(3,2,1),"velocity":Vector3(1,2,3)});projectile.set_physics_process(false)
		var art:Node3D=projectile.get_node("DownloadedGrenadeArt079")
		check(art.get_node("DownloadedGrenade079").mesh==mesh,side+" real projectile and held model share reduced mesh")
		check(art.scale.is_equal_approx(Vector3.ONE*(.035/.047)*.9),side+" original projectile art ratio retained")
		var collision:CollisionShape3D
		for child in projectile.get_children():
			if child is CollisionShape3D:collision=child
		check(collision!=null and is_equal_approx(collision.shape.radius,.035) and projectile.continuous_cd,side+" same real spherical collider and continuous collision")
		check(projectile.linear_velocity==Vector3(1,2,3) and is_equal_approx(projectile.gravity_scale,1.0) and is_equal_approx(projectile.mass,.35),side+" unchanged trajectory physics and mass")
		projectile.warning_sound.stop();projectile.free()
	var zone:Node3D=finish.grenade(holder,"zone");check(zone.get_node("DownloadedGrenade079").mesh==original_mesh and zone.get_meta("art_profile")=="zone","zone consistently retains sci-fi art")
	ProjectSettings.set_setting("ashfall/model_alternatives",false);var restored:Node3D=finish.grenade(holder,"zone");check(restored.get_node("DownloadedGrenade079").mesh==original_mesh,"return to defaults preserves exact sci-fi zone cached source")
	game.free();actor.free();holder.free();ProjectSettings.set_setting("ashfall/lightweight_models",null);ProjectSettings.set_setting("ashfall/model_alternatives",null);await create_timer(.2).timeout
	print("REDUCED_FRAG_083 checks=",checks," failures=",failures," cpu_only=true xr_off=true headset_verified=false");quit(failures)
