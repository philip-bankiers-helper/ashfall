extends SceneTree
var checks:=0
var failures:=0
const Reference=preload("res://scripts/reference_audio_099.gd")
const Damage=preload("res://scripts/one_star0991.gd")
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func freeze_tree(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():freeze_tree(child)
func run()->void:
	var game:Node3D=load("res://scripts/main.gd").new();root.add_child(game);game._start_from_title();freeze_tree(game)
	var actor:Node3D=game.player;actor.xr_enabled=false;actor.input_enabled=true
	check(ProjectSettings.get_setting("application/config/version")=="1.0.0.0","isolated multiplayer version")
	var guns:Array=game.weapon.weapons
	var dummy:Node3D=preload("res://scripts/practice_dummy.gd").new();game.add_child(dummy);dummy.position=Vector3(200,4,-5);dummy.set_process(false)
	await physics_frame;await physics_frame
	var ids:Dictionary={}
	for index in game.weapon.ACTIVE_WEAPON_INDICES:
		var gun:Node3D=guns[index];var id:=str(gun.get_meta("reference_id",""))
		if not Damage.data().has(id):continue
		ids[id]=true;var row:Dictionary=Damage.data()[id]
		check(absf(gun.damage*int(row.pellets)-float(row.body))<.001,"actual one-star discharge energy "+id)
		game.weapon.selected=index
		for zone in ["body","head"]:
			dummy.reset_target();var at:=dummy.global_position+Vector3(0,1.14 if zone=="body" else 1.72,0)
			if int(row.pellets)==8:
				var rays:Array[Vector3]=[]
				for i in 8:rays.append(Vector3.FORWARD)
				game._on_pellet_shot(at+Vector3.BACK*2,rays,gun.damage)
			else:game._on_shot(at+Vector3.BACK*2,Vector3.FORWARD,gun.damage)
			check(absf(dummy.last_damage-float(row[zone]))<.01,"real ray hits one-star "+id+" "+zone+" expected="+str(row[zone])+" actual="+str(dummy.last_damage))
		if "guns" in gun:
			for child in gun.guns:check(absf(child.damage-gun.damage)<.001,"both physical sides use selected gray one-star damage")
	check(ids.size()==21,"all twenty-one gun profiles covered")
	dummy.rotation.y=.85;await physics_frame
	var outside:=dummy.to_global(Vector3(.26,1.72,0));dummy.reset_target()
	game._on_shot(outside+dummy.global_basis.z*2,-dummy.global_basis.z,20)
	check(dummy.last_damage==0,"head-adjacent empty space is not an oversized capsule hit")
	var s85:Node3D=guns[25]
	var relative:Basis=s85.model.global_basis.inverse()*s85.get_offered_magazine_transform().basis
	check(relative.orthonormalized().is_equal_approx(Basis.IDENTITY),"S85 offer vertical in gun space")
	for index in [14,15,16]:
		var sword:Node3D=guns[index];var trail:Node3D=sword._gold_trail097
		check(trail!=null,"both Excalibur and Cyberblade own a full-blade sweep")
		for i in 20:trail.sample_blade(Vector3(i*.02,3,0),Vector3(i*.02,4,0),.01,true)
		check(trail.history.size()<=5 and trail.mesh.get_aabb().size.y>.99,"one-third trail lifetime still covers entire blade")
		var colors:PackedColorArray=trail.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		check(colors[0].r>.99 and (colors[0].b<.3 if index==16 else colors[0].b==1),"accepted white Katana/Excalibur and yellow Cyberblade")
		trail.sample_blade(Vector3.ZERO,Vector3.ZERO,0,false);check(trail.mesh.get_surface_count()==0,"stowed blade leaves no stale ribbon")
	var m10:Node3D=guns[9];var heights:Array[float]=[]
	for part in m10.shell_pack.get_children():
		if part is MeshInstance3D:heights.append(part.position.y);check(absf(part.position.x)<.001,"M10 shell centre in a single column")
	check(heights.size()==6,"M10 pack contains six underlying shells")
	heights.sort();check(heights[-1]-heights[0]>.17,"M10 six-shell column extends vertically")
	var p90:Node3D=guns[10];var flash:MeshInstance3D=p90.muzzle_flash
	var rear:Vector3=flash.transform*(flash.mesh.get_aabb().get_center()-Vector3.UP*flash.mesh.get_aabb().size.y*.5)
	check(rear.distance_to(p90.get_meta("download_muzzle_084"))<.0001,"flash rear face touches P90 muzzle")
	for index in [17,18,23,3]:
		var gun:Node3D=guns[index];var sight:Node3D=gun.get_meta("reflex_sight")
		check(absf(sight.global_basis.get_scale().x-(.75 if index in [17,18] else 1))<.001,"MP5/MP9 reduced, RFB/MK retained physical optic scale")
	var body:Node3D=game.body_visual;var wakes:Node3D=game.get_node("ElbowWakes0992");actor.gliding=true
	for i in 500:actor.global_position=Vector3(200+i*.03,6,0);body._process(.01);wakes._process(.01)
	for trail in wakes.trails:
		check(absf(trail.distance-12)<.001,"twelve metres retained through actual elbow producer")
		check(trail.mesh.get_aabb().size.length()<13,"trail local bounds stay near moving emitter")
		check(trail.visual.custom_aabb.has_point(Vector3.ZERO),"emitter bound includes near elbow for XR culling")
	actor.gliding=false;body._process(.01);wakes._process(.01)
	for trail in wakes.trails:check(trail.mesh.get_surface_count()==0,"landing clears flight wakes")
	var flight:AudioStreamWAV=Reference.generic("glide",0)
	check(flight.get_length()==16 and flight.loop_mode==AudioStreamWAV.LOOP_FORWARD,"long blended flight bed loops")
	for index in game.weapon.ACTIVE_WEAPON_INDICES:
		var gun:Node3D=guns[index]
		if gun.has_method("sample_motion"):continue
		for cue in ["mag_eject","pouch","mag_insert","bolt"]:check(Reference.weapon(cue,gun,0)!=null,"recorded mechanical fallback exists "+str(index)+" "+cue)
	var dt:Node3D=guns[1]
	for cue in ["open","insert","close"]:check(dt._mechanisms[cue]==Reference.generic(cue,0),"DT11 actual mechanical cache is recorded "+cue)
	for spec in [[7,"cylinder_open","mag_eject"],[7,"cylinder_loaded","mag_insert"],[8,"box_removed","mag_eject"],[8,"holding_box","pouch"],[8,"needs_feed","mag_insert"],[8,"box_seated","mag_insert"],[8,"needs_charge","close"]]:
		var gun:Node3D=guns[spec[0]];gun._audio_variant=0;gun._set_stage(spec[1],"")
		check(gun._sound.stream==Reference.weapon(spec[2],gun,0),"custom cylinder / M60 stages play recorded mechanics "+str(spec[1]))
	check(preload("res://scripts/weapon.gd").reload_cue0991("ready","needs_bolt")=="" and preload("res://scripts/weapon.gd").reload_cue0991("ready","needs_rack")=="","firing a bolt-action does not fake a magazine insertion")
	var supplies:Node3D=game.field_consumables
	var count:=supplies.get_child_count();check(supplies.collect(0),"actual heal pickup succeeds")
	check(supplies.get_child_count()>count,"actual heal pickup creates independent headset-level voice")
	count=supplies.get_child_count();check(supplies.equip_instance(supplies.selected_instance),"collected heal equips")
	check(supplies.get_child_count()>count and supplies.audio_events[-1]=="equip","actual heal equip creates its own voice")
	count=supplies.get_child_count();check(supplies.toggle_selected(),"double-A path stows selected heal")
	check(supplies.get_child_count()>count and supplies.audio_events[-1]=="stow","backpack stow survives held prop removal")
	supplies.equip_instance(supplies.selected_instance);actor.inventory_open=true
	count=supplies.audio_events.size();supplies._process(.01);actor.inventory_open=false
	check(supplies.held_kind.is_empty() and supplies.audio_events.size()==count+1 and supplies.audio_events[-1]=="stow","opening backpack also sounds once when stowing a heal")
	var floor_body:=StaticBody3D.new();game.add_child(floor_body);floor_body.position=Vector3(250,-.1,0);floor_body.collision_layer=1
	var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,.2,10);floor_shape.shape=box;floor_body.add_child(floor_shape)
	var frag:RigidBody3D=preload("res://scripts/explosive_projectile.gd").new();game.add_child(frag);frag.setup(game,{"kind":"frag","origin":Vector3(250,.12,0),"velocity":Vector3(8,0,0)});frag.set_physics_process(false)
	for i in 165:await physics_frame
	check(frag.ground_roll0991>1 and frag.ground_roll0991<3.2,"actual physics contact limits ground roll to ten feet")
	check(Vector2(frag.linear_velocity.x,frag.linear_velocity.z).length()<.1,"grenade comes to rest instead of rolling indefinitely")
	frag.free();floor_body.free();dummy.free();game.queue_free();await process_frame;await process_frame
	print("REGRESSION_0993 checks=",checks," failures=",failures," xr_runtime=off headset_tested=false")
	quit(0 if failures==0 else 1)
