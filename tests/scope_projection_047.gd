extends SceneTree
const Scope=preload("res://scripts/longwatch_scope.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	for values in [Vector3(NAN,.16,2),Vector3(.024,NAN,2),Vector3(.024,.16,INF),Vector3(.024,-1,2),Vector3(-1,.16,2)]:
		check(is_finite(Scope.physical_lens_fov(values.x,values.y,values.z)) and Scope.physical_lens_fov(values.x,values.y,values.z)>=1,"invalid projection input uses finite valid nominal FOV")
	var far_actor=load("res://scripts/player.gd").new();root.add_child(far_actor);far_actor.setup(false);far_actor.set_process(false);far_actor.set_physics_process(false);far_actor.get_view_camera().position.z=500
	var unposed=load("res://scripts/precision_rifle.gd").new();root.add_child(unposed);unposed.setup(far_actor,false);unposed.set_process(false);unposed.set_physics_process(false)
	check(is_equal_approx(unposed.optic.scope_camera.fov,Scope.physical_lens_fov(.024,.16,2)),"unposed gun far from camera initializes valid nominal projection")
	unposed.optic.refresh_optic(.1)
	check(not unposed.optic.active and not unposed.get_displayed_optic_pose().valid,"far initial camera cannot activate or publish arbitrary projection")
	far_actor.get_view_camera().global_transform=Transform3D(unposed.optic.global_basis,unposed.optic.lens.global_position+unposed.optic.global_basis.z*.08)
	check(unposed.optic.simulate_displayed_frame_for_test() and absf(unposed.optic.scope_camera.fov-Scope.physical_lens_fov(.024,.08,2))<.0001,"first aligned frame replaces nominal FOV with true physical relief")
	unposed.shutdown();unposed.free();far_actor.free();await process_frame
	# This is a disabled headless viewport, used only for aspect/projection state.
	for size in [Vector2i(800,800),Vector2i(1280,720)]:
		var host:=SubViewport.new();host.size=size;host.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(host)
		var actor=load("res://scripts/player.gd").new();host.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
		for base_fov in [55.0,85.0]:
			actor.get_view_camera().fov=base_fov
			var gun=load("res://scripts/precision_rifle.gd").new();host.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			var optic=gun.optic;var camera:Camera3D=actor.get_view_camera()
			for relief in [.08,.16,.30]:
				camera.global_transform=Transform3D(optic.global_basis,optic.lens.global_position+optic.global_basis.z*relief)
				check(optic.simulate_displayed_frame_for_test(),"headless commit relief=%s fov=%s viewport=%s"%[relief,base_fov,size])
				var fov:float=optic.scope_camera.fov
				check(absf(fov-Scope.physical_lens_fov(.024,relief,2))<.0001,"scope FOV derives physical aperture/relief independently of main camera")
				for world_angle in [.01,.02]:
					# Perspective scene -> square UV -> physical lens -> apparent eye ray.
					var uv_offset:=tan(world_angle)/tan(deg_to_rad(fov)*.5)
					var lens_y:float=optic.LENS_RADIUS*uv_offset
					var apparent:=atan(lens_y/relief)
					check(absf(tan(apparent)/tan(world_angle)-2)<.0001,"projected world angular scale2x relief=%s angle=%s"%[relief,world_angle])
				check(optic.viewport.size==Vector2i(384,384) and optic.scope_camera.keep_aspect==Camera3D.KEEP_HEIGHT,"square optical projection preserves explicit vertical aperture")
				check(host.render_target_update_mode==SubViewport.UPDATE_DISABLED and optic.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"CPU proof never requests GPU render")
			gun.shutdown();gun.free();await process_frame
		actor.free();host.free();await process_frame
	# Engine multiview documents offsets in view space. Transform the offset as a
	# point, including camera rotation/translation; zero offset is the mono case.
	var camera_transform:=Transform3D(Basis(Vector3.UP,.7),Vector3(3,2,5))
	var center_eye:Vector3=camera_transform.origin
	var left_eye:Vector3=camera_transform*Vector3(-.032,0,0)
	var right_eye:Vector3=camera_transform*Vector3(.032,0,0)
	check(is_equal_approx(left_eye.distance_to(right_eye),.064),"documented view-space eye offsets preserve64mm IPD through camera yaw")
	check((left_eye-center_eye).dot(camera_transform.basis.x)<-.0319 and (right_eye-center_eye).dot(camera_transform.basis.x)>.0319,"stereo origins lie on correct rotated camera sides")
	check((camera_transform*Vector3.ZERO).is_equal_approx(center_eye),"mono zero eye offset preserves original camera origin")
	var reflex=load("res://scripts/authored_reflex_sight.gd").new();root.add_child(reflex)
	var owner=load("res://scripts/weapon.gd").new();root.add_child(owner)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false);owner.setup(actor,false);owner.set_process(false);owner.set_physics_process(false)
	reflex.reparent(owner.model);reflex.setup("window",Transform3D(Basis.IDENTITY,Vector3(0,0,-.4)),owner)
	var shader:String=reflex.collimated_dot.material_override.shader.code
	check(shader.contains("INV_VIEW_MATRIX*vec4(EYE_OFFSET,1.0)"),"production reflex shader transforms documented current-eye offset")
	check(not shader.contains("vec3 eye=INV_VIEW_MATRIX[3].xyz"),"center-only origin removed from stereo reflex shader")
	# CPU shader resource creation is structural evidence only, not GPU compilation.
	check(reflex.collimated_dot.material_override.shader is Shader,"spatial shader resource exists without pretending GPU validation")
	reflex.free();owner.shutdown();owner.free();actor.free();await create_timer(.2).timeout
	print("SCOPE_PROJECTION_047 checks=",checks," failures=",failures," gpu_rendered=false shader_gpu_compiled=false headset_tested=false")
	quit(failures)
