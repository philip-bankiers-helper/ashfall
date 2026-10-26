extends SceneTree
const Player = preload("res://scripts/player.gd")
const Initialization = preload("res://scripts/vertical_combat_initialization.gd")
const DT := 1.0/90.0
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func actor() -> AshPlayer:
	var value := Player.new(); root.add_child(value); value.setup(false); value.set_process(false); value.set_physics_process(false)
	return value
func run() -> void:
	var value := actor()
	check(is_equal_approx(value.MEASURED_REFERENCE_UNIT_METERS,.6096),"one reported meter is exactly two feet = .6096 SI meters")
	for entry in [[value.WALK_SPEED,4.58301686746988],[value.RUN_SPEED,5.288096385542169],[value.SPRINT_SPEED,6.6982554216867465],[value.GLIDE_SPEED,8.460954216867469]]:
		check(absf(float(entry[0])-float(entry[1]))<.0000001,"reference speed converted once to %.4f m/s" % float(entry[1]))
	check(is_equal_approx(value.effective_walk_speed(),4.58301686746988) and is_equal_approx(value.get_effective_glide_speed(),8.460954216867469),"fresh default getters expose corrected SI speed without another factor")
	check(is_equal_approx(value.sprint_slow_gain,7.5/6.5) and is_equal_approx(value.sprint_fast_gain,9.5/6.5),"dimensionless sprint ratios remain unchanged")
	check(is_equal_approx(value.GLIDE_RATIO,7.0),"glide ratio stays 7 horizontal to 1 vertical")
	var menu: AshMenu = load("res://scripts/menu.gd").new(); root.add_child(menu); menu.setup(value); menu.set_process(false)
	var old_save := {"movement_settings_version":3,"controls_tuning_revision":1,"walk_speed_multiplier":1.0,"sprint_slow_gain":7.5/6.5,"sprint_fast_gain":9.5/6.5,"glide_speed_mps":12.0,"fling_power":1.0}
	menu.apply_settings(old_save)
	for i in range(5):
		var saved: Dictionary = menu.get_settings()
		menu.apply_settings(saved)
		check(is_equal_approx(value.effective_walk_speed(),4.58301686746988) and is_equal_approx(value.glide_speed_mps,8.460954216867469),"settings roundtrip %d never compounds .6096 or restores old absolute flight speed" % i)
	var saved: Dictionary = menu.get_settings()
	check(saved.measurement_reference_revision==2 and is_equal_approx(saved.reference_unit_meters,.6096),"settings record correction provenance while gains remain dimensionless")
	menu.apply_settings({"movement_settings_version":3,"controls_tuning_revision":1,"walk_speed_multiplier":1.2,"sprint_slow_gain":1.25,"sprint_fast_gain":1.75,"glide_steering_gain":1.1})
	check(is_equal_approx(value.effective_walk_speed(),4.58301686746988*1.2) and is_equal_approx(value.glide_speed_mps,8.460954216867469*1.2),"custom walk multiplier scales corrected speeds exactly once")
	check(is_equal_approx(value.sprint_slow_gain,1.25) and is_equal_approx(value.sprint_fast_gain,1.75) and is_equal_approx(value.glide_steering_gain,1.1),"explicit custom ratios and hand steering remain unchanged")
	menu.apply_settings({"comfort_speed":true,"controls_tuning_revision":1})
	check(is_equal_approx(value.move_speed,2.6) and is_equal_approx(value.glide_speed_mps,4.8),"unmeasured SI comfort walk and its existing derived flight are preserved")
	menu.settings_page="movement"; menu._adjust_setting(5,1)
	check(is_equal_approx(value.walk_speed_multiplier,1.05) and is_equal_approx(value.move_speed,2.6),"walk multiplier slider remains dimensionless and leaves comfort base unchanged")
	menu.settings_page="turning"; menu._adjust_setting(2,1)
	check(is_equal_approx(value.move_speed,4.58301686746988),"turning menu restores corrected standard speed")
	menu._adjust_setting(2,1)
	check(is_equal_approx(value.move_speed,2.6),"turning menu shares the explicit preserved comfort tuning")
	menu.reset_movement_settings()
	check(is_equal_approx(value.effective_walk_speed(),4.58301686746988) and is_equal_approx(value.glide_speed_mps,8.460954216867469),"reset defaults uses corrected standard speed without migration multiplication")
	check(is_equal_approx(value.GRAVITY,16.2) and is_equal_approx(value.AIR_STEERING,6.0) and is_equal_approx(value.AIR_DRAG,.8),"existing SI gravity and free-air acceleration/drag remain unchanged")
	check(is_equal_approx(value.sprint_double_press_window,.32) and is_equal_approx(value.sprint_stamina_seconds,6.0) and is_equal_approx(value.sprint_recovery_seconds,4.0),"sprint click window and stamina/recovery durations remain unchanged")
	check(is_equal_approx(value.INPUT_REARM_TIME,.08) and is_equal_approx(value.MANTLE_COMPLETION_SECONDS,.20) and is_equal_approx(value.TURN_EASE_SECONDS,.12),"neutral rearm mantle and turn timing remain unchanged")
	check(is_equal_approx(value.HEAD_RADIUS,.12) and is_equal_approx(value.GLIDE_HORIZONTAL_SPREAD,.95890625),"physical head radius and hand-spread control threshold are not reference geometry")
	var reference_distance := 40.0*.6096
	for entry in [[6.5,value.WALK_SPEED],[7.5,value.RUN_SPEED],[9.5,value.SPRINT_SPEED],[12.0,value.GLIDE_SPEED]]:
		check(is_equal_approx(40.0/float(entry[0]),reference_distance/float(entry[1])),"40-reference-unit traversal timing is unchanged for %.1f old speed" % float(entry[0]))
	var floor := StaticBody3D.new(); floor.position.y=-.1
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=Vector3(300,.2,300); collision.shape=shape; floor.add_child(collision); root.add_child(floor)
	await physics_frame; await physics_frame
	value.reset_motion(); value.position=Vector3.ZERO; value._jump_requested=true; value.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,DT)
	check(is_equal_approx(value.velocity.y,6.0),"unmeasured SI jump impulse stays 6 m/s")
	value._jump_requested=false
	for entry in [[0,4.58301686746988],[1,5.288096385542169],[2,6.6982554216867465]]:
		value.reset_motion(); value.position=Vector3.ZERO; value._sprint_mode=int(entry[0]); var elapsed:=0.0
		for i in range(90):
			await physics_frame; value.apply_locomotion_motion(Vector3.FORWARD,Vector3.FORWARD,false,int(entry[0])!=0,DT); elapsed+=DT
		var actual := Vector2(value.position.x,value.position.z).length()/elapsed
		check(absf(actual-float(entry[1]))<.015,"actual ground physics travels %.4f m/s; actual %.6f" % [float(entry[1]),actual])
	value.reset_motion(); value.position=Vector3(0,30,0); var elapsed:=0.0
	for i in range(90):
		await physics_frame; value.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,true,false,DT); elapsed+=DT
	var horizontal := Vector2(value.position.x,value.position.z).length(); var drop := 30.0-value.position.y
	check(absf(horizontal/elapsed-8.460954216867469)<.015,"actual glide physics travels 8.460954216867469 horizontal m/s")
	check(absf(horizontal/drop-7.0)<.02 and absf(drop/elapsed-8.460954216867469/7.0)<.015,"actual glide descent derives once from speed/7, preserving 7:1 path")
	value.reset_motion(); value.position=Vector3(0,1000,0); value._release_velocity=Vector3.UP*100.0; value._grabs[value.desktop_camera]=value.desktop_camera.global_position
	value._update_grab(value.desktop_camera,false,true)
	check(is_equal_approx(value.velocity.y,8.75),"physical hand-derived fling still caps 7 m/s then applies existing default 1.25 gain")
	var launch_y := value.position.y
	for i in range(100):
		value.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,DT)
		if value.velocity.y<=0.0: break
	var rise := value.position.y-launch_y; var analytic_rise := pow(8.75,2)/(2.0*16.2)
	check(absf(rise-analytic_rise)<.06,"default maximum upward fling remains ballistic %.6f m above release, actual %.6f" % [analytic_rise,rise])
	value.reset_motion(); value.position=Vector3(0,1000,0); value.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,.1)
	check(is_equal_approx(value.velocity.y,-1.62),"unsupported gravity still changes velocity by 16.2 m/s squared")
	value.reset_motion(); value.position=Vector3(0,1000,0); value.apply_locomotion_motion(Vector3.RIGHT,Vector3.FORWARD,false,false,.1)
	check(is_equal_approx(value.velocity.x,.6),"free-air acceleration remains 6 m/s squared toward corrected target speed")
	value.apply_locomotion_motion(Vector3.ZERO,Vector3.FORWARD,false,false,.1)
	check(is_equal_approx(value.velocity.x,.52),"neutral free-air drag remains .8 m/s squared")
	value.reset_motion(); value.position=Vector3(5,0,5)
	value.xr_enabled=true; value.tracking_available=true; value.xr_camera.position=Vector3(.2,1.65,-.1); value.left_hand.position=Vector3(-.4,1.2,-.4)
	var raw_camera := value.xr_camera.transform; var raw_hand := value.left_hand.transform
	check(is_equal_approx(value.vertical_combat_target_height_m,2.0),"deliberate VCS target remains 2 m pending user decision")
	value.initialize_vertical_combat_system()
	check(is_equal_approx(value.measured_eye_height(),2.0),"existing 2 m normalization remains active")
	value.vertical_combat_target_height_m=1.2192
	check(is_equal_approx(value.get_standing_eye_height(),2.0) and is_equal_approx(value.measured_eye_height(),2.0),"changing explicit target does not move camera before calibration")
	var result := value.initialize_vertical_combat_system()
	check(is_equal_approx(float(result.world_baseline_m),1.2192) and is_equal_approx(value.measured_eye_height(),1.2192),"explicit alternate corrected target is supported without choosing it as default")
	check(value.xr_camera.transform.is_equal_approx(raw_camera) and value.left_hand.transform.is_equal_approx(raw_hand),"alternate target still leaves physical runtime poses unchanged")
	var relative_hand := value.left_hand.global_position-value.xr_camera.global_position
	check(is_equal_approx(relative_hand.y,-.45) and value.xr_origin.scale.is_equal_approx(Vector3.ONE),"physical hand reach is not scaled with the reference correction")
	value.xr_camera.position.y-=.4; value._sync_head_shape()
	check(is_equal_approx(value.measured_eye_height(),.8192) and value._body_shape.global_position.is_equal_approx(value.xr_camera.global_position),"alternate baseline crouches by exact physical 40 cm and moves head collision")
	var head_before_x:=value.xr_camera.global_position.x; value.xr_camera.position.x+=.1; var old_world_x:=value.get_locomotion_anchor_position().x; var head_x:=value.xr_camera.global_position.x; value._sync_body_to_head()
	check(is_equal_approx(head_x-head_before_x,.1) and is_equal_approx(value.xr_camera.global_position.x,head_x) and is_equal_approx(value.get_locomotion_anchor_position().x,old_world_x),"room recenter leaves actual 10 cm tracked displacement and locomotion anchor unchanged")
	menu.apply_settings({"vertical_combat_target_height_m":1.2192,"controls_tuning_revision":1})
	saved=menu.get_settings(); menu.apply_settings(saved)
	check(is_equal_approx(value.vertical_combat_target_height_m,1.2192),"explicit VCS target persists through settings roundtrip")
	var flow := Initialization.new(); root.add_child(flow); flow.setup(value,menu); flow.set_process(false); flow.begin(true); flow._process(0.0)
	flow.advance_gaze(flow.HOLD_SECONDS,value.xr_camera.global_position,(flow._panel.global_position-value.xr_camera.global_position).normalized())
	check(flow.state=="complete" and flow._status.text.contains("1.22"),"VCS success graphic reports the configured target rather than hard-coded 2 m")
	flow._process(1.0); flow.free()
	menu.apply_settings({})
	check(is_equal_approx(value.vertical_combat_target_height_m,2.0),"old or empty save defaults remain explicitly 2 m")
	menu.free(); value.free(); floor.free(); await create_timer(.25).timeout
	print("LOCOMOTION_UNITS_062 checks=",checks," failures=",failures," actual_world_physics=true synthetic_tracking=true rendered=false headset_tested=false")
	quit(0 if failures==0 else 1)
