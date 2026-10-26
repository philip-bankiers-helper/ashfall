extends "res://tests/aim_sync_072.gd"
# Simulate tracked-hand eligibility without enabling XR or a native viewport.
class TrackedAWP extends "res://scripts/precision_rifle.gd":
	func _vr_active()->bool:return true
const EXPERIMENT:="ashfall/awp_zoom_damping_experiment"
func run()->void:
	var baseline_flag:bool=OS.get_cmdline_user_args().has("--awp-baseline")
	check(not root.use_xr,"headless XR remains off")
	var actor:=Actor.new();root.add_child(actor);actor.add_child(actor.right_hand);actor.add_child(actor.left_hand);actor.add_child(actor.view)
	var gun:=TrackedAWP.new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false);gun._desktop_signals=true
	gun.motion_damping=1.35;gun.position=Vector3(.23,1.2,-.4)
	var home:Vector3=gun.position
	var base_tau:=.006+.09*1.35*1.35
	var target:=Basis(Vector3.UP,.4)
	var results:Array=[]
	for enabled in [false,true]:
		ProjectSettings.set_setting(EXPERIMENT,enabled)
		for scoped in [false,true]:
			gun.supported=scoped
			for zoom in [1.0,2.0,4.0,8.0]:
				gun.optic.zoom_magnification=zoom
				check(gun.optic.alignment_allowed()==scoped,"actual scope eligibility uses support")
				var factor:float=sqrt(zoom) if scoped and enabled and not baseline_flag else 1.0
				var tau:float=base_tau*factor
				check(absf(gun.aim_smoothing_time_constant()-tau)<.000001,"actual AWP virtual tau matches scope/setting")
				for hz in [30,72,90,120]:
					gun.global_basis=Basis.IDENTITY;gun._aim_filter_ready=false;gun._apply_aim_filter(1.0/hz)
					for frame in range(1,hz+1):
						gun.global_basis=target;gun._apply_aim_filter(1.0/hz)
						var expected:=Basis(Vector3.UP,.4*(1.0-exp(-(float(frame)/hz)/tau)))
						check(gun._filtered_aim.get_rotation_quaternion().angle_to(expected.get_rotation_quaternion())<.001,"actual filter exponential response independent of frame rate")
						check(gun.position==home,"filter leaves position exact")
					results.append({"enabled":enabled,"scoped":scoped,"zoom_test_value":zoom,"hz":hz,"tau_s":tau,"response_fraction_1s":gun._filtered_aim.get_euler().y/.4})
	ProjectSettings.set_setting(EXPERIMENT,true);gun.supported=true;gun.optic.zoom_magnification=8
	gun.motion_damping=0;gun._aim_filter_ready=true;gun._filtered_aim=Basis.IDENTITY;gun.global_basis=target;gun._apply_aim_filter(1.0/90)
	check(gun.global_basis.is_equal_approx(target),"zero damping bypasses experiment")
	check(gun.scoped_damping_multiplier(.1,true)==1 and gun.scoped_damping_multiplier(20,true)==(1 if baseline_flag else sqrt(8.0)),"magnification bounded1..8")
	check(gun.scoped_damping_multiplier(8,false)==1,"unscoped helper neutral")
	# Exercise actual optical snapshot and fire, including roll removal. Headless
	# commits snapshots explicitly; this does not measure native render latency.
	gun.motion_damping=1.35;gun.global_basis=Basis.from_euler(Vector3(.3,.6,1.1));gun._apply_recoil_visual()
	gun.optic._commit_displayed_frame()
	var shown:Transform3D=gun.get_firing_pose();var forward:Vector3=-shown.basis.z.normalized()
	check(absf(shown.basis.x.dot(Vector3.UP))<.00001,"optical snapshot stays world upright")
	check(forward.distance_to(-gun.get_visual_reticle_pose_071(gun.get_shot_transform()).basis.z.normalized())<.00001,"upright scope retains filtered shot forward")
	var shots:Array=[];capture(gun,shots);verify_shot(gun,shots,shown,"AWP scoped actual shot")
	# Shared base keeps the exact072 constant for unrelated guns.
	for id in ["fal","mp5","spr"]:
		var control=make_gun(actor,id);control.motion_damping=1.35
		check(absf(control.aim_smoothing_time_constant()-base_tau)<.000001,id+" shared baseline tau preserved")
		control.shutdown();control.free()
	ProjectSettings.set_setting(EXPERIMENT,null)
	gun.shutdown();gun.free();actor.free()
	print("AWP_DAMPING_073_DATA ",JSON.stringify(results))
	print("AWP_DAMPING_073 checks=",checks," failures=",failures," baseline_flag=",baseline_flag," simulated_tracking=true xr_off=true headset_verified=false");quit(failures)

