extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func compositor_basis(optic:Node3D)->Basis:
	return Basis(optic._material.get_shader_parameter("view_right"),optic._material.get_shader_parameter("view_up"),-optic._material.get_shader_parameter("view_forward"))
func compositor_ray(optic:Node3D,p:Vector2)->Vector3:
	var frame:=compositor_basis(optic);var scale:float=optic._material.get_shader_parameter("angular_scale")
	return (frame*Vector3(p.x*scale,p.y*scale,-1)).normalized()
func stop_audio(node:Node)->void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:node.stop();node.stream=null
	for child in node.get_children():stop_audio(child)
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for index in [3,9,17,23]:
		var gun:Node3D=rack.weapons[index];var sight:Node3D=gun.get_meta("reflex_sight")
		check(sight!=null and sight.gun==gun,"actual rack nonmagnifying sight "+str(index))
		var size:Vector2=sight.window.mesh.size
		check(is_equal_approx(size.x*size.y,.039*.035*2),"clear window has exactly double prior AREA "+str(index))
		check(is_equal_approx(size.x/size.y,.039/.035),"clear window preserves aspect ratio "+str(index))
		check(sight.collimated_dot.mesh.size.is_equal_approx(size),"dynamic aiming aperture matches glass geometry "+str(index))
		check(is_equal_approx(sight._aim_material.get_shader_parameter("dot_radius"),.0007) and sight._aim_material.shader.code.contains("if(distance_to_aim>dot_radius) discard"),"solid disc dot and original radius retained "+str(index))
		check(sight.find_children("*","Camera3D",true,false).is_empty() and sight.find_children("*","SubViewport",true,false).is_empty(),"no nonmagnifying sight introduces camera or viewport "+str(index))
		for sign in [-1,1]:
			var eye:Vector3=sight.to_global(Vector3(0,0,.20));var point:Vector3=sight.collimated_dot.to_global(Vector3(sign*.026,sign*.023,0))
			var target:=eye+(point-eye)*100
			check(sight.project_target_to_lens(eye,target).valid,"newly exposed outer window remains aimable "+str(index)+" "+str(sign))
		var outside:Vector3=sight.collimated_dot.to_global(Vector3(size.x*.6,0,0));var eye:Vector3=sight.to_global(Vector3(0,0,.2))
		check(not sight.project_target_to_lens(eye,eye+(outside-eye)*100).valid,"outside enlarged glass clips projected dot "+str(index))
		if index==9:
			check(sight.style=="holographic" and sight.position.y>.13,"M10 actual rack owns raised protected holographic housing")
			check(sight.get_child_count()>8,"M10 housing includes hood, rail foot and side controls")
		if index==3:
			var eye_local:=Vector3(0,.115,.35);var lens_local:=Vector3(0,.115,-.096)
			var legacy_block:=AABB(Vector3(-.0375,.085,-.175),Vector3(.075,.06,.11))
			check(legacy_block.intersects_segment(eye_local,lens_local)!=null,"old MK18 solid optic placeholder blocks the real lens center")
			var foot:MeshInstance3D=gun.model.find_child("AuthoredReflexRailFoot",true,false)
			check(foot!=null and foot.mesh.get_aabb().intersects_segment(foot.to_local(gun.model.to_global(eye_local)),foot.to_local(gun.model.to_global(lens_local)))==null,"MK18 replacement rail foot clears the real lens center")
		var clone:Node3D=gun.model.duplicate(0);var inventory=load("res://scripts/weapon_inventory.gd").new();inventory._strip(clone)
		check(clone.find_child("DynamicReflexReticle",true,false)==null and clone.find_child("ClearSightWindow",true,false)!=null,"inert pickup keeps housing and strips active projected dot "+str(index))
		clone.free();inventory.free()
	for index in [0,21,25]:
		var gun:Node3D=rack.weapons[index];var sights:Node3D=gun.model.find_child("RingAndFrontDotSights",true,false)
		check(sights!=null,"CX4/AK/S85 actual rack has authored ring and front dot "+str(index))
		check(sights.find_child("RearAlignmentRing",true,false).mesh is TorusMesh and sights.find_child("SolidFrontDot",true,false).mesh is SphereMesh,"rear circle and separate solid front bead "+str(index))
		var bead:MeshInstance3D=sights.find_child("SolidFrontDot",true,false)
		var ring:MeshInstance3D=sights.find_child("FrontAlignmentRing",true,false)
		check((bead.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color(1,.045,.025)),"solid front bead retains accepted RED colour "+str(index))
		check(bead.material_override!=ring.material_override,"ring tint is independent of solid aiming dot "+str(index))
		check(gun.sight_front!=null and gun.sight_rear!=null,"existing physical sight reference hooks preserved "+str(index))
		var rear:Vector3=gun.model.to_local(gun.sight_rear.global_position);var front:Vector3=gun.model.to_local(gun.sight_front.global_position)
		var target:Vector3=sights.get_meta("bore_origin")+Vector3.FORWARD*float(sights.get_meta("zero_distance"))
		check((target-rear).normalized().dot((front-rear).normalized())>.9999999,"separate front bead zeros to unchanged firing bore at80m "+str(index))
		check(sights.find_children("*","Camera3D",true,false).is_empty(),"ring/front dot are physical geometry "+str(index))
	# Exercise the actual AWP compositor parameters, not only its scene cameras.
	var gun:Node3D=rack.weapons[5];var optic:Node3D=gun.optic
	gun.global_transform=Transform3D(Basis.from_euler(Vector3(.13,.43,0)),Vector3(4,3,-8));gun.model.basis=Basis(Vector3.FORWARD,.31)
	var recorded_rays:Array[Vector3]=[]
	var powers:Array[float]=[4.0,8.0]
	for power in powers:
		var unrolled:=Basis.from_euler(Vector3(.24,.63,0));var baseline:=Basis.IDENTITY
		for roll in [-1.25,-.6,0.0,.72,1.4]:
			gun.camera.global_transform=Transform3D(unrolled*Basis(Vector3.FORWARD,roll),Vector3(3,3,0))
			var head_before:Transform3D=gun.camera.global_transform
			optic.zoom_magnification=power;optic._commit_displayed_frame()
			var display:=compositor_basis(optic)
			check(absf(display.x.y)<.00001 and absf(optic.scope_camera.global_basis.x.y)<.00001,"AWP image and reticle axes use world horizon power=%s roll=%s"%[power,roll])
			check(gun.camera.global_transform.is_equal_approx(head_before),"AWP leveling never writes head pose")
			if roll==-1.25:
				baseline=display;recorded_rays.clear()
				for p in [Vector2.ZERO,Vector2(.6,.2),Vector2(-.2,.65)]:recorded_rays.append(compositor_ray(optic,p))
			else:
				check(display.is_equal_approx(baseline),"AWP rolled head cannot rotate compositor frame")
				for i in 3:check(compositor_ray(optic,[Vector2.ZERO,Vector2(.6,.2),Vector2(-.2,.65)][i]).distance_to(recorded_rays[i])<.000001,"AWP environment landmark and reticle world rays invariant under head roll "+str(i))
			var scale:float=optic._material.get_shader_parameter("angular_scale")
			check(is_equal_approx(scale/tan(deg_to_rad(optic.scope_camera.fov)*.5),power),"AWP preserved4x/8x angular magnification math")
			check(optic.scope_camera.global_transform.is_equal_approx(optic.right_scope_camera.global_transform),"AWP both eyes retain same collimated optical image")
			check(optic.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and optic.right_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"CPU test requests no GPU frame")
	for forward in [Vector3.UP,Vector3.DOWN,Vector3(.00001,1,0).normalized()]:check(optic.world_level_basis(forward).is_finite(),"AWP pole fallback is finite and independent of head roll")
	check(gun.SIGHT_DROP_DEGREES==2.5 and gun.magazine_size==3,"AWP praised reload capacity and firing calibration unchanged")
	rack.shutdown();stop_audio(rack);stop_audio(actor);rack.free();actor.free();await create_timer(.2).timeout
	print("OPTICS_062 checks=",checks," failures=",failures," gpu_rendered=false actual_xr_multiview=false headset_tested=false")
	quit(failures)
