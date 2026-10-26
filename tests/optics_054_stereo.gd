extends SceneTree
# CPU geometry/state proof only. No viewport requests a GPU frame.
class StereoSPR extends "res://scripts/spr_scope.gd":
	var separation:=.072
	func get_eye_poses()->Array[Transform3D]:
		return [gun.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(-separation*.5,0,0)),gun.camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(separation*.5,0,0))]
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var gun=load("res://scripts/spr.gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
	var old=gun.optic;old.shutdown();old.viewport.free();old.free()
	var optic:=StereoSPR.new();gun.model.add_child(optic);optic.setup(gun);gun.optic=optic
	gun.global_transform=Transform3D.IDENTITY;gun.model.transform=Transform3D.IDENTITY
	var view:Camera3D=actor.get_view_camera();view.global_transform=Transform3D.IDENTITY
	gun.position=Vector3(0,-.151,-.226)
	optic._commit_displayed_frame()
	var eyes:Array[Transform3D]=optic.get_eye_poses()
	check(optic.scope_camera.global_position.is_equal_approx(eyes[0].origin),"SPR left render origin is actual left eye, not objective or center eye")
	var has_right:=optic.get("right_scope_camera")!=null
	check(has_right,"SPR has a distinct right-eye optical camera")
	if has_right:
		check(optic.right_scope_camera.global_position.is_equal_approx(eyes[1].origin),"SPR right render origin is actual right eye")
		check(is_equal_approx(optic.scope_camera.global_position.distance_to(optic.right_scope_camera.global_position),.072),"SPR optical scene cameras preserve 72mm runtime IPD")
		check(optic.scope_camera.global_basis.is_equal_approx(optic.right_scope_camera.global_basis),"SPR stereo optical cameras are parallel")
	check(optic._material.shader.code.contains("VIEW_INDEX") and optic._material.shader.code.contains("optical_right"),"SPR production shader selects actual current-eye scene")
	check(optic._material.shader.code.contains("EYE_OFFSET"),"SPR physical aperture sampling includes current-eye origin")
	check(optic.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"CPU fixture never requests optical rendering")
	if has_right:
		var direct:=Camera3D.new();root.add_child(direct);direct.keep_aspect=Camera3D.KEEP_HEIGHT;direct.fov=80
		for roll in [0.0,.55]:
			gun.global_transform=Transform3D(Basis.from_euler(Vector3(.08,.4,roll)),Vector3(2,3,-5));gun.model.transform=Transform3D.IDENTITY
			for relief in [.08,.16,.30]:
				for separation in [.058,.072]:
					optic.separation=separation
					for offset in [Vector2.ZERO,Vector2(.015,.01)]:
						view.global_transform=Transform3D(gun.global_basis,optic.lens.global_position+gun.global_basis*Vector3(offset.x,offset.y,relief))
						optic._commit_displayed_frame();eyes=optic.get_eye_poses()
						var frame:Transform3D=gun.get_firing_pose()
						var directions:Array[Vector2]=[]
						for index in 2:
							var optical:Camera3D=optic.scope_camera if index==0 else optic.right_scope_camera
							var extent:Vector2=optic._material.get_shader_parameter("tangent_left" if index==0 else "tangent_right")
							check(optical.global_position.is_equal_approx(eyes[index].origin),"actual SPR per-eye origin through head/gun rotation")
							var aperture_covered:=true
							for x in [-.5,.5]:
								for y in [-.5,.5]:
									var corner:Vector3=optical.to_local(optic.lens.to_global(Vector3(optic.WINDOW_SIZE.x*x,optic.WINDOW_SIZE.y*y,0)))
									var tangent:=Vector2(corner.x,corner.y)/(-corner.z)/2.0
									aperture_covered=aperture_covered and absf(tangent.x)<=extent.x+.00001 and absf(tangent.y)<=extent.y+.00001
							check(aperture_covered,"SPR source projection covers actual off-axis aperture corners")
							direct.global_transform=optical.global_transform
							var unaided:Array[Vector2]=[];var through:Array[Vector2]=[]
							for height in [-.08,.08]:
								var target:Vector3=optic.lens.global_position+gun.global_basis*Vector3(0,height,-20)
								unaided.append(direct.unproject_position(target))
								# Engine Camera3D projection supplies source pixels. Intersect
								# their magnified eye ray with the actual aperture plane.
								var uv:Vector2=optical.unproject_position(target)/Vector2(optic.viewport.size)
								var p:=Vector2(uv.x*2-1,1-uv.y*2)
								var angular:Vector2=p*extent*2.0
								var ray:Vector3=optical.global_basis*Vector3(angular.x,angular.y,-1)
								var distance:float=(optic.lens.global_position-eyes[index].origin).dot(optic.lens.global_basis.z)/ray.dot(optic.lens.global_basis.z)
								var on_lens:Vector3=eyes[index].origin+ray*distance
								through.append(direct.unproject_position(on_lens))
								if height>0:directions.append(angular)
							var ratio:float=through[0].distance_to(through[1])/unaided[0].distance_to(unaided[1])
							check(absf(ratio-2.0)<.001,"engine projected SPR landmark scale2x relief=%s IPD=%s roll=%s eye=%s"%[relief,separation,roll,index])
							var target:Vector3=frame.origin-frame.basis.z*180.0
							var uv:Vector2=optical.unproject_position(target)/Vector2(optic.viewport.size)
							var expected_aim:=Vector2(uv.x*2-1,1-uv.y*2)
							var aim:Vector2=optic._material.get_shader_parameter("aim_left" if index==0 else "aim_right")
							check(aim.distance_to(expected_aim)<.00001,"SPR per-eye reticle matches engine projected displayed firing target")
						check(absf(absf(directions[1].x-directions[0].x)-2.0*separation/(20.0+relief))<.000001,"SPR binocular scene disparity comes from20m target, not near lens plane")
						check(optic.get_displayed_pose().pose.is_equal_approx(frame),"SPR displayed firing authority remains exact committed frame")
		optic.shutdown();check(optic.right_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"SPR shutdown also disables second viewport")
		direct.free()
	gun.shutdown();gun.free();actor.free();await create_timer(.2).timeout
	print("OPTICS_054_STEREO checks=",checks," failures=",failures," gpu_rendered=false actual_xr_multiview=false headset_tested=false")
	quit(failures)
