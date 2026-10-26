extends SceneTree
class Katana extends "res://scripts/melee_sword.gd":
	func _vr_active()->bool:return true
class Excalibur extends "res://scripts/speed_sword.gd":
	func _vr_active()->bool:return true
class Cyberblade extends "res://scripts/energy_sword.gd":
	func _vr_active()->bool:return true
class Menu extends Node:
	var player_damage_multiplier:=1.0
	var vignette_enabled:=false
class DamageGame extends "res://scripts/main.gd":
	func _impact(_point:Vector3,_normal:Vector3)->void:pass
	func _play_sound(_kind:String)->void:pass
	func _activate_encounter(_announce:bool=true)->void:encounter_active=true
class Victim extends StaticBody3D:
	var health:=100.0
	var shield:=100.0
	var hits:=0
	func take_damage(amount:float)->void:shield-=amount
	func take_melee_damage(amount:float)->void:health-=amount;hits+=1
var checks:=0
var failures:=0
var actor
var rack
var trackers:Dictionary={}
var impacts:Array[Dictionary]=[]
var hurt:=0.0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func neutral(gun)->void:
	actor._grabs.clear();actor.left_hand_reserved=false;actor.input_enabled=true;actor.head_obstructed=false
	for t in trackers.values():t.set_input("grip",0.0);t.set_input("trigger",0.0);t.set_input("primary",Vector2.ZERO)
	actor.update_hand_input_rearm(.2);gun.cooldown=0;gun._process(0)
func pose(gun,at:Vector3)->void:
	gun.right_hand.global_transform=Transform3D(Basis(Vector3.RIGHT,PI*.5),at);gun._process(0)
func support(gun,value:float)->void:
	gun.left_hand.global_position=gun.model.to_global(gun.SUPPORT_POINT);trackers[gun.left_hand].set_input("grip",value);gun._process(0)
func victim(at:Vector3)->Victim:
	var result:=Victim.new();root.add_child(result);result.position=at;result.collision_layer=4
	var shape:=CollisionShape3D.new();var ball:=SphereShape3D.new();ball.radius=.20;shape.shape=ball;result.add_child(shape);return result
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.xr_camera.position.y=1.65;actor.set_process(false);actor.set_physics_process(false)
	for hand in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="sword049_"+str(hand.get_instance_id());XRServer.add_tracker(t);hand.tracker=t.name;hand.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);trackers[hand]=t
	await process_frame
	rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	check(rack.weapons.size()==29 and rack.ACTIVE_WEAPON_INDICES.size()==27 and not rack.is_catalog_active(4),"three swords appended alongside050catalog, without restoring retired pump or shifting indices")
	for i in rack.ACTIVE_WEAPON_INDICES:check(ResourceLoader.exists("res://assets/ui/wheel_weapon_%d.svg"%i),"active wheel icon exists type%d"%i)
	var game:=DamageGame.new();var menu:=Menu.new();game.field_menu=menu
	rack.melee_contact.connect(game._on_melee_contact)
	for item in [[14,Katana],[15,Excalibur],[16,Cyberblade]]:
		var old=rack.weapons[item[0]];old.shutdown();old.free()
		var sword=item[1].new();rack.add_child(sword);sword.setup(actor,false);sword.set_process(false);sword.set_physics_process(false);rack.weapons[item[0]]=sword;rack._connect_weapon_events(sword)
	for side in ["right","left"]:
		actor.dominant_hand=side;actor.refresh_hands() if actor.has_method("refresh_hands") else null
		for index in [14,15,16]:
			rack.selected=index;rack.is_holstered=false;rack._apply_selection();var sword=rack.weapons[index];neutral(sword);pose(sword,Vector3(-.4,1.0,-.3))
			var expected:=1.15 if index==14 else 1.25
			check(is_equal_approx(sword.get_movement_multiplier(),expected),side+" equipped speed%d historical multiplier"%index)
			check(is_equal_approx(rack.get_ground_speed_gain(1.0),expected) and is_equal_approx(rack.get_ground_speed_gain(1.5),1.5),side+" original nonstacking sprint policy%d"%index)
			check(is_equal_approx(actor.get_effective_glide_speed(),actor.effective_walk_speed()*12.0/6.5),side+" measured glide/walk scaling preserved%d"%index)
			var target:=victim(Vector3(0,1.6,-.3));await physics_frame;await physics_frame
			pose(sword,Vector3(-.4,1.0,-.3));sword.sample_motion(.04)
			check(target.hits==0,side+" equip/first pose is never a phantom sword strike%d"%index)
			var bank:Dictionary=rack.reserves.duplicate();var raw:Transform3D=sword.right_hand.global_transform
			var from_base:Vector3=sword.blade_base.global_position;var from_tip:Vector3=sword.blade_tip.global_position
			pose(sword,Vector3(.4,1.0,-.3))
			sword.sample_motion(.04)
			check(target.hits==1 and target.health>=25 and target.health<=75 and target.shield==100,side+" real swept blade hits HP once and bypasses personal shield%d"%index)
			check(rack.reserves==bank and sword.get_loaded_rounds()==0,side+" melee consumes or creates no ammunition%d"%index)
			for step in 5:sword.sample_motion(.04)
			check(target.hits==1,side+" resting/contact blade cannot repeatedly drain HP%d"%index)
			var hidden:=victim(Vector3(0,1.6,-.3));var wall:=StaticBody3D.new();root.add_child(wall);wall.position=Vector3(0,1.4,-.12)
			var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(2,2,.06);wall_shape.shape=wall_box;wall.add_child(wall_shape)
			await physics_frame;await physics_frame
			sword._history_valid=false;pose(sword,Vector3(-.4,1.0,-.3));sword.sample_motion(.04);pose(sword,Vector3(.4,1.0,-.3));sword.sample_motion(.04)
			check(hidden.hits==0,side+" blade behind solid eye/hilt barrier cannot damage hidden target%d"%index)
			wall.free();hidden.free()
			var original:int=target.hits;sword._history_valid=false;pose(sword,Vector3(-.4,1.0,-.3));sword.sample_motion(.04)
			actor.position.x=10;pose(sword,Vector3(9.6,1.0,-.3));sword.sample_motion(.04)
			check(target.hits==original,side+" artificial body translation is not blade swing%d"%index)
			actor.position=Vector3.ZERO;sword._history_valid=false
			pose(sword,Vector3(-.4,1.0,-.3));sword.sample_motion(.04);pose(sword,Vector3(2,1.0,-.3));sword.sample_motion(.04)
			check(target.hits==original,side+" tracking jump cannot sweep damage through targets%d"%index)
			target.free();neutral(sword);pose(sword,Vector3(0,1.2,-.3));support(sword,0)
			var climb_wall:=StaticBody3D.new();root.add_child(climb_wall);climb_wall.position=Vector3(0,1.1,-.35)
			var climb_col:=CollisionShape3D.new();var climb_box:=BoxShape3D.new();climb_box.size=Vector3(.8,1.8,.12);climb_col.shape=climb_box;climb_wall.add_child(climb_col)
			await physics_frame;await physics_frame;pose(sword,Vector3(0,1.2,-.3));sword.left_hand.global_position=Vector3(.2,1.1,-.275)
			actor._update_grab(sword.right_hand,true);actor._update_grab(sword.left_hand,true)
			check(not actor._grabs.has(sword.right_hand) and actor._grabs.has(sword.left_hand),side+" drawn sword hand cannot climb while its free offhand can%d"%index)
			var anchor:Vector3=actor._grabs.get(sword.left_hand,Vector3.INF);support(sword,1)
			check(not sword.shield_active and actor._grabs.get(sword.left_hand)==anchor,side+" Katana support request cannot steal an existing wall anchor%d"%index)
			check(rack.select_weapon(0) and actor._grabs.get(sword.left_hand)==anchor and rack.select_inventory_weapon(index),side+" switching sword/gun preserves offhand wall anchor%d"%index)
			actor._update_grab(sword.left_hand,false,false);climb_wall.free();neutral(sword);pose(sword,Vector3(0,1.2,-.3));support(sword,0);support(sword,1)
			if index!=14:check(not sword.shield_active and sword.supported,side+" speed sword supports both hands without a shield%d"%index);continue
			check(sword.shield_active and sword.supported and sword.shield_visual.visible,side+" actual tracked offhand grip at Katana hilt activates two-hand shield")
			check(is_equal_approx(rack.get_ground_speed_gain(1.5),.90),side+" shield slowdown0.90 overrides sprint")
			check(rack.is_hand_holding_weapon(sword.right_hand) and rack.is_hand_holding_weapon(sword.left_hand),side+" shield owns both drawn hands without changing raw trackers")
			check(actor.get_hand_art_contact(sword.right_hand).profile=="sword" and actor.get_hand_art_contact(sword.right_hand).center==sword.hand_grip_center,side+" original sword hilt uses its own authored fist contact")
			var plane:Transform3D=sword.shield_visual.global_transform
			check(not actor.intercept_bullet(plane*Vector3(0,0,-2),plane*Vector3(0,0,2)).is_empty(),side+" real player/rack route intercepts front bullet")
			check(actor.intercept_bullet(plane*Vector3(0,0,2),plane*Vector3(0,0,-2)).is_empty(),side+" rear bullet bypasses active shield")
			check(actor.intercept_bullet(plane*Vector3(.81,0,-2),plane*Vector3(.81,0,2)).is_empty(),side+" outside shield perimeter bullet passes")
			var enemy=load("res://scripts/enemy.gd").new();root.add_child(enemy);enemy.setup(actor,0);enemy.set_physics_process(false);enemy.position=Vector3(0,0,-5);enemy.locked_aim=actor.get_view_camera().global_position;enemy.hit_player.connect(func(amount:float):hurt+=amount)
			enemy.shot_visual.connect(func(origin:Vector3,endpoint:Vector3):impacts.append({"origin":origin,"endpoint":endpoint}))
			await physics_frame;pose(sword,Vector3(0,1.2,-.3));support(sword,1);hurt=0;enemy._fire(enemy.locked_aim)
			check(hurt==0 and not impacts.is_empty() and absf(sword.shield_visual.to_local(impacts.back().endpoint).z)<.001,side+" production enemy discharge is stopped at shield and tracer terminates there")
			enemy._impact_point=actor.global_position;enemy._resolve_warden_impact(actor.get_view_camera().global_position)
			check(hurt>0 and sword.shield_active,side+" production area blast bypasses active bullet shield")
			hurt=0
			support(sword,0);enemy._fire(enemy.locked_aim)
			check(hurt>0 and not sword.shield_active,side+" grip release immediately restores ordinary bullet damage")
			enemy.queue_free();await process_frame;pose(sword,Vector3(0,1.2,-.3));support(sword,0);support(sword,1)
			actor.input_enabled=false;check(actor.intercept_bullet(plane*Vector3(0,0,-2),plane*Vector3(0,0,2)).is_empty(),side+" paused/input-disabled shield never grants stale invulnerability")
			actor.input_enabled=true;support(sword,0);support(sword,1);rack.set_holstered(true)
			check(not sword.shield_active and is_equal_approx(rack.get_ground_speed_gain(1.0),1.0),side+" holstering removes shield and speed bonus")
	game.health=100;game.shield=100;game.take_melee_damage(50)
	check(game.health==50 and game.shield==100,"actual Main melee-damage route bypasses personal shield")
	game.health=100;game.shield=100;game._damage_player(50)
	check(game.health==100 and game.shield==50,"ordinary/area damage keeps existing shield-first layers")
	check(is_equal_approx(Katana.swing_damage(0,0),25) and is_equal_approx(Katana.swing_damage(4,.5),75) and Katana.swing_damage(1,.1)<Katana.swing_damage(3,.4),"historical25-75 damage range scales with original swing strength/travel tuning")
	for t in trackers.values():XRServer.remove_tracker(t)
	game.free();menu.free();rack.shutdown();rack.free();actor.free();await create_timer(.25).timeout
	print("SWORDS_059_CARRY checks=",checks," failures=",failures," synthetic=true physical_button_parity=false headset_tested=false")
	quit(failures)
