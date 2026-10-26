extends SceneTree
var checks:=0
var failures:=0
var game:Node3D
var trackers:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;print("FAIL ",label)
func sample_grip(hand:Node3D,value:float)->void:
	trackers[hand].set_input("grip",value);game.player._objective_grip_frame=-1;game.player.update_objective_grips()
func run()->void:
	game=load("res://scripts/main.gd").new();root.add_child(game)
	await process_frame;await physics_frame
	check(game.front_end_active and game.front_menu.active,"normal boot enters title")
	check(game.paused and not game.player.input_enabled,"title gates gameplay")
	game.front_menu.buttons[1].pressed.emit()
	check(game.field_menu.is_open and not game.front_menu.active,"title Settings opens working settings")
	game.field_menu.set_open(false)
	check(game.front_menu.active and not game.player.input_enabled,"closing Settings returns to title")
	game.front_menu.buttons[0].pressed.emit()
	check(not game.front_end_active and game.player.input_enabled,"Play starts game")
	game.set_process(false);game.paused=false;game.dead=false;game.complete=false
	for node in game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	var player:Node3D=game.player
	player.position=Vector3(0,30,0);player.input_enabled=true
	for hand in [player.left_hand,player.right_hand]:
		var tracker:=XRControllerTracker.new();tracker.type=XRServer.TRACKER_CONTROLLER;tracker.name="playtest090_"+str(hand.get_instance_id());XRServer.add_tracker(tracker)
		hand.tracker=tracker.name;hand.pose="grip";tracker.set_pose("grip",Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3(-.3 if hand==player.left_hand else .3,1.1,-.2)),Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH)
		tracker.set_input("grip",0.0);tracker.set_input("trigger",0.0);tracker.set_input("primary",Vector2.ZERO);trackers[hand]=tracker
	player.xr_enabled=true;player.tracking_available=true;player.xr_camera.position.y=player.DEFAULT_EYE_HEIGHT_M
	await process_frame;player.update_hand_input_rearm(.2)
	for prop in game.weapon_inventory.pickups.values():prop.hide()
	for prop in game.field_consumables.pickups:prop.hide()
	for box in game.ammo_pickups.boxes:box.hide()
	game.weapon.is_holstered=true
	var hand:Node3D=player.left_hand
	for family in ["pistol","rifle","smg","sniper","shells","builds"]:
		for distance in [.25,.8,1.8]:
			var point:Vector3=hand.global_position+Vector3.FORWARD*distance
			var box:Node3D=game.ammo_pickups.spawn_box(family,point)
			var before:int=game.field_builder.charges if family=="builds" else game.weapon.reserves[family]
			sample_grip(hand,0.0);sample_grip(hand,1.0)
			var after:int=game.field_builder.charges if family=="builds" else game.weapon.reserves[family]
			check(box.get_meta("collected") and after-before==box.get_meta("amount"),"full grip dispatcher credits "+family+" at "+str(distance))
			sample_grip(hand,1.0)
			check((game.field_builder.charges if family=="builds" else game.weapon.reserves[family])==after,"held grip cannot duplicate "+family)
	var remote:Node3D=game.ammo_pickups.spawn_box("pistol",hand.global_position+Vector3.FORWARD*2.2)
	sample_grip(hand,0);sample_grip(hand,1);check(not remote.get_meta("collected"),"supply range remains bounded")
	remote.hide()
	var blocked:Node3D=game.ammo_pickups.spawn_box("pistol",hand.global_position+Vector3.FORWARD*.8)
	var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(.6,.6,.05);wall.add_child(shape);game.add_child(wall);wall.global_position=hand.global_position+Vector3.FORWARD*.45
	await physics_frame;sample_grip(hand,0);sample_grip(hand,1);check(not blocked.get_meta("collected"),"supply grip cannot pass through wall")
	wall.queue_free();blocked.hide();sample_grip(hand,0)
	# Exercise the VR title's actual pointing/trigger path with synthetic tracking.
	var title=load("res://scripts/front_menu_091.gd").new();game.add_child(title);title.setup(player);title.set_process(false);title.set_active(true)
	var actions:=[0];title.play_requested.connect(func():actions[0]+=1)
	var button_center:Vector2=title.buttons[0].get_global_rect().get_center()
	var target:Vector3=title.board.to_global(Vector3((button_center.x/1280-.5)*1.6,(.5-button_center.y/800)*1.0,0))
	var pointer_hand:Node3D=player.get_weapon_hand();var raw:=Transform3D(Basis.looking_at(target-pointer_hand.global_position,Vector3.UP)*Basis(Vector3.RIGHT,PI*.5),pointer_hand.global_position)
	pointer_hand.global_transform=raw;trackers[pointer_hand].set_input("trigger",0.0);title._process(.011);title._process(.011)
	trackers[pointer_hand].set_input("trigger",1.0);title._process(.011)
	check(actions[0]==0,"press alone cannot activate title")
	trackers[pointer_hand].set_input("trigger",0.0);title._process(.011)
	check(actions[0]==1,"VR title controller ray and fresh trigger activates Play")
	title._process(.011);check(actions[0]==1,"held title trigger cannot repeat")
	trackers[pointer_hand].set_input("trigger",0.0);title.set_active(false);title.leave_lobby();title.queue_free()
	player.xr_enabled=false
	var pistol:Node3D=game.weapon.weapons[19]
	for stage in ["reset","idle","fire","eject","insert","rack"]:
		if stage=="reset":pistol.reset_weapon()
		elif stage=="fire":
			var before:int=pistol.ammo;pistol.cooldown=0;pistol._semi_armed=true;pistol.fire()
			check(pistol.ammo==before-1 and pistol._carrier_time>0,"1911 actually discharges for slide cycle check")
		elif stage=="eject":pistol.eject_magazine()
		elif stage=="insert":pistol.grab_magazine();pistol.insert_magazine()
		elif stage=="rack":pistol.rack_bolt()
		pistol._process(.02 if stage=="fire" else 0)
		check(absf(pistol.bolt.position.x)<.00001,"1911 slide centered "+stage)
	var spr:Node3D=game.weapon.weapons[13]
	var center:Vector3=spr.charging_grip_point()
	check(absf(center.x)<.003 and center.y>.060 and center.z>.0,"SPR contact is rear upper T-handle, not side assist")
	check(spr.bolt.mesh.get_faces().size()/3==646,"both source charging-handle pieces move together")
	check(spr.optic._material.shader.code.contains("float ring=") and not spr.optic._material.shader.code.contains("float h=step"),"SPR circle-and-dot replaces crosshair")
	var s85:Node3D=game.weapon.weapons[25];var offer:Transform3D=s85.get_offered_magazine_transform()
	check(absf(s85.global_basis.z.normalized().dot(offer.basis.z.normalized())-1)<.00001,"S85 clip roll keeps bullets pointing forward")
	check(absf(s85.global_basis.y.normalized().angle_to(offer.basis.y.normalized())-PI*.25)<.00001,"S85 offered clip rotates45degrees")
	check(absf((s85.get_magazine_offer_point().y-s85.OFFER_POINT.y)*s85.visual_model_scale()-.1524)<.00001,"S85 offer up6physical inches")
	for gun in game.weapon.weapons:
		if gun.ammo_panel==null:continue
		gun.update_ammo_display()
		check(gun.ammo_panel.rotation.is_zero_approx(),"fixed backward readout "+str(gun.name))
		check(absf(gun.ammo_label.font_size*gun.ammo_label.pixel_size*gun.ammo_label.global_basis.get_scale().x-.0143)<.00001,"consistent physical readout font "+str(gun.name))
	var pair:Node3D=game.weapon.weapons[11];pair.update_ammo_display()
	check(pair.guns[0].ammo_panel.position.x<0 and pair.guns[1].ammo_panel.position.x>0,"dual readouts on opposite inside receiver faces")
	check(player.process_priority==90 and game.body_visual.process_priority==100,"current gun, glove, then body render order")
	var gun:Node3D=game.weapon.weapons[0];game.weapon.selected=0;gun.show();gun.model.show();gun.global_transform=Transform3D.IDENTITY
	var a:Vector3=gun.get_shot_transform().origin;var end:=a+Vector3.FORWARD*10;game._tracer(a,end);var i:int=posmod(game._tracer_cursor-1,game.EFFECT_POOL_SIZE)
	gun.global_position.x+=.3;game._update_effect_pool(.011)
	var beam:MeshInstance3D=game._tracers[i]
	var start:Vector3=beam.global_position-beam.global_basis.y*.5
	check(start.distance_to(gun.get_shot_transform().origin)<.0001,"strafe tracer starts at current muzzle")
	check((beam.global_position+beam.global_basis.y*.5).distance_to(end)<.0001,"strafe tracer retains ballistic endpoint")
	var consumables=load("res://scripts/field_consumables.gd")
	check(consumables.within_consumption_volume(Vector3(0,-.25,-.48),Transform3D.IDENTITY,"soda"),"modest forward drinking reach")
	check(not consumables.within_consumption_volume(Vector3(.4,-.4,-.7),Transform3D.IDENTITY,"soda"),"gigantic089corner no longer consumes")
	var paddles:Node3D=game.revive_paddles;paddles.equip()
	for speed in [0.0,.7]:
		paddles._clear_charge();var elapsed:=0.0
		while not paddles.charge_ready and elapsed<11:
			var shift:float=0 if speed==0 else (.0035 if roundi(elapsed/.01)%2==0 else -.0035)
			paddles.step_contacts(.01,Vector3(shift,31,-.3),Vector3(1.5+shift,31,-.3),true,Vector3.RIGHT,Vector3.LEFT);elapsed+=.01
		check(absf(elapsed-(10 if speed==0 else 5.5))<.05,"paddles charge across1.5m at proper rate "+str(speed))
	paddles._clear_charge();paddles.step_contacts(.05,Vector3(0,31,0),Vector3(1.5,31,0),true,Vector3.RIGHT,Vector3.RIGHT);paddles.step_contacts(.05,Vector3(.025,31,0),Vector3(1.525,31,0),true,Vector3.RIGHT,Vector3.RIGHT)
	check(paddles.charge==0 and not paddles._facing,"paddles must face one another")
	var geometry:Node3D=paddles._paddles[0].get_node("HospitalPaddle090")
	check((-geometry.basis.y.normalized()).dot(Vector3.FORWARD)>.999,"electrode rotates toward fingertips")
	check(geometry.scale.is_equal_approx(Vector3.ONE*1.3),"paddles30percent larger")
	check(geometry.find_children("HandleSupport*","",false,false).size()==2,"open hospital handle has two supports")
	paddles.stow()
	for kind in ["revive_shepard","katana_shield","sword_swing"]:
		var wav:AudioStreamWAV=AshAudioBank.sample(kind);check(wav.mix_rate==48000 and wav.format==AudioStreamWAV.FORMAT_16_BITS,"new lossless sound "+kind)
		if kind!="sword_swing":check(wav.loop_mode==AudioStreamWAV.LOOP_FORWARD,"continuous sound loop "+kind)
	check(game.field_builder.minimum_vertical_placement_distance==.4572,"retracted build-distance change stays18in")
	var terrain:=StaticBody3D.new();terrain.collision_layer=1;var terrain_shape:=CollisionShape3D.new();terrain_shape.shape=BoxShape3D.new();terrain_shape.shape.size=Vector3(10,.4,10);terrain.add_child(terrain_shape);game.add_child(terrain);terrain.global_position=Vector3(0,49.8,0);terrain.rotation.z=.2
	var builder=load("res://scripts/field_builder.gd").new();game.add_child(builder);builder.setup(null,null,null);builder.set_physics_process(false)
	var candidate:={"kind":"floor","axis":1,"at":Transform3D(Basis.IDENTITY,Vector3(0,50,0)),"base_y":50.0,"distance":2.0}
	var state:={"origin":Vector3(0,51,2),"direction":Vector3.FORWARD,"head":Vector3(1000,1000,1000)}
	var exclusions:Array[RID]=[]
	await physics_frame
	check(builder._evaluate_grid_candidate(candidate,state,exclusions),"floor can intersect slope while an edge remains exposed")
	terrain.rotation.z=0;await physics_frame
	check(not builder._evaluate_grid_candidate(candidate,state,exclusions) and builder.invalid_reason=="buried_floor","floor flush with flat ground is rejected")
	terrain.queue_free();builder.queue_free()
	for tracker in trackers.values():XRServer.remove_tracker(tracker)
	game.queue_free();await process_frame;await process_frame
	print("INTERACTIONS_097 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false")
	quit(0 if failures==0 else 1)
