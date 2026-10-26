extends SceneTree
class StereoAWP extends "res://scripts/awp_scope.gd":
	func get_eye_poses()->Array[Transform3D]:
		return [gun.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(-.032,0,0)),gun.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(.032,0,0))]
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var gun=load("res://scripts/precision_rifle.gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
	var old=gun.optic;old.shutdown();old.viewport.free();old.right_viewport.free();old.free()
	var optic:=StereoAWP.new();gun.model.add_child(optic);optic.setup(gun);gun.optic=optic
	check(optic._material.render_priority==Material.RENDER_PRIORITY_MAX and optic._material.shader.code.contains("ALPHA=1.0"),"AWP screen compositor uses final transparency priority after scene geometry")
	check(optic._material.shader.code.contains("projected.xyz/projected.w-EYE_OFFSET"),"AWP current-eye unprojection subtracts combined-camera eye offset")
	var direct:=Camera3D.new();root.add_child(direct);direct.keep_aspect=Camera3D.KEEP_HEIGHT;direct.fov=80
	for roll in [-1.2,0.0,.8]:
		gun.global_transform=Transform3D(Basis(Vector3.UP,.4),Vector3(2,3,-5));gun.model.basis=Basis(Vector3.FORWARD,roll)
		gun.camera.global_transform=Transform3D(gun.global_basis,gun.global_position+gun.global_basis*Vector3(.03,.15,.2))
		for power in [4.0,8.0]:
			optic.zoom_magnification=power;optic._commit_displayed_frame()
			check(absf(optic.scope_camera.global_basis.x.y)<.00001,"AWP horizon remains level despite gun roll and lower pitch calibration")
			check(optic.scope_camera.global_basis.is_equal_approx(optic.right_scope_camera.global_basis),"AWP left/right views stay parallel")
			check(optic.scope_camera.global_transform.is_equal_approx(optic.right_scope_camera.global_transform),"AWP binocular scene uses identical angular image rather than magnifying IPD disparity")
			check((optic._material.get_shader_parameter("aim_left") as Vector2)==Vector2.ZERO and (optic._material.get_shader_parameter("aim_right") as Vector2)==Vector2.ZERO,"reticle is centered at infinite convergence in both eyes")
			check(rad_to_deg((-gun.get_shot_transform().basis.z).angle_to(-gun.model.global_basis.z))>2.49 and rad_to_deg((-gun.get_shot_transform().basis.z).angle_to(-gun.model.global_basis.z))<2.51,"lower calibration changes actual firing direction by2.5degrees")
			var target:Vector3=optic._displayed_pose.origin-optic._displayed_pose.basis.z*180
			for index in 2:
				var camera:Camera3D=optic.scope_camera if index==0 else optic.right_scope_camera
				check(camera.global_transform.is_equal_approx(optic._displayed_pose),"AWP optical image is collimated with displayed firing pose for both eyes")
				var uv:Vector2=camera.unproject_position(target)/Vector2(optic.viewport.size)
				var expected_aim:=Vector2(uv.x*2-1,1-uv.y*2)
				var aim:Vector2=optic._material.get_shader_parameter("aim_left" if index==0 else "aim_right")
				check(expected_aim.distance_to(aim)<.00001,"AWP eye reticle agrees with engine projection of displayed firing ray")
				direct.global_transform=camera.global_transform
				var unaided:Array[Vector2]=[];var through:Array[Vector2]=[]
				for height in [-.08,.08]:
					var landmark:Vector3=camera.to_global(Vector3(.02,height,-20))
					unaided.append(direct.unproject_position(landmark))
					uv=camera.unproject_position(landmark)/Vector2(optic.viewport.size)
					var p:=Vector2(uv.x*2-1,1-uv.y*2)
					var scale:float=optic._material.get_shader_parameter("angular_scale")
					through.append(direct.unproject_position(camera.to_global(Vector3(p.x*scale,p.y*scale,-1))))
				var ratio:float=through[0].distance_to(through[1])/unaided[0].distance_to(unaided[1])
				check(absf(ratio-power)<.001,"engine source camera + angular compositor scale="+str(power)+" eye="+str(index))
			check(optic.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and optic.right_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"CPU geometry proof leaves both GPU views disabled")
	var shots:Array[Dictionary]=[]
	gun.shot.connect(func(origin:Vector3,direction:Vector3,_damage:float)->void:shots.append({"origin":origin,"direction":direction}))
	gun.cooldown=0;gun.chambered=true;gun.reload_state="ready";gun.fire()
	check(shots.size()==1 and shots[0].origin.distance_to(optic._displayed_pose.origin)<.00001 and shots[0].direction.dot(-optic._displayed_pose.basis.z)>.999999,"actual discharge agrees with lowered rendered optical center in origin and direction")
	optic._commit_displayed_frame() # Establish the new recoil pose before comparing cover.
	var near_barrier:=StaticBody3D.new();root.add_child(near_barrier)
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(2,2,.1);collider.shape=shape;near_barrier.add_child(collider)
	near_barrier.global_transform=optic._displayed_pose;near_barrier.global_position-=optic._displayed_pose.basis.z*1.0
	await physics_frame
	var before:Transform3D=optic._displayed_pose;optic._commit_displayed_frame()
	check(optic._displayed_pose.is_equal_approx(before) and optic.scope_camera.global_transform.is_equal_approx(optic.right_scope_camera.global_transform) and (optic._material.get_shader_parameter("aim_left") as Vector2)==Vector2.ZERO,"nearby ballistic cover cannot pull image/reticle convergence toward the eyes")
	near_barrier.free()
	gun.shutdown();check(optic.right_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"AWP shutdown disables second-eye cost")
	direct.free();gun.free();actor.free();await create_timer(.2).timeout
	print("OPTICS_057_AWP checks=",checks," failures=",failures," gpu_rendered=false actual_xr_multiview=false headset_tested=false")
	quit(failures)
