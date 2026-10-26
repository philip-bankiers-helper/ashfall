extends SceneTree
const Ballistics=preload("res://scripts/ballistic_query.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;print("FAIL ",label)
func hit(marks:Node3D,from:Vector3,to:Vector3,label:String)->void:
	var ray:Dictionary=root.get_world_3d().direct_space_state.intersect_ray(Ballistics.create(self,from,to,[],1|8))
	check(not ray.is_empty(),label+" has exact visible collision")
	if ray.is_empty():return
	check(not ray.collider.is_in_group("stair_support"),label+" excludes invisible comfort slope")
	check(marks.add_hit(ray.position,ray.normal,ray.collider),label+" renders independent bullet hole")
func run()->void:
	var world=load("res://scripts/world.gd").new();root.add_child(world);world._make_materials()
	world._stairs(Vector3.ZERO,6,.2,.5,3)
	world._platform(Vector3(8,2,0),Vector3(4,.4,4))
	world._rail(Vector3(15,0,0),4,false)
	world._mountain(Vector3(30,0,0),6,4,0)
	world._flush_batches()
	var marks=load("res://scripts/impact_marks.gd").new();root.add_child(marks);marks.set_process(false)
	await physics_frame;await physics_frame
	for i in 6:
		var point:=Vector3(0,.2*(i+1),-(i*.5+.25))
		await hit(marks,point+Vector3.UP*.4,point-Vector3.UP*.2,"stair tread"+str(i))
		point.z+=.15
		await hit(marks,point+Vector3.UP*.4,point-Vector3.UP*.2,"unpainted stair tread"+str(i))
	for x in [6.15,7.0,8.0,9.0,9.85]:await hit(marks,Vector3(x,3,0),Vector3(x,1,0),"catwalk top "+str(x))
	for x in [13.0,13.5,14.0,15.0,16.0,16.5,17.0]:
		await hit(marks,Vector3(x,1.7,0),Vector3(x,.7,0),"rail top "+str(x))
		await hit(marks,Vector3(x,1,.6),Vector3(x,1,-.6),"rail side "+str(x))
	# A main-game protection query contains mission controls, never loot positions.
	var main=load("res://scripts/main.gd").new()
	check(main._construction_protected_targets().is_empty(),"unloaded mission protection has no loot clearance targets");main.free()
	var mountain:Node3D=world.get_node("Mountain_00")
	check(mountain.mesh.get_faces().size()>64*64*6,"terrain has closed skirt/underside triangles")
	check(mountain.mesh.surface_get_material(0).shader.code.contains("cull_disabled"),"terrain backfaces stay opaque")
	var prop:=MeshInstance3D.new();prop.mesh=BoxMesh.new();prop.material_override=StandardMaterial3D.new();prop.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	world.add_child(prop);world._opaque_terrain_faces_089(prop)
	check(prop.get_active_material(0).transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and prop.get_active_material(0).cull_mode==BaseMaterial3D.CULL_DISABLED,"imported boundary rock faces opaque both sides")
	print("SURFACES_089 checks=",checks," failures=",failures," actual_physics=true xr_runtime=off")
	world.free();marks.free();await process_frame;quit(0 if failures==0 else 1)
