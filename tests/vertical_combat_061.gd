extends SceneTree
const Player = preload("res://scripts/player.gd")
const Initialization = preload("res://scripts/vertical_combat_initialization.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func actor() -> AshPlayer:
	var value := Player.new(); root.add_child(value); value.setup(false); value.set_process(false); value.set_physics_process(false)
	value.xr_enabled = true; value.tracking_available = true
	return value
func run() -> void:
	for baseline in [1.0,1.65,3.0]:
		var value := actor(); value.position = Vector3(9,16,-4); value.xr_camera.position = Vector3(.2,baseline,-.1)
		value.left_hand.position = Vector3(-.4,baseline-.4,-.4)
		var raw_camera := value.xr_camera.transform; var raw_hand := value.left_hand.transform
		var relative_hand := value.left_hand.global_position-value.xr_camera.global_position
		var foot := value.global_position
		var result := value.initialize_vertical_combat_system()
		check(not result.is_empty() and is_equal_approx(value.measured_eye_height(),2.0),"baseline %.2f calibrates eye to 2 m" % baseline)
		check(value.global_position.is_equal_approx(foot),"calibration leaves logical feet/world spawn unchanged")
		check(value.xr_camera.transform.is_equal_approx(raw_camera) and value.left_hand.transform.is_equal_approx(raw_hand),"runtime camera/controller local poses remain unchanged")
		check((value.left_hand.global_position-value.xr_camera.global_position).is_equal_approx(relative_hand),"hand to head distance remains meter-for-meter")
		check(value.scale.is_equal_approx(Vector3.ONE) and value.xr_origin.scale.is_equal_approx(Vector3.ONE),"world/controller scale stays 1; sword/build dimensions unchanged")
		check(is_equal_approx(value.get_standing_eye_height(),2.0),"remembered standing baseline is 2 m for seated or tall player")
		value.xr_camera.position.y -= .4; value._sync_head_shape()
		check(is_equal_approx(value.measured_eye_height(),1.6),"lowering 40 cm crouches eye by exactly 40 cm")
		check(value._body_shape.global_position.is_equal_approx(value.xr_camera.global_position),"head collision follows crouched eye")
		check(is_equal_approx(value.get_standing_eye_height(),2.0),"crouching cannot overwrite initialized standing baseline")
		var origin_lift := value.xr_origin.position.y; value._sync_body_to_head()
		check(is_equal_approx(value.xr_origin.position.y,origin_lift) and is_equal_approx(value.measured_eye_height(),1.6),"horizontal room recenter preserves calibrated vertical offset")
		value.initialize_vertical_combat_system()
		check(is_equal_approx(value.measured_eye_height(),2.0),"reinitializing lowered posture establishes new 2 m baseline")
		value.tracking_available = false
		check(value.initialize_vertical_combat_system().is_empty(),"untracked headset cannot calibrate")
		value.free()
	var value := actor(); value.xr_camera.position.y = 1.05
	var menu: AshMenu = load("res://scripts/menu.gd").new(); root.add_child(menu); menu.setup(value); menu.set_process(false)
	var flow := Initialization.new(); root.add_child(flow); flow.setup(value,menu); flow.set_process(false)
	flow.begin(true); flow._process(0.0)
	check(is_equal_approx(value.measured_eye_height(),2.0),"startup immediately normalizes first valid tracked eye to 2 m")
	check(flow.active and flow._panel.visible and not value.input_enabled,"startup displays gaze cue and suspends movement")
	value.input_enabled = true
	check(not value.input_enabled,"menu or other input enable cannot bypass active calibration movement lock")
	var forward := -value.xr_camera.global_basis.z
	var target := (flow._panel.global_position-value.xr_camera.global_position).normalized()
	check(is_equal_approx(rad_to_deg(acos(clampf(forward.dot(target),-1,1))),18.0) and target.x > 0,"cue starts 18 degrees to initial gaze right")
	flow.advance_gaze(.8,value.xr_camera.global_position,forward)
	check(is_zero_approx(flow.progress),"initial straight-ahead gaze cannot start countdown")
	flow.advance_gaze(.5,value.xr_camera.global_position,target)
	check(is_equal_approx(flow.progress,.4) and flow._ring.mesh.get_surface_count()==1 and flow._status.text.contains("0.8"),"turning head begins visible ring and seconds countdown")
	flow.advance_gaze(.1,value.xr_camera.global_position,forward)
	check(is_zero_approx(flow.progress),"looking away resets continuous gaze hold")
	value.xr_camera.position.y -= .2
	flow.advance_gaze(1.0,value.xr_camera.global_position,(flow._panel.global_position-value.xr_camera.global_position).normalized())
	check(flow.state=="holding" and not is_equal_approx(value.measured_eye_height(),2.0),"incomplete hold cannot recalibrate changed posture")
	flow.advance_gaze(.25,value.xr_camera.global_position,(flow._panel.global_position-value.xr_camera.global_position).normalized())
	check(flow.state=="complete" and is_equal_approx(value.measured_eye_height(),2.0),"1.25 seconds continuous hold calibrates current posture")
	check(flow._chime.stream.data.size() > 1000 and flow._status.text.contains("2.0"),"completion has original audio stream and initialized status")
	flow._process(.6)
	check(not flow.active and not flow._panel.visible and value.input_enabled,"completion removes cue and resumes movement with neutral input gate")
	value.xr_camera.position.y -= .5
	menu.set_open(true); menu.settings_page = "game"; menu._refresh()
	check(menu._labels()[5]=="REINITIALIZE VERTICAL COMBAT SYSTEM" and menu._labels().size()<=menu.MENU_ROWS,"Game Settings exposes reinitialize without overflowing menu rows")
	menu._choose(5); flow._process(0.0)
	check(not menu.is_open and flow.active and flow.state=="await_gaze","menu selection closes panel and repeats the head-turn gaze flow")
	check(is_equal_approx(value.measured_eye_height(),1.5),"manual reinitialize waits for gaze before changing seated baseline")
	flow.advance_gaze(.5,value.xr_camera.global_position,(flow._panel.global_position-value.xr_camera.global_position).normalized())
	value.tracking_available = false; flow._process(.3)
	check(is_zero_approx(flow.progress) and not flow._panel.visible and flow.state=="await_tracking","tracking loss resets countdown and hides target")
	value.tracking_available = true; flow._process(0.0)
	flow.advance_gaze(1.25,value.xr_camera.global_position,(flow._panel.global_position-value.xr_camera.global_position).normalized()); flow._process(.6)
	check(is_equal_approx(value.measured_eye_height(),2.0) and not flow.active,"headset tracking resume permits fresh complete seated calibration")
	check(is_equal_approx(value.WALK_SPEED,6.5) and is_equal_approx(value.RUN_SPEED,7.5) and is_equal_approx(value.SPRINT_SPEED,9.5) and is_equal_approx(value.GLIDE_SPEED,12.0) and is_equal_approx(value.GLIDE_RATIO,7.0),"Al's walk/run/sprint/fly and 7:1 glide defaults retained")
	var bank := value.update_glide_heading(Vector3.FORWARD,value.to_global(Vector3(-.6,1.6,0)),value.to_global(Vector3(.6,1.2,0)),true,.01)
	check(is_equal_approx(bank.x/-bank.z,.65*1.1*value.glide_steering_gain),"hand-height bank authority increases exactly 10 percent")
	check(is_zero_approx(bank.y) and is_equal_approx(bank.length(),1.0),"extra hand steering changes heading without speed or glide slope")
	flow.free(); menu.free(); value.free(); await create_timer(.25).timeout
	var floor := StaticBody3D.new(); floor.position.y = -.1
	var floor_collision := CollisionShape3D.new(); var floor_shape := BoxShape3D.new(); floor_shape.size = Vector3(20,.2,20); floor_collision.shape = floor_shape; floor.add_child(floor_collision); root.add_child(floor)
	var ceiling := StaticBody3D.new(); ceiling.position = Vector3(0,2.1,0)
	var ceiling_collision := CollisionShape3D.new(); var ceiling_shape := BoxShape3D.new(); ceiling_shape.size = Vector3(2,.2,2); ceiling_collision.shape = ceiling_shape; ceiling.add_child(ceiling_collision); root.add_child(ceiling)
	await physics_frame; await physics_frame
	for baseline in [1.05,3.0]:
		var calibrated := actor(); calibrated.xr_camera.position.y = baseline; calibrated.initialize_vertical_combat_system()
		check(calibrated._resolve_support(.02,false) and is_zero_approx(calibrated.position.y),"calibrated %.2f m player keeps real floor support at feet" % baseline)
		check(calibrated.is_head_position_obstructed(calibrated.xr_camera.global_position),"initialized 2 m head retains real overhead obstruction")
		calibrated.xr_camera.position.y -= .4; calibrated._sync_head_shape()
		check(calibrated._resolve_support(.02,false) and is_zero_approx(calibrated.position.y),"crouching changes head collision without lifting/sinking logical floor")
		check(not calibrated.is_head_position_obstructed(calibrated.xr_camera.global_position),"40 cm physical crouch clears actual low ceiling after calibration")
		calibrated.free()
	floor.free(); ceiling.free(); await process_frame
	print("VERTICAL_COMBAT_061 checks=",checks," failures=",failures," synthetic_tracking=true headset_tested=false rendered=false")
	quit(0 if failures==0 else 1)
