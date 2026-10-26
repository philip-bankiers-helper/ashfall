extends SceneTree
class SyntheticPlayer extends "res://scripts/player.gd":
	func is_hand_input_ready(_hand:XRController3D)->bool:return tracking_available
var count:=0
var failures:=0
var chosen:Array=[]
var dropped:Array=[]
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	count+=1
	print("PASS " if value else "FAIL ",label)
	if not value:failures+=1
func run()->void:
	var actor=SyntheticPlayer.new();root.add_child(actor);actor.setup(false)
	await process_frame
	actor.set_physics_process(false)
	var menu=load("res://scripts/menu.gd").new();root.add_child(menu);menu.setup(actor);menu.set_process(false)
	menu.loadout_provider=func()->Array[String]:return ["internal_gun_id","internal_gun_2","back"]
	menu.loadout_icon_provider=func()->Array[Texture2D]:return [load("res://assets/ui/wheel_weapon_0.svg"),load("res://assets/ui/wheel_weapon_1.svg"),load("res://assets/ui/wheel_weapon_2.svg")]
	menu.loadout_selected.connect(func(i):chosen.append(i))
	menu.loadout_dropped.connect(func(i):dropped.append(i))
	menu.set_open(true);menu.settings_page="loadout";menu._refresh()
	for i in range(3):
		check(menu._rows[i].text=="" and menu._buttons[i].text=="","slot%d has no weapon words"%i)
		check(menu._loadout_icons[i].mesh is QuadMesh and menu._buttons[i].icon!=null,"slot%d flat pictures in VR/desktop"%i)
	for hand in ["left","right"]:
		actor.dominant_hand=hand;menu.selected=0;menu._cancel_loadout_gesture()
		menu._loadout_gesture(.01,true,false,false)
		menu._loadout_gesture(.01,true,true,false)
		check(chosen.is_empty(),hand+" A-down never equips")
		menu._loadout_gesture(.01,true,false,false)
		check(chosen==[0],hand+" short A-up equips once");chosen.clear()
		menu._loadout_gesture(.01,true,true,false)
		menu._loadout_gesture(2.9,true,true,false)
		check(dropped.is_empty() and menu._drop_ring.visible,hand+" hold shows small nontext ring before threshold")
		menu._loadout_gesture(.11,true,true,false)
		menu._loadout_gesture(4.,true,true,false)
		menu._loadout_gesture(.01,true,false,false)
		check(dropped==[0] and chosen.is_empty(),hand+" 3s hold drops once with no release equip");dropped.clear()
		menu._loadout_gesture(.01,true,false,true)
		menu._loadout_gesture(1.,true,false,true)
		check(dropped==[0],hand+" fresh grip instant drop once");dropped.clear()
		menu._loadout_gesture(.01,true,false,false)
		menu._loadout_gesture(.01,true,true,false)
		menu._loadout_gesture(2.,true,true,false)
		menu.selected=1;menu._loadout_gesture(4.,true,true,false);menu._loadout_gesture(.01,true,false,false)
		check(dropped.is_empty() and chosen.is_empty(),hand+" highlight change cancels hold/release")
		menu._loadout_gesture(.01,true,true,false)
		menu._loadout_gesture(.01,false,true,false)
		menu._loadout_gesture(4.,true,true,false);menu._loadout_gesture(.01,true,false,false)
		check(dropped.is_empty() and chosen.is_empty(),hand+" tracking loss requires neutral")
		menu._loadout_gesture(.01,true,true,false);menu.set_open(false)
		menu._loadout_gesture(4.,true,true,false)
		check(dropped.is_empty() and chosen.is_empty(),hand+" closing cancels gesture")
		menu.set_open(true);menu.settings_page="loadout";menu._refresh()
	for hand in ["left","right"]:
		actor.dominant_hand=hand; actor.xr_enabled=true;actor.tracking_available=true
		var controller=actor.get_weapon_hand()
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="backpack_"+hand
		XRServer.add_tracker(tracker);controller.tracker=tracker.name
		tracker.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		tracker.set_input("primary",Vector2.ZERO);tracker.set_input("grip",0.);tracker.set_input("trigger",0.);tracker.set_input("ax_button",false)
		menu.selected=0;menu.is_open=true;menu.settings_page="loadout";menu._cancel_loadout_gesture();menu._process(.01)
		tracker.set_input("ax_button",true);menu._process(.01)
		check(chosen.is_empty(),hand+" actual tracker A-down defers equip")
		tracker.set_input("ax_button",false);menu._process(.01)
		check(chosen==[0],hand+" actual tracker A-up equips while actor input disabled");chosen.clear()
		tracker.set_input("grip",1.);menu._process(.01);menu._process(.01)
		check(dropped==[0],hand+" actual tracker grip drops exactly once");dropped.clear()
		tracker.set_input("grip",0.);menu._process(.01)
		XRServer.remove_tracker(tracker)
	actor.xr_enabled=false
	check(menu._drop_ring.mesh.size==Vector2(.065,.065),"ring is 6.5cm no text geometry")
	print("BACKPACK_041 ",count," checks failures=",failures)
	menu.queue_free();actor.queue_free();await process_frame
	quit(1 if failures else 0)



