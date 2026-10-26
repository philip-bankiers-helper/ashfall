extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var game:Node3D=load("res://scripts/main.gd").new();root.add_child(game)
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	game.set_process(false)
	check(game.front_menu.selected_map=="range","scope launcher preselects practice range")
	game._start_from_title()
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	check(game.has_node("StandaloneSandboxRange091") and game.weapon.selected==13,"Ready enters range with SPR in hand")
	check(game.weapon_inventory.has_weapon(13) and game.weapon_inventory.total_slots()<=6,"SPR ownership uses existing six-slot inventory")
	var gun:Node3D=game.weapon.weapons[13];var optic:Node3D=gun.optic
	check(optic.scale.is_equal_approx(Vector3.ONE) and optic.position.is_zero_approx(),"scope uses donor model coordinates without old riser transform")
	check(gun.model.find_child("RectangularSPRScopeMount084",true,false)==null and gun.model.find_child("SPRClampedOpticRiser088",true,false)==null,"old stacked riser removed")
	check(not gun.model.find_child("SPROpenOpticHood064",true,false).visible,"old lightweight scope hood is disabled")
	check(optic.lens.position.is_equal_approx(Vector3(0,.098,.0185)),"live aperture at authored ocular location")
	check(optic.lens.mesh.size.is_equal_approx(Vector2(.044,.026)),"live aperture matches compact model")
	check(optic.lens.name=="DynamicScopeLens","inert pickup stripping still recognizes live lens")
	check(optic.right_viewport!=null and optic.right_scope_camera!=null,"complete stereo viewport implementation retained")
	for variant in ["pcvr","light"]:
		var scene:PackedScene=load("res://assets/models/gemini_scope098/spr_scope_"+variant+".glb")
		var item:Node3D=scene.instantiate();root.add_child(item)
		for name in ["ScopeMount","ScopeHousing","ScopeDarkInterior","FrontObjectiveGlass","RearOcularGlass","ReticleViewPlane"]:
			check(item.find_child(name,true,false)!=null,"named part "+variant+" "+name)
		item.queue_free()
	check(not optic.compact_housing098.find_child("ReticleViewPlane",true,false).visible,"static placeholder cannot cover live scope texture")
	gun.global_transform=Transform3D(Basis.IDENTITY,Vector3(200,4,0))
	var camera:Camera3D=game.player.get_view_camera();camera.global_transform=Transform3D(optic.global_basis.orthonormalized(),optic.lens.global_position+optic.global_basis.z.normalized()*.20)
	await physics_frame
	check(optic.alignment_allowed(),"new low optical center acquires head alignment")
	check(optic.simulate_displayed_frame_for_test(),"new aperture commits real stereo firing snapshot")
	optic.refresh_optic(0)
	check(not optic.compact_housing098.find_child("RearOcularGlass",true,false).visible,"live view hides static rear glass")
	for roll in [-1.0,0.0,.7]:
		gun.global_basis=Basis.from_euler(Vector3(.1,.2,roll))
		for eye_offset in [-.03,0,.03]:
			camera.global_transform=Transform3D(gun.global_basis,optic.lens.global_position+gun.global_basis*Vector3(eye_offset,0,.20))
			optic._commit_displayed_frame()
			var pose:Transform3D=optic._displayed_pose;var forward:Vector3=-pose.basis.z
			check((optic.reticle_world_center()-pose.origin).cross(forward).length()<.0001,"reticle stays on firing line across eye offset / roll")
			check(absf((optic.reticle_world_center()-optic.lens.global_position).dot(forward)-1)<.001,"fixed one-metre virtual reticle")
	var before:int=gun.ammo;gun.cooldown=0;gun._semi_armed=true;gun.fire()
	check(gun.ammo==before-1,"SPR still discharges")
	gun.cooldown=0;gun.fire();check(gun.ammo==before-1,"held semi-auto trigger cannot discharge twice")
	check(gun.charging_grip_point().y>.06 and absf(gun.charging_grip_point().x)<.003,"real rear T-handle remains reload target")
	var prop:Node3D=game.weapon_inventory._create_prop(13)
	check(prop.find_child("GeminiCompactSPRScope098",true,false)!=null,"ground gun retains Gemini housing")
	check(prop.find_child("RearOcularGlass",true,false).visible,"inert copy restores static glass even when live scope was active")
	check(prop.find_child("DynamicScopeLens",true,false)==null and prop.find_children("*","SubViewport",true,false).is_empty(),"ground gun stays inert")
	prop.queue_free()
	camera.global_position+=Vector3.UP*.5
	check(not optic.alignment_allowed(),"unrelated head location cannot activate compact optic")
	optic.shutdown();check(optic.compact_housing098.find_child("RearOcularGlass",true,false).visible,"stowing restores static ocular glass")
	game.queue_free();await process_frame;await process_frame
	print("SCOPE_098 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false");quit(failures)
