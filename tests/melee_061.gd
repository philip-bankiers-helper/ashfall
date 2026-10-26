extends SceneTree
class Sword extends "res://scripts/melee_sword.gd":
	func _usable()->bool:return true
	func _pose_weapon()->void:pass
class Knife extends "res://scripts/short_knife.gd":
	func _usable()->bool:return true
	func _pose_weapon()->void:pass
class Victim extends StaticBody3D:
	var health:=100.0
	var hits:=0
	func take_melee_damage(amount:float)->void:health-=amount;hits+=1
var checks:=0
var failures:=0
var actor
func _initialize()->void:Engine.max_fps=90;call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func victim(at:Vector3,radius:float=.015)->Victim:
	var body:=Victim.new();body.collision_layer=4;root.add_child(body);body.position=at
	var shape:=CollisionShape3D.new();var ball:=SphereShape3D.new();ball.radius=radius;shape.shape=ball;body.add_child(shape);return body
func prepare(blade)->void:
	root.add_child(blade);blade.setup(actor,false);blade.set_process(false);blade.set_physics_process(false)
	blade.melee_contact.connect(func(target:Node3D,_at:Vector3,amount:float,_dir:Vector3):target.take_melee_damage(amount))
func wait_hit_limit(blade,target:Node3D)->void:
	while Time.get_ticks_msec()<=int(blade._target_next_ms.get(target.get_instance_id(),0)):await process_frame
func run()->void:
	load("res://scripts/audio_bank.gd").ensure_buses()
	actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var assets=load("res://scripts/blade_assets.gd")
	for kind in ["katana","excalibur","cyberblade","knife"]:
		var model:=Node3D.new();root.add_child(model);var built:Dictionary=assets.build(model,kind)
		var pommel:MeshInstance3D=model.get_node("Pommel")
		var bottom:=pommel.position-Vector3.UP*(pommel.mesh as BoxMesh).size.y*.5
		check(is_equal_approx(bottom.distance_to(built.tip.position),assets.KNIFE_LENGTH if kind=="knife" else 2.0),kind+" exact authored pommel-to-tip span")
		var hilt:MeshInstance3D=model.get_node("GripCore")
		check(hilt.position.y<assets.GRIP.y if kind!="knife" else hilt.position==assets.GRIP,kind+" fist is seated toward guard with usable hilt behind")
		if kind!="knife":check(is_equal_approx((hilt.mesh as BoxMesh).size.y,.285),kind+" handle length28.5cm")
		model.free()
	var sword:=Sword.new();prepare(sword);sword.position=Vector3(0,1,-.3)
	var from_base:Vector3=sword.blade_base.global_position+Vector3.LEFT*.4
	var from_tip:Vector3=sword.blade_tip.global_position+Vector3.LEFT*.4
	var to_base:=from_base+Vector3.RIGHT*.8;var to_tip:=from_tip+Vector3.RIGHT*.8
	var thin:Array[Victim]=[]
	for i in 12:thin.append(victim((from_base+Vector3.RIGHT*.4).lerp(from_tip+Vector3.RIGHT*.4,(i+.5)/12.0),.010))
	await physics_frame;await physics_frame
	var contacts:Array=sword._find_contacts(from_base,from_tip,to_base,to_tip)
	check(contacts.size()==thin.size(),"continuous swept volume hits all12 thin targets between old ray sample lines")
	var unique:Dictionary={}
	for hit in contacts:unique[hit.target.get_instance_id()]=true;check(hit.position.is_finite(),"physical contact position is finite")
	check(unique.size()==thin.size(),"one contact per target, no duplicates")
	for target in thin:target.free()
	var pivot:=Vector3(0,1,-.3);var before:=Vector3.UP*1.6;var after:=before.rotated(Vector3.FORWARD,.60)
	var arc_target:=victim(pivot+before.rotated(Vector3.FORWARD,.30),.010)
	await physics_frame;await physics_frame
	check(sword._find_contacts(pivot,pivot+before,pivot,pivot+after).size()==1,"rotating tip arc outside endpoint chord is covered")
	arc_target.free()
	var target:=victim(Vector3(0,1.7,-.3),.10);await physics_frame;await physics_frame
	sword.position=Vector3(-.4,1,-.3);sword.sample_motion(.04)
	check(target.hits==0,"equip/first pose never strikes")
	sword.position.x=.4;sword.sample_motion(.04)
	check(target.hits==1,"actual tracked-motion route applies one sword hit")
	check(sword.swing_audio_events==1,"deliberate swing emits one original whoosh")
	for i in 8:sword.sample_motion(.04)
	check(target.hits==1 and sword.swing_audio_events==1,"resting blade emits no repeated damage/audio")
	await wait_hit_limit(sword,target)
	sword.position.x=-.4;sword.sample_motion(.04)
	check(target.hits==2,"next deliberate stroke hits after resting contact")
	await wait_hit_limit(sword,target)
	sword.position.x=.4;sword.sample_motion(.04)
	check(target.hits==3,"opposite stroke is a fresh hit without any sampled rest interval")
	sword._history_valid=false;sword.position.x=-.4;sword.sample_motion(.04)
	var events:=sword.swing_audio_events
	actor.position.x=10;sword.position.x=9.6;sword.sample_motion(.04)
	check(target.hits==3 and sword.swing_audio_events==events,"body translation causes neither strike nor swing audio")
	actor.position.x=0;sword._history_valid=false;sword.position.x=-.4;sword.sample_motion(.04);sword.position.x=2;sword.sample_motion(.04)
	check(target.hits==3,"tracking jump cannot sweep damage")
	sword._history_valid=false;sword._reset_stroke();sword.position.x=-.4;sword.sample_motion(.04);events=sword.swing_audio_events
	for i in 40:sword.position.x+=.001;sword.sample_motion(1.0/90.0)
	check(sword.swing_audio_events==events,"slow walking arm bob stays silent")
	var wall:=StaticBody3D.new();root.add_child(wall);wall.position=Vector3(0,1.7,-.12)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(3,3,.05);collision.shape=shape;wall.add_child(collision)
	await physics_frame;await physics_frame
	check(sword._find_contacts(from_base,from_tip,to_base,to_tip).is_empty(),"solid wall between eye and hilt blocks all swept contacts")
	wall.free();target.free();sword.shutdown();sword.free()
	var knife:=Knife.new();prepare(knife);knife.position=Vector3(-.15,1,-.3)
	var knife_target:=victim(Vector3(0,1.1,-.3),.06);await physics_frame;await physics_frame
	check(knife._damage_for_swing(.3,.01)==35 and knife._damage_for_swing(8,1)==35,"primary-source knife35damage independent of speed/distance")
	knife.sample_motion(.04)
	for i in 3:
		knife.position.x=.15 if i%2==0 else -.15;knife.sample_motion(.04)
		check(knife_target.hits==i+1 and is_equal_approx(knife_target.health,100-(i+1)*35),"knife distinct contact%d deals35HP"%(i+1))
		await wait_hit_limit(knife,knife_target)
	check(knife_target.health<=0,"three separate knife hits defeat100HP")
	knife._update_guard();check(not knife.supported and not knife.shield_active and not knife.grip_cue.visible,"knife has no two-hand shield/support cue")
	knife_target.free();knife.shutdown();knife.free();actor.free();await process_frame
	print("MELEE_061 checks=",checks," failures=",failures," cpu_physics=true headset_tested=false rendered=false")
	quit(failures)
