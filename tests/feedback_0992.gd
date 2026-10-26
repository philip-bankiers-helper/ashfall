extends SceneTree
var checks:=0
var failures:=0
const Reference=preload("res://scripts/reference_audio_099.gd")
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func freeze(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze(child)
func forbidden(node:Node)->bool:
	for child in node.find_children("*","Node",true,false):
		if str(child.name).contains("Arrow") or child is Label3D or child.name=="AmmoReadoutPanel":return true
	return false
func run()->void:
	var game:Node3D=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title();freeze(game)
	var actor:Node3D=game.player;actor.input_enabled=true
	var inventory:Node3D=game.weapon_inventory;var guns:Array=game.weapon.weapons
	for index in [1,7,8,9,13,25]:
		var prop:Node3D=inventory._create_prop(index)
		check(not forbidden(prop),"inert world/loadout clone has no live arrows/counter "+str(index))
		if index==7:
			for cartridge in guns[index].cartridges:check(prop.get_child(0).get_node_or_null(guns[index].model.get_path_to(cartridge))==null,"inert Magnum cartridges removed")
		if index==8:
			var path:NodePath=guns[8].model.get_path_to(guns[8].belt_box)
			var box:Node3D=prop.get_child(0).get_node(path)
			check(box.position.is_equal_approx(guns[8].get_box_seat()),"ground M60 uses accepted held box seat")
		prop.free()
	check(absf(inventory.HOVER_HEIGHT-.4452)<.0001,"loot surface gap exactly one foot lower")
	var floor_body:=StaticBody3D.new();game.add_child(floor_body);floor_body.position=Vector3(200,-.10,0);floor_body.collision_layer=1
	var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(40,.2,40);floor_body.add_child(shape)
	await physics_frame;await physics_frame
	for node in [inventory._create_prop(7),game.field_consumables.make_prop("shaker"),game.field_consumables.make_prop("soda"),game.field_consumables.make_prop("banana")]:
		if node.get_parent()==null:game.add_child(node)
		node.global_position=Vector3(200,1,0);inventory._settle_on_surface(node)
		check(absf(inventory._lowest_mesh_point(node)-.4452)<.002,"guns and each heal share actual floor clearance")
		node.free()
	floor_body.free()
	var marks:Node3D=game.building_input.team_marks
	for i in 8:
		marks._create_mark(Vector3(i,2,-5),Vector3.UP,i)
		check(marks.records.size()==1 and marks._visuals.size()==1,"new mark replaces previous mark "+str(i))
	check(marks.TITLES[0]=="HOLD" and marks.TITLES[7]=="GO HERE" and marks.TITLES[2]=="PING","explicit mark labels")
	var targets:Array=[{"id":"inventory_pickup:7","hand":actor.right_hand,"position":Vector3(0,0,-1)},{"id":"supply:0","hand":actor.right_hand,"position":Vector3(0,0,-.6)},{"id":"consumable:pickup:1","hand":actor.right_hand,"position":Vector3(0,0,-.8)}]
	actor.right_hand.global_position=Vector3.ZERO
	check(preload("res://scripts/pickup_focus0992.gd").nearest(actor.right_hand,targets).id=="supply:0","closest eligible supply beats weapon and heal")
	targets[0].position=Vector3(0,0,-.4)
	check(preload("res://scripts/pickup_focus0992.gd").nearest(actor.right_hand,targets).id=="inventory_pickup:7","weapon wins when nearest")
	# Real RFB endpoint path, caps and recovery. Supported trajectory is exactly40%.
	var rfb:Node3D=guns[23];var one:Array=[]
	for supported in [false,true]:
		rfb.reset_weapon();rfb.supported=supported
		for i in 230:
			if i%8==0 and i<192:rfb._kick_recoil(.012,deg_to_rad(3))
			rfb._recover_recoil(1.0/90);rfb._apply_recoil_visual()
			var sample:=Vector3(rfb.model.rotation.x,rfb.model.rotation.y,rfb.model.position.z)
			if not supported:one.append(sample)
			else:check(sample.distance_to(one[i]*.4)<.00001,"supported RFB equals40% one-hand at frame "+str(i))
	check(one[60].x>one[5].x and one[60].x>absf(one[60].y)*5,"one-hand RFB retains rising mostly vertical trajectory")
	rfb.supported=false
	var s85:Node3D=guns[25];s85.reload_state="held_mag";var offer:Vector3=s85.get_magazine_offer_point();var scale:float=s85.visual_model_scale()
	for offset in [Vector3(0,.065,0),Vector3(.14,.08,0),Vector3(0,.30,.08)]:
		check(s85._in_reload_reach(offer+offset/scale,s85.get_magazine_insert_point(),.10),"larger physical S85 insertion region "+str(offset))
		var zone:Dictionary=s85.get_reload_zones()[0]
		check(s85._in_reload_reach(offer+offset/scale,zone.position,zone.radius),"grip arbitration and stroke use same S85 volume")
	for offset in [Vector3(0,-.02,0),Vector3(.30,.1,0),Vector3(0,.60,0)]:check(not s85._in_reload_reach(offer+offset/scale,s85.get_magazine_insert_point(),.10),"S85 excludes below/far unrelated positions")
	var hud:Node3D=game.combat_hud;game.paused=false;hud.refresh(0)
	for node in hud.find_children("*","Label3D",true,false):check(not node.no_depth_test,"HUD text obeys world depth")
	for node in hud.reference_hud.find_children("*","MeshInstance3D",true,false):check(not node.material_override.no_depth_test,"reference HUD surfaces obey depth")
	check(hud.global_basis.get_scale().is_equal_approx(Vector3.ONE*2.5),"HUD angular size retained at deeper physical plane")
	var dummy:=preload("res://scripts/practice_dummy.gd").new();game.add_child(dummy);dummy.position=Vector3(200,0,-4)
	hud.notify_outgoing(20,dummy.get_instance_id());hud.notify_outgoing(30,dummy.get_instance_id());hud.notify_outgoing(45,dummy.get_instance_id(),true)
	var numbers:Node3D=hud.damage_numbers0992
	check(numbers.entries.size()==3 and numbers.entries[0].label.text=="20" and numbers.entries[1].label.text=="30" and numbers.entries[2].label.text=="45","three hits produce three independent values")
	check(not hud.outgoing_number.visible and hud.outgoing_amount==0,"no outgoing accumulator near HUD")
	for entry in numbers.entries:check(not entry.label.no_depth_test and entry.start.y>dummy.position.y+1.85,"small numbers live above/right of target in world")
	numbers._process(.9);check(numbers.entries.is_empty(),"damage numbers expire")
	var pads:Node3D=game.revive_paddles;pads.equip();pads._add_charge(1);var stream:AudioStreamWAV=pads._audio.stream
	check(stream==Reference.generic("revive_ready_full0992",0) and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"full activation is one-shot")
	pads.tick_ready_window097(3.49);check(pads.charge_ready,"ready retained through measured interval")
	pads.tick_ready_window097(.02);check(not pads.charge_ready and not pads._audio.playing,"ready resets after3.5seconds")
	var supplies:Node3D=game.field_consumables;supplies.held_kind="shaker";supplies.phase="shake";supplies._shake_sound0992();var first_voice:Node=supplies._shake_voice0992
	check(first_voice.stream.get_length()>3 and first_voice.stream==Reference.action("consume_shake","shaker",0),"full shaker phrase assigned")
	for i in 15:supplies._shake_sound0992()
	check(supplies._shake_voice0992==first_voice,"continued motion reuses one continuous shaker voice")
	supplies.stow(false);check(not first_voice.playing,"stow stops shaker recording")
	check(Reference.generic("item_stow",0)!=Reference.generic("item_pickup",0) and Reference.generic("item_equip",0)!=Reference.generic("item_pickup",0),"holster/draw cue differs from physical pickup")
	# Every sub30Hz strafe frame must publish current scene/eye coordinates.
	var spr:Node3D=guns[13];var optic:Node3D=spr.optic;var camera:Camera3D=actor.get_view_camera()
	spr.show();spr.global_transform=Transform3D(Basis.IDENTITY,Vector3(210,5,0))
	for i in 36:
		spr.global_position.x+=.01
		camera.global_transform=Transform3D(Basis.IDENTITY,optic.lens.global_position+Vector3.BACK*.20)
		optic.refresh_optic(1.0/90)
		check(optic.active and optic._displayed_pose.origin.distance_to(camera.global_position)<.00001,"SPR publishes current strafe frame "+str(i))
		check(optic.scope_camera.global_position.distance_to(camera.global_position)<.00001,"SPR scene camera matches current eye "+str(i))
	# Shared provider, including a pixel check of the actual rendered-source reversal.
	var icons=preload("res://scripts/weapon_icons_094.gd")
	for index in [14,15,16,29]:
		var before:Image=load("res://assets/ui/catalog0991/weapon_%d.png"%index).get_image();before.rotate_180()
		var corrected:Image=icons.icon(index).get_image()
		check(corrected.get_data()==before.get_data(),"sword/knife thumbnail reversed exactly once "+str(index))
	for index in [14,15,16]:
		var sword:Node3D=guns[index];sword.show();sword.model.show();sword._process(.01)
		for i in 6:actor.global_position.x+=.04;sword._process(.01)
		check(sword._gold_trail097.mesh.get_surface_count()==0,"body strafing cannot generate sword trails "+str(index))
		var saved_eye:Transform3D=camera.global_transform
		for i in 8:camera.rotate_x(.04);sword._process(.01)
		check(sword._gold_trail097.mesh.get_surface_count()>0,"real weapon swing generates full-blade trail "+str(index))
		camera.global_transform=saved_eye
		sword.hide()
	var menu:Node3D=game.field_menu;menu.set_open(true)
	check(menu.settings_page=="pause" and menu._labels().size()==4,"pause hub precedes settings")
	menu._choose(1);check(menu.settings_page=="root","settings button reaches existing options")
	menu._choose(4);check(menu.settings_page=="pause" and menu.is_open,"settings Back returns to pause hub")
	menu._choose(0);check(not menu.is_open and actor.input_enabled,"Resume returns control")
	menu.set_open(true);menu._choose(3)
	check(game.front_end_active and game.front_menu.active and game.front_menu.page=="lobby","Home returns to real pedestal lobby")
	game.front_menu.selected_map="range";game._start_from_title();freeze(game)
	var old:Node3D=game.active_sandbox_map;check(is_instance_valid(old),"Ready enters selected range")
	game._return_home0992();game._start_from_title();freeze(game)
	check(game.active_sandbox_map==old,"range reentry does not duplicate map")
	game._return_home0992();game.front_menu.selected_map="valley";game._start_from_title();freeze(game)
	check(game.active_sandbox_map==null and game.world.visible and actor.global_position.distance_to(game.world.player_spawn)<.1,"Home map selection can restore valley")
	dummy.free();game.queue_free();await process_frame;await process_frame
	print("FEEDBACK_0992 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false");quit(failures)
