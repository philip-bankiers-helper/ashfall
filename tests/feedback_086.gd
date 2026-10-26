extends SceneTree
class FilterWeapon extends "res://scripts/weapon.gd":
	func _vr_active()->bool:return true
	func _input_allowed()->bool:return true
	func _hand_input_ready(_hand:XRController3D)->bool:return true
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	var inv=load("res://scripts/weapon_inventory.gd").new();root.add_child(inv);inv.player=actor;inv.rack=rack;inv.set_process(false)
	var sizes:={1:1.6,3:.92,9:1.0,17:.72,20:.72,24:1.037875,27:1.6,5:1.0,18:1.0,19:.55,21:.9,23:.8,13:1.32,8:1.0}
	for i in sizes:
		var gun:Node3D=rack.weapons[i];gun.set_process(false);gun.set_physics_process(false)
		check(gun.model.scale.is_equal_approx(Vector3.ONE*float(sizes[i])),"actual held size "+rack.weapon_names[i])
		var ground:Node3D=inv._create_prop(i);check(ground.get_child(0).scale.is_equal_approx(gun.model.scale),"actual ground size "+rack.weapon_names[i]);ground.free()
	for i in 2:
		check(rack.weapons[11].guns[i].model.scale.is_equal_approx(Vector3.ONE*.64),"Uzis -20%% hand%d"%i)
		check(is_equal_approx(rack.weapons[12].guns[i].fire_interval,.32/1.2),"Matador rate +20%% hand%d"%i)
	var probe:=FilterWeapon.new();root.add_child(probe);probe.setup(actor,false);probe.set_process(false);probe._apply_aim_filter(.01)
	var raw:=Basis(Vector3.UP,.5);probe.global_basis=raw;probe._apply_aim_filter(.01)
	check(probe.global_basis.is_equal_approx(raw),"filter never rotates tracked weapon")
	var presented:Transform3D=probe.get_visual_reticle_pose_071(probe.get_shot_transform())
	check(not presented.basis.is_equal_approx(probe.get_shot_transform().basis),"crosshair aim is damped independently")
	probe.publish_displayed_aim(presented);check(probe.get_firing_pose().is_equal_approx(presented),"firing retains exact displayed damped ray")
	# Reproduce wrist-roll lag through the actual filter, not just a static
	# presentation helper. The world-up pulse must be applied AFTER filtering.
	for id in ["fal","px4","1911","dt11"]:
		probe.set_meta("reference_id",id)
		for dominant in ["left","right"]:
			actor.dominant_hand=dominant
			for fps in [30,72,120]:
				probe.global_basis=Basis.IDENTITY;probe._aim_filter_ready=false;probe._apply_aim_filter(1.0/fps)
				probe.global_basis=Basis.from_euler(Vector3(.2,.4,PI*.5 if dominant=="right" else -PI*.5))
				probe._apply_aim_filter(1.0/fps)
				var raw_weapon:Basis=probe.global_basis
				probe._reticle_bounce_pitch_071=0.0
				var neutral:Transform3D=probe.get_visual_reticle_pose_071(probe.get_shot_transform())
				probe._reticle_bounce_pitch_071=.1
				var risen:Transform3D=probe.get_visual_reticle_pose_071(probe.get_shot_transform())
				var forward:Vector3=-neutral.basis.z.normalized();var up:Vector3=-risen.basis.z.normalized()
				var side:Vector3=Vector3(forward.x,0,forward.z).normalized().cross(Vector3.UP)
				check(up.y>forward.y and absf(up.dot(side))<.00001,id+" filtered roll keeps pulse world-upright "+dominant+str(fps))
				check(probe.global_basis.is_equal_approx(raw_weapon) and risen.origin.is_equal_approx(neutral.origin),id+" filtered pulse leaves weapon and muzzle origin unchanged")
				probe.publish_displayed_aim(risen)
				check(probe.get_firing_pose().is_equal_approx(risen),id+" filtered rolled pulse and shot share displayed aim")
	actor.dominant_hand="right"
	# Fixed guard probes from the independently measured rigid alignment.
	var guard_expected:Array=[[-0.021338593648132075,0.08796221560606751,-0.0007334512186224044],[-0.004093493172643929,0.08510904521788128,0.0632087372991787],[-0.001483180029243207,0.0856789169576749,-0.014023812986292516],[-0.0360915364045324,0.08505673584869788,0.02494030727396876],[0.03558179316618446,0.08532581345581189,0.02766431196940182],[-0.004776166141026618,0.07950288708481382,0.02798857236994832]]
	var sword_mesh:Mesh=rack.weapons[14].model.get_node("DownloadedBlade077").mesh
	for coordinates in guard_expected:
		var expected:=Vector3(coordinates[0],coordinates[1],coordinates[2]);var distance:=INF
		for surface in sword_mesh.get_surface_count():
			for point in sword_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:distance=minf(distance,point.distance_to(expected))
		check(distance<.00001,"actual Katana guard matches upright measured geometry "+str(expected))
	var m10:Node3D=rack.weapons[9]
	for held in [false,true]:
		m10.reset_weapon();m10.supported=held;m10.ammo=6;m10.reload_state="ready"
		for shot in 6:
			m10._displayed_pose_valid=false
			var centre:Vector3=-m10.get_visual_reticle_pose_071(m10.get_shot_transform()).basis.z
			var expected_y:=0.0 if shot==0 else sin(deg_to_rad(2.0 if held else 3.5))
			check(absf(centre.y-expected_y)<.00001,"M10 actual next shot plateau %s/%d"%[held,shot])
			m10.cooldown=0;m10.fire();m10._recover_recoil(m10.fire_interval);m10._apply_recoil_visual()
	var p90:Node3D=rack.weapons[10]
	var delta:Vector3=(p90.get_top_offer()-(p90.get_top_seat()+Vector3.BACK*.17))*p90.visual_model_scale()
	check(delta.is_equal_approx(Vector3(0,.0508,.0508)),"P90 offered offset exact physical two inches each")
	p90.reload_state="needs_mag";p90._process(.01);check(p90.insertion_arrow.visible,"P90 magazine arrow visible")
	p90.reload_state="needs_rack";p90._process(.01);check(p90.charging_arrow.visible,"P90 handle arrow visible")
	check(is_equal_approx(rack.weapons[13].optic.global_basis.x.length(),1.1),"SPR scope half085 physical size")
	var spr:Node3D=rack.weapons[13];var mount:MeshInstance3D=spr.model.get_node("RectangularSPRScopeMount084")
	check(absf(spr.optic.position.y+.1095*spr.optic.scale.y-mount.position.y-mount.mesh.get_aabb().end.y)<.001,"SPR lower frame physically meets mount within1mm")
	check(absf(spr.optic.position.z+spr.optic.lens.position.z*spr.optic.scale.z-mount.position.z)<.001,"SPR compact scope remains centred over mount")
	var lightning=load("res://scripts/build_lightning_085.gd").new();root.add_child(lightning);lightning.update_bolt(Vector3.ZERO,Vector3(2,1,-4),true)
	check(lightning.strands.size()==20,"twenty build strands")
	for path in lightning.strands:check(path[0]==Vector3.ZERO and path[-1]==Vector3(2,1,-4),"exact shared lightning endpoints")
	lightning.update_bolt(Vector3.ZERO,Vector3.ONE,false);check(lightning.strands.is_empty() and not lightning.visible,"all strands clear on cancellation")
	var builder=load("res://scripts/field_builder.gd").new();root.add_child(builder)
	check(is_equal_approx(builder._geometry("wall").shape.size.z,.08) and is_equal_approx(builder._geometry("floor").mesh.size.y,.08),"build physics and mesh half thickness")
	var consume=load("res://scripts/field_consumables.gd")
	for point in [Vector3(0,0,-.7),Vector3(.35,.2,-.35),Vector3(-.35,-.2,-.35)]:check(consume.within_consumption_volume(point,Transform3D.IDENTITY,"soda"),"soda reaches face front "+str(point))
	check(not consume.within_consumption_volume(Vector3(0,0,-1),Transform3D.IDENTITY,"soda"),"distant soda excluded")
	var marks=load("res://scripts/team_marks.gd").new();root.add_child(marks);marks.set_physics_process(false)
	marks.consume_state({"pressed":false,"eligible":true},.01)
	var hit:={"position":Vector3(0,0,-5),"normal":Vector3.UP}
	marks.consume_state({"pressed":true,"eligible":true,"hit":hit},.11);marks.selected_color=1
	marks.consume_state({"pressed":false,"eligible":true},.01)
	marks.consume_state({"pressed":true,"eligible":true,"hit":hit},.03);marks.consume_state({"pressed":false,"eligible":true},.01)
	check(marks.records.size()==2 and marks.records[1].color=="red","chosen ping color persists into quick taps")
	check(marks._wheel.get_script()==preload("res://scripts/ping_wheel_086.gd"),"actual ping wheel shares weapon wheel subclass")
	check(marks._visuals[0].find_child("BasePingIcon",false,false)!=null,"base uses action graphic")
	check(marks._visuals[0].find_children("*","Label3D",true,false).is_empty(),"no mark text")
	var dots:SphereMesh=marks._visuals[0].get_node("DottedSkyColumn").multimesh.mesh
	check(is_equal_approx(dots.radius*2,.6096*1.2) and dots.height>.3,"wider three dimensional oval dots")
	var banana=load("res://scripts/field_item_models.gd").consumable("banana",{})
	root.add_child(banana);load("res://scripts/banana_peel_086.gd").update(banana,2,false,Vector3.ZERO,null)
	check(banana.get_node("FourPeelStrips").get_child_count()==4,"four independent peel strips")
	check(not banana.get_node("Cap").visible,"old shrinking shell hidden")
	check(banana.get_node("FourPeelStrips").get_child(0).get_meta("amount")==1.0 and banana.get_node("FourPeelStrips").get_child(2).get_meta("amount")==0.0,"only completed strips flop down")
	var consumption=consume.new();root.add_child(consumption);consumption.set_process(false);consumption.actor=actor;consumption.held_prop=banana;consumption.held_kind="shaker"
	consumption._update_shaker_ring(.301);var ring:MeshInstance3D=banana.get_node("ChargeRing");var before:PackedVector3Array=ring.mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
	consumption._update_shaker_ring(.302);var after:PackedVector3Array=ring.mesh.surface_get_arrays(1)[Mesh.ARRAY_VERTEX]
	check(before.size()==after.size() and before[-1]!=after[-1],"ring terminal edge advances continuously within one segment")
	consumption.held_prop=null
	var enemy=load("res://scripts/enemy.gd").new();root.add_child(enemy);enemy.position=Vector3(0,0,-8);enemy.setup(actor,0);enemy.set_physics_process(false)
	await physics_frame;await physics_frame
	var head:CollisionShape3D=enemy._detail_visual.head_hit_shape
	print("HEAD086 local centre=",head.position," size=",head.shape.size," legacy capsule top=",enemy._humanoid_collider.position.y+enemy._humanoid_collider.shape.height*.5)
	for x in [-.11,0,.11]:
		for y in [-.1,0,.1]:
			var centre:Vector3=head.global_position+head.global_basis*Vector3(x,y,0)
			var query:=PhysicsRayQueryParameters3D.create(centre+Vector3.BACK,centre+Vector3.FORWARD,4)
			var contact:Dictionary=root.get_world_3d().direct_space_state.intersect_ray(query)
			check(not contact.is_empty() and contact.collider==enemy,"actual physics head hit %s/%s"%[x,y])
	for yaw in [0.0,PI*.5,PI]:
		enemy.position+=Vector3(.4,0,.2);enemy._visual.rotation.y=yaw;enemy._detail_visual.update_pose(1.0/90,true,true,0,.4)
		await physics_frame;await physics_frame
		for direction in [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK]:
			var centre:Vector3=head.global_position+Vector3.UP*.1
			var contact:Dictionary=root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(centre-direction,centre+direction,4))
			check(not contact.is_empty() and contact.collider==enemy,"moving rotated animated crown hit "+str(yaw)+str(direction))
	print("RESULT feedback086 checks=",checks," failures=",failures)
	quit(1 if failures else 0)
