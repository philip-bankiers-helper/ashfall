extends SceneTree
const Player = preload("res://scripts/player.gd")
const Initialization = preload("res://scripts/vertical_combat_initialization.gd")
const TOP := 1.8288
const OFFSET := .120
const EYE := TOP-OFFSET
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1; print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func close(a: float,b: float) -> bool: return absf(a-b)<.00001
func actor() -> AshPlayer:
	var value := Player.new(); root.add_child(value); value.setup(false); value.set_process(false); value.set_physics_process(false)
	return value
func collider_top(value: AshPlayer) -> float:
	var highest := -INF
	for point in value._body_shape.shape.points: highest=maxf(highest,(value._body_shape.global_transform*point).y-value.global_position.y)
	return highest
func box(at: Vector3,size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new(); body.position=at; var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collision.shape=shape; body.add_child(collision); root.add_child(body)
	return body
func run() -> void:
	check(close(Player.DEFAULT_PLAYER_TOP_HEIGHT_M,6*.3048),"six feet explicitly means 1.8288 m top-of-head stature")
	check(close(Player.AUTHORED_HEAD_TOP_TO_EYE_M,OFFSET) and close(Player.DEFAULT_EYE_HEIGHT_M,EYE),"authored 120 mm top-to-eye offset gives 1.7088 m camera baseline")
	var desktop := actor()
	check(close(desktop.desktop_camera.position.y,EYE) and not close(desktop.desktop_camera.position.y,TOP),"desktop camera is at eyes, never at the 6 ft vertex")
	check(close(desktop.get_head_top_height(),TOP) and close(collider_top(desktop),TOP),"desktop reported head top agrees with actual collider top")
	check(close(desktop.get_standing_eye_height(),EYE) and close(desktop.get_standing_head_top_height(),TOP),"standing-eye and standing-top APIs are distinct before XR calibration")
	desktop.initialize_vertical_combat_system()
	check(close(desktop.measured_eye_height(),EYE) and close(desktop.get_head_top_height(),TOP),"desktop VCS uses the same explicit eye/head-top semantics")
	var floor := box(Vector3(0,-.1,0),Vector3(30,.2,30))
	var ceiling := box(Vector3(0,TOP+.102,0),Vector3(2,.2,2)) # 2 mm clear of head vertex.
	await physics_frame; await physics_frame
	for baseline in [1.0,1.65,3.0]:
		var value := actor(); value.xr_enabled=true; value.tracking_available=true; value.xr_camera.position=Vector3(.1,baseline,-.1); value.left_hand.position=Vector3(-.3,baseline-.45,-.3)
		var raw_eye:=value.xr_camera.transform; var raw_hand:=value.left_hand.transform; var relative_hand:=value.left_hand.global_position-value.xr_camera.global_position
		var result := value.initialize_vertical_combat_system()
		check(close(value.measured_eye_height(),EYE) and close(value.get_head_top_height(),TOP),"raw %.2f m posture calibrates to 6 ft top, 1.7088 m eye" % baseline)
		check(close(float(result.world_eye_baseline_m),EYE) and close(float(result.world_head_top_baseline_m),TOP) and result.height_semantics=="standing_head_top","calibration signal exposes separate eye/top targets and semantics")
		check(close(float(result.world_baseline_m),EYE),"legacy signal baseline remains an eye-height alias")
		check(close(value.get_standing_eye_height(),EYE) and close(value.get_standing_head_top_height(),TOP),"remembered standing baseline separates eye and vertex")
		check(value.xr_camera.transform.is_equal_approx(raw_eye) and value.left_hand.transform.is_equal_approx(raw_hand),"calibration leaves physical runtime local poses unchanged")
		check((value.left_hand.global_position-value.xr_camera.global_position).is_equal_approx(relative_hand) and value.xr_origin.scale.is_equal_approx(Vector3.ONE),"physical hand reach remains 1:1")
		check(close(collider_top(value),value.get_head_top_height()),"actual upper collision point equals reported vertex")
		check(value._resolve_support(.02,false) and close(value.position.y,0),"corrected eye/top baseline preserves real floor support")
		check(not value.is_head_position_obstructed(value.xr_camera.global_position),"standing head clears a ceiling 2 mm above actual 6 ft top")
		value.xr_camera.position.y-=.4; value._sync_head_shape()
		check(close(value.measured_eye_height(),EYE-.4) and close(value.get_head_top_height(),TOP-.4),"40 cm tracked crouch lowers both eye and vertex exactly 40 cm")
		check(close(collider_top(value),TOP-.4) and close(value.get_standing_head_top_height(),TOP),"crouched collider moves; remembered standing vertex stays 6 ft")
		value.xr_camera.position.y-=.7; value._sync_head_shape()
		check(close(value.get_head_top_height(),TOP-1.1) and close(collider_top(value),TOP-1.1),"deep-crouch head-top helper follows collider despite reported-eye minimum clamp")
		value.free()
	ceiling.position.y=TOP+.098 # 2 mm overlap of upper head envelope.
	await physics_frame; await physics_frame
	check(desktop.is_head_position_obstructed(desktop.desktop_camera.global_position),"ceiling below actual vertex overlaps the real upper head collider")
	desktop.position=Vector3(4,0,4); desktop.desktop_camera.rotation.x=.6; desktop.rotation.y=.7; desktop._sync_head_shape()
	check(close(collider_top(desktop),TOP) and close(desktop.get_head_top_height(),TOP),"yaw and gaze pitch preserve authored upright head-top/collider agreement")
	var menu: AshMenu=load("res://scripts/menu.gd").new(); root.add_child(menu); menu.setup(desktop); menu.set_process(false)
	for old_eye in [2.0,1.2192,1.524]:
		menu.apply_settings({"vertical_combat_target_height_m":old_eye,"controls_tuning_revision":1})
		check(close(desktop.vertical_combat_target_top_height_m,TOP) and close(desktop.get_target_eye_height_m(),EYE),"legacy %.4f eye setting cannot silently become top-of-head stature" % old_eye)
	for old_revision in [-1,0]:
		var old_top_save:Dictionary={"vertical_combat_target_top_height_m":1.524,"controls_tuning_revision":1}
		if old_revision>=0:old_top_save["vertical_combat_stature_revision"]=old_revision
		menu.apply_settings(old_top_save)
		check(close(desktop.vertical_combat_target_top_height_m,TOP),"old five-foot top save migrates to six-foot default")
	var saved:Dictionary=menu.get_settings()
	check(saved.vertical_combat_stature_revision==1,"new save marks explicit stature revision")
	check(saved.vertical_combat_height_semantics=="standing_head_top" and close(float(saved.vertical_combat_target_top_height_m),TOP),"new save names top-of-head target and semantics explicitly")
	check(not saved.has("vertical_combat_target_height_m") and close(float(saved.vertical_combat_top_to_eye_m),OFFSET),"new save removes ambiguous eye key and records authored offset")
	menu.apply_settings({"vertical_combat_stature_revision":1,"vertical_combat_target_top_height_m":1.7,"controls_tuning_revision":1})
	check(close(desktop.get_head_top_height(),TOP),"changing explicit target does not move the live eye before initialization")
	desktop.initialize_vertical_combat_system()
	check(close(desktop.get_head_top_height(),1.7) and close(desktop.measured_eye_height(),1.58),"explicit custom top derives eye once without unit rescaling")
	menu.apply_settings(menu.get_settings())
	check(close(desktop.vertical_combat_target_top_height_m,1.7),"top-of-head setting survives a save roundtrip")
	menu.apply_settings({})
	var xr:=actor(); xr.xr_enabled=true; xr.tracking_available=true; xr.xr_camera.position.y=1.0
	var ambient=load("res://scripts/ambience.gd").new(); root.add_child(ambient); ambient._player=xr; ambient.set_process(false)
	xr.initialize_vertical_combat_system()
	check(not ambient._crouch_walking() and close(xr.get_tracking_eye_baseline_m(),1.0),"neutral seated calibration uses physical baseline for raw-space crouch audio")
	xr.xr_camera.position.y=.74
	check(ambient._crouch_walking(),"physical crouch audio compares raw pose against raw baseline")
	xr.global_position.y+=10
	check(ambient._crouch_walking(),"artificial climb/flight height cannot change raw-space crouch classification")
	xr.xr_camera.position.y=1.0; xr.position=Vector3(5,0,5)
	var flow:=Initialization.new(); root.add_child(flow); flow.setup(xr); flow.set_process(false); flow.begin(true); flow._process(0.0)
	check(close(xr.get_head_top_height(),TOP) and flow.active and not xr.input_enabled,"startup normalizes the top before presenting unchanged gaze controls")
	var forward:Vector3=-xr.xr_camera.global_basis.z; var target:Vector3=(flow._panel.global_position-xr.xr_camera.global_position).normalized()
	check(close(rad_to_deg(acos(clampf(forward.dot(target),-1,1))),18.0),"startup cue remains 18 degrees to initial gaze right")
	flow.advance_gaze(.5,xr.xr_camera.global_position,target)
	check(close(flow.progress,.4),"gaze hold timing remains 1.25 seconds")
	flow.advance_gaze(.1,xr.xr_camera.global_position,forward)
	check(is_zero_approx(flow.progress),"looking away still resets continuous hold")
	flow.advance_gaze(1.25,xr.xr_camera.global_position,target)
	check(flow.state=="complete" and flow._status.text.contains("TOP 1.829"),"completion shows head-top height rather than labeling eye height as stature")
	check(close(xr.measured_eye_height(),EYE) and close(collider_top(xr),TOP),"gaze completion preserves correct camera and collider top")
	flow._process(.6)
	check(not flow.active and xr.input_enabled,"completion resumes existing controls after neutral gate")
	xr.xr_camera.position.y=.8
	flow.begin(); flow._process(0)
	check(close(xr.get_head_top_height(),TOP-.2),"manual reinitialize waits for gaze before changing crouched posture")
	flow.advance_gaze(1.25,xr.xr_camera.global_position,(flow._panel.global_position-xr.xr_camera.global_position).normalized()); flow._process(.6)
	check(close(xr.get_head_top_height(),TOP) and close(xr.get_tracking_eye_baseline_m(),.8),"manual reinitialize restores 6 ft vertex from newly seated raw baseline")
	check(close(xr.WALK_SPEED,4.58301686746988) and close(xr.RUN_SPEED,5.288096385542169) and close(xr.SPRINT_SPEED,6.6982554216867465) and close(xr.GLIDE_SPEED,8.460954216867469) and close(xr.GLIDE_RATIO,7.0),"height clarification leaves corrected motion speeds and glide ratio unchanged")
	flow.free(); ambient.free(); xr.free(); menu.free(); desktop.free(); ceiling.free(); floor.free(); await create_timer(.25).timeout;await process_frame;await process_frame
	print("HEAD_TOP_062 checks=",checks," failures=",failures," actual_collision_queries=true synthetic_tracking=true rendered=false headset_tested=false authored_eye_offset_m=0.120")
	quit(0 if failures==0 else 1)
