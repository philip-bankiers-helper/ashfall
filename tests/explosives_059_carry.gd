extends SceneTree
class Grenade extends "res://scripts/explosive_weapon.gd":
	func _vr_active()->bool:return true
class MainHost extends "res://scripts/main.gd":
	func _ready()->void:pass
	func _process(_delta:float)->void:pass
	func _play_sound(_key,_unused=null)->void:pass
	func _impact(_point,_normal)->void:pass
class Menu extends Node:
	var player_damage_multiplier:=1.0
	var vignette_enabled:=false
class Target extends StaticBody3D:
	var damage_total:=0.0
	func take_damage(amount:float)->void:damage_total+=amount
var checks:=0
var failures:=0
var actor
var trackers:Dictionary={}
var events:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func box(size:Vector3,point:Vector3)->StaticBody3D:
	var b:=StaticBody3D.new();var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;c.shape=s;b.add_child(c);b.position=point;root.add_child(b);return b
func run()->void:
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.xr_enabled=true;actor.set_process(false);actor.set_physics_process(false)
	for h in [actor.left_hand,actor.right_hand]:
		var t:=XRControllerTracker.new();t.type=XRServer.TRACKER_CONTROLLER;t.name="explosive050_"+str(h.get_instance_id());XRServer.add_tracker(t);h.tracker=t.name;h.pose="grip";t.set_pose("grip",Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,XRPose.XR_TRACKING_CONFIDENCE_HIGH);t.set_input("trigger",0.0);t.set_input("grip",0.0);trackers[h]=t
	await process_frame;actor.update_hand_input_rearm(.2)
	for side in ["right","left"]:
		actor.dominant_hand=side
		var grenade:=Grenade.new();root.add_child(grenade);grenade.setup(actor,false);grenade.set_process(false);grenade.set_physics_process(false)
		grenade.explosive_launch.connect(func(spec:Dictionary):events.append(spec))
		var before:=events.size();trackers[grenade.right_hand].set_input("trigger",0.0);grenade._process(.016)
		trackers[grenade.right_hand].set_input("trigger",1.0);grenade._process(.016)
		check(not grenade.armed and grenade.ammo==1 and events.size()==before+1,side+" C13 trigger press throws once")
		trackers[grenade.right_hand].set_input("trigger",0.0);grenade._process(.016)
		check(grenade.ammo==1 and events.size()==before+1 and events[-1].kind=="frag",side+" C13 release does not throw an additional frag")
		grenade.throw_input(true,false,Vector3.ZERO);grenade.throw_input(false,false,Vector3.FORWARD*6)
		check(grenade.ammo==1 and events.size()==before+1,side+" C13 invalid tracking rejects press without spending")
		grenade.shutdown();grenade.free();actor.left_hand_reserved=false
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	var rocket=rack.weapons[27];events.clear();rocket.explosive_launch.connect(func(spec:Dictionary):events.append(spec))
	for i in 3:
		rocket.cooldown=0;rocket._requires_trigger_release=false;rocket.fire()
		check(events.size()==i+1 and rocket.ammo==0,"C13 SMAW fires one chamber, shot"+str(i+1))
		if i<2:
			rocket.grab_magazine();rocket.insert_magazine()
			check(rocket.ammo==1 and rocket.reload_state=="ready" and rack.reserves.rockets==1-i,"C13 finite single-rocket reload between shots")
	rocket.cooldown=0;rocket._requires_trigger_release=false;rocket.fire()
	check(events.size()==3 and rocket.ammo==0 and rack.reserves.rockets==0,"C13 disposable SMAW limited to3TOTAL, never3shot magazine")
	var m60=rack.weapons[8]
	for i in 11:
		m60.cooldown=0;m60.fire()
		if i==0:check(is_equal_approx(m60.fire_interval,1.0/3.6),"C12 M60 starts50% of measured7.2rps")
	check(is_equal_approx(m60.fire_interval,1.0/7.2) and m60.spool_shots==11,"C12 M60 reaches measured7.2rps after10shots, startup ramp matches counter trace")
	# Production main damage dispatch: radial falloff, self damage, build damage.
	var host:=MainHost.new();root.add_child(host);host.player=actor;host.field_menu=Menu.new();host.add_child(host.field_menu);host.xr_enabled=false;host.shield=100;host.health=100
	var target:=Target.new();root.add_child(target);target.add_to_group("enemies");target.position=Vector3(2,-.7,0)
	actor.xr_enabled=false;actor.position=Vector3(0,0,0);actor.desktop_camera.position=Vector3(0,1.65,0)
	host.apply_explosive_damage(Vector3(0,0,0),10,150,true)
	check(is_equal_approx(target.damage_total,120),"C13 production frag150 maximum with explicitly original linear10m falloff")
	check(host.shield==0 and host.health<100 and host.health>0,"C13 production blast can damage thrower through normal shield/HP layers")
	host.shield=100;host.health=100;target.damage_total=0
	var zone=load("res://scripts/explosive_projectile.gd").new();host.add_child(zone);zone.setup(host,{"kind":"zone","origin":Vector3.ZERO,"velocity":Vector3.ZERO});zone.set_physics_process(false);zone.stuck=true
	zone.advance_zone(.49);check(target.damage_total==0,"C13 chosen first zone tick after0.5seconds is explicit original timing")
	zone.advance_zone(.01);check(target.damage_total==5 and zone.zone_ticks==1,"C13 zone5damage tick after0.5s =10DPS")
	zone.advance_zone(1.5);check(target.damage_total==20 and zone.zone_ticks==4,"C13 deterministic zone tick partitions")
	check(is_equal_approx(zone.zone_visual.scale.x,12),"C13 chosen linear radius15->0 over10s, interpolation labelled original")
	zone.set_paused(true);check(zone.freeze,"C13 pause freezes projectile physics")
	zone.set_paused(false);zone.advance_zone(8.0);check(zone.finished and zone.zone_ticks==20,"C13 zone lifetime10seconds,20tick boundaries")
	await process_frame
	# Contact uses real RigidBody collision, including walls/floor/ceiling.
	for axis in [Vector3.FORWARD,Vector3.DOWN,Vector3.UP]:
		var surface:=box(Vector3(4,.15,4) if axis.y!=0 else Vector3(4,4,.15),Vector3(20,2,0)+axis)
		var projectile=load("res://scripts/explosive_projectile.gd").new();host.add_child(projectile);projectile.setup(host,{"kind":"zone","origin":Vector3(20,2,0),"velocity":axis*7})
		for i in 24:await physics_frame
		check(projectile.stuck and projectile.freeze and projectile.collision_layer==0,"C13 actual zone sticks without solid trap, surface"+str(axis))
		projectile.queue_free();surface.queue_free();await physics_frame;await physics_frame
	var frag=load("res://scripts/explosive_projectile.gd").new();host.add_child(frag);frag.setup(host,{"kind":"frag","origin":Vector3(40,1,0),"velocity":Vector3.ZERO});frag.set_physics_process(false);frag._physics_process(2.49)
	check(not frag.finished,"C13 original configurable frag fuse not early")
	frag._physics_process(.02);check(frag.finished,"C13 configured frag fuse detonates")
	target.free();host.field_menu.free();host.free();rack.shutdown();rack.free()
	for t in trackers.values():XRServer.remove_tracker(t)
	actor.free();await create_timer(.2).timeout
	print("EXPLOSIVES_059_CARRY checks=",checks," failures=",failures," actual_physics=true unspecified_timings_original=true headset_tested=false")
	quit(failures)
