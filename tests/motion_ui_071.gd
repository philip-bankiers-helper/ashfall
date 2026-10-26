extends SceneTree
const Upright=preload("res://scripts/upright_ui.gd")
const Supplies=preload("res://scripts/field_consumables.gd")
const Player=preload("res://scripts/player.gd")
const Init=preload("res://scripts/vertical_combat_initialization.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func run()->void:
	var camera:=Camera3D.new();root.add_child(camera)
	var hud=load("res://scripts/combat_hud.gd").new();camera.add_child(hud);hud.camera=camera;hud.set_process(false)
	for yaw in [-120.0,0.0,75.0]:
		for pitch in [-70.0,0.0,65.0]:
			var level:=Basis.from_euler(Vector3(deg_to_rad(pitch),deg_to_rad(yaw),0))
			for roll in [-90.0,0.0,90.0]:
				camera.global_transform=Transform3D(level*Basis(Vector3.BACK,deg_to_rad(roll)),Vector3(3,2,-4))
				hud.refresh(0)
				check(hud.global_basis.is_equal_approx(Upright.view_basis(level)),"HUD ignores roll, preserves pitch/yaw")
				check(hud.global_position.is_equal_approx(camera.global_position),"HUD follows translated headset")
				check(hud.global_basis.z.dot(camera.global_basis.z)>.9999,"crosshair helper preserves aiming plane normal")
				var projected_up:=Vector3.UP-camera.global_basis.z*Vector3.UP.dot(camera.global_basis.z)
				check(hud.global_basis.y.dot(projected_up.normalized())>.9999,"HUD vertical is projected world-up")
	for vertical in [Vector3.UP,Vector3.DOWN]:
		check(Upright.view_basis(Basis.looking_at(vertical,Vector3.RIGHT)).is_finite(),"vertical gaze is finite")
	for axis in [Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var head:=Vector3(5,1.7,-3)
		check(Supplies.within_headset_reach(head+axis*.4499,head),"inside expanded head region")
		check(not Supplies.within_headset_reach(head+axis*.4501,head),"outside expanded head region")
	check(Supplies.within_headset_reach(Vector3(.45,0,0),Vector3.ZERO),"exact radius included")
	var supplies:=Supplies.new();root.add_child(supplies);supplies.set_process(false)
	supplies.held_kind="banana";supplies.phase="open"
	for peels in 4:
		check(not supplies.open_item() and not supplies.consume_at_mouth(1,true,true),"unpeeled banana cannot consume "+str(peels))
		supplies._peel_start=Vector3(0,.1,0);supplies._peel_active=true
		supplies.sample_peel(Vector3(0,-.02,0),true,true)
		check(supplies.peel_count==peels+1,"one downward stroke adds one peel")
		supplies.sample_peel(Vector3(0,-.02,0),true,true)
		check(supplies.peel_count==peels+1,"stationary grip cannot repeat peel")
	check(supplies.phase=="consume","four peels permit eating")
	supplies.held_kind="shaker";supplies.phase="shake"
	check(not supplies.consume_at_mouth(1,true,true),"unready shaker cannot drink even within radius")
	for i in 300:supplies.sample_shake(Vector3.ZERO,1.0/90)
	check(supplies.phase=="shake","stationary headset proximity does not prepare shaker")
	for i in 480:supplies.sample_shake(Vector3(sin(i*.25)*.12,0,0),1.0/90)
	check(supplies.phase=="consume" and "ready" in supplies.audio_events,"actual shaking retains ready cue and drink phase")
	check(not supplies.consume_at_mouth(.2,true,false),"upright drink still requires tilt")
	check(not supplies.consume_at_mouth(.2,false,true) and supplies._mouth_time==0,"outside radius resets consumption timer")
	for seated in [.85,1.2,1.7]:
		var actor:=Player.new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
		actor.xr_enabled=true;actor.tracking_available=true;actor.xr_camera.position.y=seated
		var raw:=actor.xr_camera.transform;actor.initialize_vertical_combat_system()
		check(is_equal_approx(actor.get_head_top_height(),1.8288),"six-foot top at seated calibration")
		check(is_equal_approx(actor.get_target_eye_height_m(),1.7088),"six feet is not eye height")
		check(actor.xr_camera.transform==raw,"calibration preserves tracked pose")
		actor.xr_camera.position.y=seated+.6;actor._apply_vertical_combat_ceiling()
		check(is_equal_approx(actor.get_head_top_height(),1.8288),"standing above seated baseline capped")
		actor.xr_camera.position.y=seated-.3;actor._apply_vertical_combat_ceiling()
		check(is_equal_approx(actor.get_head_top_height(),1.5288),"downward crouch remains physical")
		actor.initialize_vertical_combat_system();check(is_equal_approx(actor.get_head_top_height(),1.8288),"reinit sets fresh top baseline")
		check(actor.scale==Vector3.ONE and actor.xr_origin.scale==Vector3.ONE,"no global scale change")
		actor.free()
	check(Init.GAZE_CONE_DEGREES==15.0,"activation cone doubled")
	for degrees in [14.9,15.1]:
		check((Vector3.FORWARD.dot(Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(degrees)))>=cos(deg_to_rad(Init.GAZE_CONE_DEGREES)))==(degrees<15),"cone boundary")
	supplies.free();hud.free();camera.free()
	print("MOTION_UI_071 checks=",checks," failures=",failures," native_headset_verified=false");quit(failures)
