extends SceneTree
class PlayerFixture extends "res://scripts/player.gd":
	func update_tracking()->bool:return tracking_available # Synthetic tracked inputs; never initialize OpenXR.
class Game extends Node:
	var paused:=false
	var dead:=false
	var complete:=false
	var health:=0.0
	var shield:=0.0
	var player:Node3D
	var weapon:Node3D
	var weapon_inventory:Node3D
	var field_consumables:Node3D
	var field_builder:Node3D
	var ammo_pickups:Node3D
	var revive_paddles:Node3D
var checks:=0
var failures:=0
var game:Game
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;print("FAIL ",label)
func run()->void:
	game=Game.new();root.add_child(game)
	var floor:=StaticBody3D.new();floor.collision_layer=1;var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(30,.2,30);floor.add_child(shape);floor.position.y=-.1;game.add_child(floor)
	game.player=PlayerFixture.new();game.add_child(game.player);game.player.setup(false);game.player.set_process(false);game.player.set_physics_process(false)
	game.weapon=load("res://scripts/weapon_rack.gd").new();game.add_child(game.weapon);game.weapon.setup(game.player);game.weapon.set_process(false);game.weapon.set_physics_process(false)
	for gun in game.weapon.weapons:gun.set_process(false);gun.set_physics_process(false)
	game.weapon_inventory=load("res://scripts/weapon_inventory.gd").new();game.add_child(game.weapon_inventory);game.weapon_inventory.setup(game.player,game.weapon);game.weapon_inventory.set_process(false)
	game.field_consumables=load("res://scripts/field_consumables.gd").new();game.add_child(game.field_consumables);game.field_consumables.setup(game.player,game.weapon,game);game.field_consumables.set_process(false)
	game.field_builder=load("res://scripts/field_builder.gd").new();game.add_child(game.field_builder);game.field_builder.setup(game.player,game.weapon,game);game.field_builder.set_physics_process(false)
	game.ammo_pickups=load("res://scripts/ammo_pickups.gd").new();game.add_child(game.ammo_pickups);game.ammo_pickups.setup(game.player,game.weapon,[]);game.ammo_pickups._builder=game.field_builder
	game.revive_paddles=load("res://scripts/revive_paddles.gd").new();game.add_child(game.revive_paddles);game.revive_paddles.setup(game.player,game.weapon);game.revive_paddles.set_process(false)
	await physics_frame;await physics_frame
	check(ProjectSettings.get_setting("application/config/version")=="0.9.4","isolated089 identity")
	check(game.player.DEFAULT_PLAYER_TOP_HEIGHT_M==1.8288 and game.weapon_inventory.SLOT_LIMIT==6,"six-foot height/six carried slots retained")
	for spec in [[8,["ready","cover_open","box_removed","needs_feed","box_seated","needs_charge"]],[25,["ready","needs_mag","needs_rack"]],[13,["ready","needs_mag","needs_rack"]],[5,["ready","needs_bolt","needs_mag"]]]:
		var gun:Node3D=game.weapon.weapons[spec[0]]
		for stage in spec[1]:
			gun.reload_state=stage
			check(game.weapon_inventory._transfer_safe(spec[0]),"idle reload stage can transfer "+str(spec[0])+" "+stage)
		gun.reload_state="ready"
	game.weapon.weapons[8].contact=true;check(not game.weapon_inventory._transfer_safe(8),"actual M60 part manipulation still owns hand");game.weapon.weapons[8].contact=false
	game.weapon.weapons[25].reload_state="held_mag";check(not game.weapon_inventory._transfer_safe(25),"held S85 clip still owns hand");game.weapon.weapons[25].reload_state="ready"
	# Real persistent ownership transfer with an empty M60. Drop cannot conjure ammunition.
	game.weapon_inventory.owned.assign([8,0,25]);game.weapon.selected=8
	var m60:Node3D=game.weapon.weapons[8];m60.ammo=0;m60.seated=0;m60.reload_state="box_removed"
	check(game.weapon_inventory._can_interact(),"empty M60 permits unrelated pickup intent")
	var reserves:Dictionary=game.weapon.reserves.duplicate()
	check(game.weapon_inventory.drop_weapon(8),"empty M60 drops onto reachable floor")
	check(game.weapon_inventory.pickup_weapon(8),"same empty M60 can be re-picked")
	check(m60.ammo==0 and m60.seated==0 and m60.reload_state=="box_removed" and game.weapon.reserves==reserves,"empty state and reserve conserved on re-pickup")
	game.weapon.selected=25;game.weapon.weapons[25].ammo=0;game.weapon.weapons[25].reload_state="needs_rack"
	check(game.weapon_inventory.make_room("weapon_17") and not game.weapon_inventory.has_weapon(25),"full inventory replaces unloaded S85 slot")
	check(game.weapon_inventory.pickup_weapon(17),"replacement enters vacated slot")
	check(game.weapon.weapons[25].ammo==0 and game.weapon.weapons[25].reload_state=="needs_rack","dropped S85 stays unloaded")
	# Resource collection has no cap and no automatic proximity credit.
	var amounts:={"pistol":16,"smg":20,"rifle":32,"shells":6,"sniper":5,"builds":6}
	for family in amounts:
		if family=="builds":game.field_builder.charges=1000000
		else:game.weapon.reserves[family]=1000000
		var box:Node3D=game.ammo_pickups.spawn_box(family,game.player.get_view_camera().global_position)
		await physics_frame;await physics_frame
		check(not box.get_meta("collected"),"proximity cannot collect "+family)
		check(game.ammo_pickups.collect_box(box)==amounts[family],"uncapped exact packet "+family)
		check((game.field_builder.charges if family=="builds" else game.weapon.reserves[family])==1000000+amounts[family],"large balance credits "+family)
		check(game.ammo_pickups.collect_box(box)==0,"duplicate collection rejected "+family)
	# Test actual XR grip arbitration with controller trackers, XR runtime remains off.
	for hand in [game.player.left_hand,game.player.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="playtest089_"+str(hand.get_instance_id());XRServer.add_tracker(tracker)
		hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,1.1,-.2)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);trackers[hand]=tracker
	game.player.xr_enabled=true;game.player.tracking_available=true;game.player.xr_camera.position.y=game.player.DEFAULT_EYE_HEIGHT_M
	await process_frame;game.player.update_hand_input_rearm(.2)
	for hand in [game.player.left_hand,game.player.right_hand]:hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(0,1.1,-.2))
	game.weapon.selected=0;game.weapon.weapons[0].global_position=Vector3(5,1,0)
	for box in game.ammo_pickups.boxes:box.hide()
	var supply:Node3D=game.ammo_pickups.spawn_box("builds",Vector3(0,1.1,-.7))
	var targets:Array=game.ammo_pickups.get_grip_targets()
	if targets.is_empty():
		for hand in [game.player.left_hand,game.player.right_hand]:print("SUPPLY_DEBUG ready=",game.player.is_hand_input_ready(hand)," eligible=",game.weapon_inventory._hand_eligible(hand)," can=",game.weapon_inventory._can_interact()," hand=",hand.global_transform," head=",game.player.get_view_camera().global_position)
	check(not targets.is_empty(),"explicit grip exposes aimed supply target")
	if not targets.is_empty():check(game.ammo_pickups.handle_grip(targets[0].id,targets[0].hand) and supply.get_meta("collected"),"grip collects aimed supply")
	game.ammo_pickups._process(0)
	check(game.ammo_pickups.aim_rings.size()==2,"ammo/build pickup circles and name labels exist for both hands")
	game.player.xr_enabled=false
	# Preparation is retained, but contact has no dwell delay.
	var consumables:Node3D=game.field_consumables
	var script=load("res://scripts/field_consumables.gd")
	for kind in ["banana","soda","shaker"]:
		for point in [Vector3(0,-.3048,-.3048),Vector3(0,-.30,-.48),Vector3(.20,-.20,-.40)]:
			check(script.within_consumption_volume(point,Transform3D.IDENTITY,kind),"inclusive forward/down reach "+kind)
		check(not script.within_consumption_volume(Vector3(0,0,-1),Transform3D.IDENTITY,kind),"remote item not consumed "+kind)
	consumables.collect(0);consumables.equip("shaker");check(not consumables.consume_at_mouth(.011,true,true),"unprepared shaker cannot drink")
	consumables.phase="consume";check(consumables.consume_at_mouth(1.0/90,true,true) and game.shield==50,"first valid contact consumes prepared shaker")
	# Menu enables locomotion but gates weapon/build/item actions; right stick scroll only.
	var service=load("res://scripts/item_catalog_service_088.gd").new();game.add_child(service);service.setup(game,true)
	var menu=load("res://scripts/menu.gd").new();game.add_child(menu);menu.setup(game.player);menu.set_item_catalog(service);menu.set_open(true);menu.settings_page="loadout";menu._refresh()
	check(game.player.input_enabled and game.player.inventory_open and menu.backpack_is_open(),"backpack enables locomotion input")
	check(not game.weapon.weapons[0]._input_allowed(),"backpack trigger cannot fire gun")
	check(game.ammo_pickups.get_grip_targets().is_empty(),"backpack grip cannot collect world items")
	check(not game.field_consumables._allowed() and not game.weapon_inventory._can_interact(),"backpack permits locomotion without consumable/ground-weapon actions")
	check(menu.weapon_settings.motion_damping==1.0,"fresh default motion damping100percent")
	var cards:Array=service.cards();var awp:=-1;var spr:=-1
	for i in range(12,cards.size()):
		if cards[i].kind=="weapon" and cards[i].catalog==5:awp=i
		if cards[i].kind=="weapon" and cards[i].catalog==13:spr=i
	check(awp>=12 and awp<spr,"AWP appears left/before SPR in selector")
	for item in [[2,"pistol"],[3,"rifle"],[6,"shells"],[7,"sniper"],[10,"smg"],[11,"builds"]]:check(cards[item[0]].family==item[1],"fixed top12resource order retained "+str(item[0]))
	game.player.xr_enabled=true;game.player.tracking_available=true;game.player.update_hand_input_rearm(.2)
	trackers[game.player.left_hand].set_input("primary",Vector2(0,1));trackers[game.player.right_hand].set_input("primary",Vector2.ZERO)
	var previous:Vector3=game.player.global_position
	game.player._physics_process(.05)
	check(game.player.global_position.z<previous.z-.01,"actual left-stick physics moves player while backpack open")
	await process_frame;await process_frame
	var ui:Node3D=menu.catalog_ui;ui._armed=true;ui.scroll.scroll_vertical=0;ui._process(.1)
	check(ui.scroll.scroll_vertical==0,"left locomotion stick does not scroll backpack")
	trackers[game.player.right_hand].set_input("primary",Vector2(0,-.8));ui._process(.1)
	check(ui.scroll.scroll_vertical>0,"right stick scrolls independently of left locomotion")
	for tracker in trackers.values():tracker.set_input("primary",Vector2.ZERO)
	game.player.xr_enabled=false
	menu.settings_page="movement";menu._refresh();check(not game.player.input_enabled and not game.player.inventory_open,"settings still suspend movement")
	menu.set_open(false)
	# Fold pitched controller direction across vertical without inverting forward locomotion.
	for yaw in [-2.2,-.6,0.0,.9,2.7]:
		var expected:Vector3=Basis(Vector3.UP,yaw)*Vector3.FORWARD
		for pitch in [0.0,1.4,PI*.5,1.7,2.0,-1.4,-1.7]:
			var heading:Vector3=game.player.controller_horizontal_heading(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch))
			check(heading.dot(expected)>.999,"controller tilt preserves horizontal direction")
	# Real charging integration, stationary10s / energetic5.5s; teleport input never accelerates.
	game.player._movement_heading_ready_089=false
	for step in 81:
		var pitch:float=step*.025
		check(game.player.continuous_controller_heading_089(Basis(Vector3.RIGHT,pitch)).dot(Vector3.FORWARD)>.999,"continuous heading past vertical")
	game.player._movement_heading_ready_089=false
	game.player.continuous_controller_heading_089(Basis.IDENTITY)
	for step in 65:
		check(game.player.continuous_controller_heading_089(Basis(Vector3.FORWARD,step*TAU/64)).dot(Vector3.FORWARD)>.999,"barrel roll cannot reverse controller locomotion")
	var paddles:Node3D=game.revive_paddles;paddles.equip()
	for speed in [0.0,.7]:
		paddles._clear_charge();var elapsed:=0.0
		while not paddles.charge_ready and elapsed<11:
			var shift:float=0 if speed==0 else (.0035 if roundi(elapsed/.01)%2==0 else -.0035)
			paddles.step_contacts(.01,Vector3(shift,1,-.3),Vector3(.2+shift,1,-.3),true);elapsed+=.01
		check(absf(elapsed-(10 if speed==0 else 5.5))<.05,"paddle charge physical time "+str(speed)+" elapsed="+str(elapsed))
	check(paddles._fill!=null and paddles._label.pixel_size*paddles._label.font_size<.02,"paddle progress bar and smaller text")
	paddles.stow()
	# Physical hand adjustments independent of render scale, without moving aim/tracking.
	var fit=load("res://scripts/playtest_fit_088.gd")
	for spec in [[7,Vector3(0,0,.05715)],[25,Vector3(0,.0508,.127)],[1,Vector3(0,0,.0381)+Basis(Vector3.RIGHT,deg_to_rad(-35))*Vector3.UP*.127+Vector3.FORWARD*.0254],[12,Basis(Vector3.RIGHT,deg_to_rad(-35))*Vector3.DOWN*.1016+Vector3.UP*.1524],[29,Vector3.BACK*.0508]]:
		var gun:Node3D=game.weapon.weapons[spec[0]]
		if spec[0]==12:gun=gun.guns[0]
		check((fit.hand_offset(gun)*gun.model.global_basis.get_scale().x).is_equal_approx(spec[1]),"physical089hand offset "+str(spec[0]))
	for index in game.weapon.ACTIVE_WEAPON_INDICES:
		var gun:Node3D=game.weapon.weapons[index]
		var guns:Array=gun.guns if gun.has_method("get_reticle_entries") else [gun]
		for part in guns:
			part.recoil_pitch=.1;part.recoil_yaw=.02;part.recoil=.03;part._apply_recoil_visual()
			if not part.has_method("sample_motion") and load("res://scripts/reticle_bounce_071.gd").profile(part).is_empty():
				check(absf(part.model.rotation.x-.125)<.0001 and absf(part.model.rotation.y-.025)<.0001,"all firearm output recoil gains25percent "+str(index))
			part._process(0)
			if part.guide!=null:check(part.guide.mesh==null,"legacy reload cube has no geometry "+str(index))
			if part.ammo_panel!=null:check(not part.ammo_panel.connector.visible,"ammo counter stem removed "+str(index))
	check(m60.belt_feed_grip.mesh==null and m60.feed_socket.mesh==null,"M60 old gray feed proxy removed")
	var sprgun:Node3D=game.weapon.weapons[13]
	check(sprgun.charging_grip_point().distance_to(sprgun.bolt.position+sprgun.bolt.mesh.get_aabb().get_center())<.0001,"SPR reload contact uses actual T handle mesh")
	check(absf((sprgun.get_magazine_offer_point().y-sprgun.OFFER_POINT.y)*sprgun.visual_model_scale()-.127)<.0001,"SPR offer5in higher")
	var awpgun:Node3D=game.weapon.weapons[5]
	check(absf((awpgun.get_magazine_offer_point().y-awpgun.OFFER_POINT.y)*awpgun.visual_model_scale()-.1016)<.0001,"AWP offer4in higher")
	var rocket:Node3D=game.weapon.weapons[27]
	check(absf((rocket.rocket_offer_point().z-rocket.ROCKET_OFFER.z)*rocket.visual_model_scale()-.3048)<.0001,"rocket offer6in closer")
	check(game.weapon.weapons[0].motion_damping==1.0,"gun default damping100percent")
	for kind in ["build_lightning","revive_charge","revive_ready","ammo_pickup","shot_shotgun","shot_suppressed","consume_open"]:
		var wav:AudioStreamWAV=AshAudioBank.sample(kind);check(wav.data.size()>4000 and wav.mix_rate==48000,"new48k layered sound "+kind)
	await preload("res://tests/regression_094_checks.gd").run(self)
	# No controller tracker survives this XR-off fixture.
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	game.queue_free();await process_frame;await process_frame
	print("REGRESSION_094 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false")
	quit(0 if failures==0 else 1)
