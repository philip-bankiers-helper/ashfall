extends SceneTree
var failures:=0
var checks:=0
var actor
var menu
var left:XRControllerTracker
var right:XRControllerTracker
func check(ok:bool,label:String):
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func tracker(id:String,hand:XRController3D)->XRControllerTracker:
	var t:=XRControllerTracker.new()
	t.type=XRServer.TRACKER_CONTROLLER;t.name=id
	XRServer.add_tracker(t)
	hand.tracker=id;hand.pose="grip"
	t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	return t
func step():menu._process(.02)
func neutral():
	left.set_input("by_button",false);left.set_input("menu_button",false)
	right.set_input("ax_button",false)
	actor.update_hand_input_rearm(.1)
	step()
func _initialize():call_deferred("run")
func run():
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	left=tracker("menu_test_left",actor.left_hand);right=tracker("menu_test_right",actor.right_hand)
	await process_frame
	actor.xr_enabled=true
	menu=load("res://scripts/menu.gd").new();root.add_child(menu);menu.setup(actor);menu.set_process(false)
	neutral()
	left.set_input("by_button",true);step()
	check(not menu.is_open,"Y does not open pause menu")
	neutral();left.set_input("menu_button",true);step()
	check(menu.is_open and not actor.input_enabled,"fresh left Menu press opens pause and disables gameplay")
	for i in range(5):step()
	check(menu.is_open,"held Menu cannot repeatedly toggle")
	left.set_input("by_button",true);step()
	check(menu.is_open,"Y does not close pause menu")
	neutral();left.set_input("menu_button",true);step()
	check(not menu.is_open,"release and fresh Menu closes pause")
	actor.update_hand_input_rearm(.2);step()
	check(not actor.is_hand_input_ready(actor.left_hand) and not menu.is_open,"held Menu across close cannot rearm or reopen")
	neutral();left.set_input("menu_button",true);step()
	check(menu.is_open,"neutral recovery permits a fresh Menu press")
	left.set_input("menu_button",false);step()
	menu.selected=1
	right.set_input("ax_button",true);step()
	check(menu.is_open and menu.settings_page=="movement","A selects menu item without closing pause")
	menu.set_open(false)
	left.set_input("menu_button",true)
	actor.update_hand_input_rearm(.2)
	check(not actor.is_hand_input_ready(actor.left_hand),"Menu is included in production neutral-input gate")
	var map=load("res://openxr_action_map.tres")
	var bound:=false
	var system_bound:=false
	for profile in map.interaction_profiles:
		if str(profile.interaction_profile_path)!="/interaction_profiles/oculus/touch_controller":continue
		for binding in profile.bindings:
			if binding.action.resource_name!="menu_button":continue
			bound=bound or binding.binding_path=="/user/hand/left/input/menu/click"
			system_bound=system_bound or "system" in binding.binding_path or binding.binding_path.begins_with("/user/hand/right/")
	check(bound and not system_bound,"Touch pause action binds left Menu, not right/system Oculus button")
	menu.free();actor.free();XRServer.remove_tracker(left);XRServer.remove_tracker(right)
	left=null;right=null;map=null
	await process_frame
	print("MENU_ACTION_RESULT checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)
