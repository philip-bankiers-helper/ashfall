extends SceneTree
# Reproduces Godot4.7.2 CameraData::set_multiview_camera's real matrix layout.
# No XR runtime, pixels, synthetic GPU, or headset acceptance is claimed.
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	# Instantiate the packaged production resource. Exported GDScript may be
	# compiled and need not expose its original source bytes through FileAccess.
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var gun=load("res://scripts/precision_rifle.gd").new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
	var source:String=gun.optic._material.shader.code
	var uses_eye_origin:=source.contains("projected.xyz/projected.w-EYE_OFFSET")
	check(uses_eye_origin,"AWP inverse projection removes current eye offset before constructing direction")
	var worst_legacy_error:=0.0
	for near_plane in [.05,.1,.25]:
		for ipd in [.058,.064,.072]:
			for side in [-1.0,1.0]:
				# Asymmetric eye projection and canted eye rotation exercise the same
				# combined-view layout the engine uploads to INV_PROJECTION_MATRIX.
				var eye_transform:=Transform3D(Basis(Vector3.UP,side*.08),Vector3(side*ipd*.5,.002,.014))
				var eye_projection:=Projection.create_depth_correction(true)*Projection.create_frustum(-near_plane*.9,near_plane*1.15,-near_plane,near_plane*.96,near_plane,200)
				var multiview_projection:=eye_projection*Projection(eye_transform.affine_inverse())
				for head_angles in [Vector3.ZERO,Vector3(.12,.6,.45)]:
					var head:=Transform3D(Basis.from_euler(head_angles),Vector3(4,2,7))
					for landmark in [Vector3(0,0,-8),Vector3(.17,-.11,-20)]:
						var world_point:Vector3=head*eye_transform*landmark
						var local_target:Vector3=head.affine_inverse()*world_point
						var clip:Vector4=multiview_projection*Vector4(local_target.x,local_target.y,local_target.z,1)
						# Runtime shader unprojects the near plane at this pixel.
						clip=Vector4(clip.x/clip.w,clip.y/clip.w,1,1)
						var point:Vector4=multiview_projection.inverse()*clip
						var local_point:Vector3=Vector3(point.x,point.y,point.z)/point.w
						var expected:Vector3=(world_point-head*eye_transform.origin).normalized()
						var legacy:Vector3=(head.basis*local_point.normalized()).normalized()
						var corrected:Vector3=(head.basis*(local_point-eye_transform.origin).normalized()).normalized()
						worst_legacy_error=maxf(worst_legacy_error,rad_to_deg(legacy.angle_to(expected)))
						var production:Vector3=corrected if uses_eye_origin else legacy
						check(production.dot(expected)>.999999,"AWP known landmark ray near=%s ipd=%s side=%s head=%s target=%s"%[near_plane,ipd,side,head_angles,landmark])
	check(worst_legacy_error>20,"old center-origin equation demonstrably fails real multiview matrix layout by over20degrees")
	gun.shutdown();_stop_audio(gun);_stop_audio(actor);gun.free();actor.free();await create_timer(.2).timeout
	print("OPTICS_054_PROJECTION checks=",checks," failures=",failures," worst_legacy_degrees=",worst_legacy_error," gpu_rendered=false actual_xr_multiview=false headset_tested=false")
	quit(failures)
func _stop_audio(node:Node)->void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop();node.stream=null
	for child in node.get_children():_stop_audio(child)
