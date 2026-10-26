extends SceneTree
const Builder=preload("res://scripts/field_builder.gd")
const Support=preload("res://scripts/construction_support.gd")
const BuildAudio=preload("res://scripts/construction_audio.gd")
class Actor extends Node3D:
	var tracking_available:=true
class Game extends Node:
	var paused:=false
	var targets:Array=[]
	func _construction_protected_targets()->Array:return targets
var checks:=0
var failures:=0
var scene:Node3D
var actor:Actor
var game:Game
var b
var world_bodies:Array[StaticBody3D]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func box(size:Vector3,point:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;c.shape=s;body.add_child(c);body.position=point;scene.add_child(body);world_bodies.append(body);return body
func entry(kind:String,point:Vector3,basis:=Basis.IDENTITY)->Dictionary:
	return b._plan_entry(kind,Transform3D(basis,point),{"found":false,"max_y":-INF,"min_y":INF,"rids":[]})
func spawn(kind:String,point:Vector3,basis:=Basis.IDENTITY)->StaticBody3D:
	b._spawn_entry(entry(kind,point,basis));return b.pieces[-1]
func reset()->void:
	b.reset_builds();b.set_physics_process(false)
	for body in world_bodies:
		if is_instance_valid(body):body.free()
	world_bodies.clear();game.targets.clear()
	await physics_frame;await physics_frame
func aim(origin:Vector3,target:Vector3)->void:
	b._update_placement({"origin":origin,"direction":(target-origin).normalized(),"head":origin})
func make_chain()->Array[StaticBody3D]:
	box(Vector3(4,1,4),Vector3(2,-.5,2));await physics_frame;await physics_frame
	var result:Array[StaticBody3D]=[]
	for x in [6.0,10.0,14.0]:result.append(spawn("floor",Vector3(x,-.08,2)))
	b._refresh_support_graph();return result
func run()->void:
	scene=Node3D.new();root.add_child(scene);actor=Actor.new();scene.add_child(actor);game=Game.new();scene.add_child(game)
	b=Builder.new();scene.add_child(b);b.setup(actor,null,game);b.set_physics_process(false)
	check(b.grid_spacing==4 and b.wall_height==4,"4m measured dimensions retained independent of player height")
	check(b.charges==999 and b.max_charges==999 and b.max_live_pieces==256,"expanded finite testing stock and bounded 256-panel scene")
	check(b._geometry("floor").shape.size==Vector3(4,.16,4),"horizontal panel has actual square walkable collider")
	var a:=entry("floor",Vector3(2,3.92,2))
	check(Support.connected(a,entry("floor",Vector3(6,3.92,2)),4),"finite shared floor edge carries support")
	check(not Support.connected(a,entry("floor",Vector3(6.2,3.92,2)),4),"20cm air gap does not carry support")
	check(not Support.connected(a,entry("floor",Vector3(6,3.92,6)),4),"diagonal corner alone does not carry 4m panel")
	check(Support.connected(a,entry("wall",Vector3(2,2,0)),4),"wall upper edge supports horizontal roof")
	check(not Support.connected(entry("floor",Vector3(2,3.92,5.7)),entry("ramp",Vector3(2,0,2)),4),"solid ramp AABB empty upper space does not create support")
	for quarter in 4:
		var rotation:=Basis(Vector3.UP,quarter*PI*.5);var ramp:=entry("ramp",Vector3(2,0,2),rotation)
		check(Support.connected(ramp,entry("floor",Vector3(2,0,2)+rotation*Vector3(0,3.92,-4)),4),"finite ramp high edge supports next floor quarter="+str(quarter))
		check(Support.connected(ramp,entry("floor",Vector3(2,0,2)+rotation*Vector3(0,-.08,4)),4),"finite ramp low edge supports next floor quarter="+str(quarter))
	# Real preview + trigger input places a horizontal runway from a roof edge.
	box(Vector3(4,1,4),Vector3(2,-.5,2));await physics_frame;await physics_frame
	b.piece_index=0;b._set_piece()
	b.tick_input({"trigger":false,"cycle":false,"tracking":true,"eligible":true,"origin":Vector3(3.5,1.3,2),"direction":Vector3(1,-.5,0),"head":Vector3(3.5,1.8,2)})
	for i in 2:
		b.tick_input({"trigger":false,"cycle":true,"tracking":true,"eligible":true,"origin":Vector3(3.5,1.3,2),"direction":Vector3(1,-.5,0),"head":Vector3(3.5,1.8,2)})
		b.tick_input({"trigger":false,"cycle":false,"tracking":true,"eligible":true,"origin":Vector3(3.5,1.3,2),"direction":Vector3(1,-.5,0),"head":Vector3(3.5,1.8,2)})
	check(b.piece_index==2 and b.pieces.is_empty(),"actual shape-button edges select horizontal without building wall")
	for i in 3:
		var x:=6.0+i*4.0;var origin:=Vector3(x-2.5,1.3,2);var direction:Vector3=(Vector3(x,0,2)-origin).normalized()
		var state:={"trigger":false,"cycle":false,"tracking":true,"eligible":true,"origin":origin,"direction":direction,"head":origin+Vector3.UP*.4}
		b.tick_input(state);state.trigger=true;b.tick_input(state);state.trigger=false;b.tick_input(state)
		check(b.pieces.size()==i+1 and b.pieces[-1].get_meta("construction_kind")=="floor","actual trigger builds horizontal extension "+str(i))
		check(b.charges==998-i and b.pieces.all(func(p):return p.get_meta("construction_kind")=="floor"),"supported horizontal extension does not spend on hanging lower wall "+str(i))
		await physics_frame;await physics_frame
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(x,1,2),Vector3(x,-1,2),1)
		var hit:=scene.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==b.pieces[-1] and absf(hit.position.y)<.002,"horizontal extension has continuous standing top "+str(i))
	check(b.charges==996 and b._audio_voices.size()==8 and b._audio_voices[0].stream!=null,"three successful placements spend three and trigger bounded positional sound")
	await reset()
	b.piece_index=2;b._set_piece();b._active=true;b._level_y=20
	aim(Vector3(3.5,21.3,2),Vector3(6,20,2));var before:int=b.charges;b._commit()
	check(not b.preview_valid and b.invalid_reason=="unsupported" and b.pieces.is_empty() and b.charges==before,"no floor or invented hanging wall may float high above world")
	box(Vector3(40,.5,40),Vector3(2,-.25,2));await physics_frame;await physics_frame
	aim(Vector3(3.5,21.3,2),Vector3(6,20,2));check(not b.preview_valid and b.invalid_reason=="unsupported","world terrain 20m below does not count as touching support")
	# A wall exactly one layer below may bridge to real world, atomically.
	b._active=false;b.piece_index=0;b._set_piece();world_bodies[0].position.y=-.35;await physics_frame;await physics_frame
	aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4))
	check(b.preview_valid and b.placement_cost==2,"one explicit lower wall reaches nearby low terrain")
	b.charges=1;aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4));b._commit();check(b.pieces.is_empty() and b.charges==1,"two-piece support plan cannot half-spend scarce stock")
	await reset()
	var chain:Array[StaticBody3D]=await make_chain()
	check(b._supported.size()==3 and b._collapse_pending.is_empty(),"three floor panels trace graph to finite roof edge")
	chain[0].hit(1000)
	check(b.pieces.size()==2 and b._collapse_pending.size()==2,"support destruction immediately schedules disconnected component")
	check(absf(float(b._collapse_pending[chain[1].get_instance_id()])-.3)<.0001 and absf(float(b._collapse_pending[chain[2].get_instance_id()])-.6)<.0001,"collapse propagates outward at 300ms per graph edge")
	b._physics_process(.299);check(not chain[1].broken and not chain[2].broken,"no early first or distant collapse")
	b._physics_process(.002);check(chain[1].broken and not chain[2].broken,"nearest orphan breaks at first wave")
	b._physics_process(.298);check(not chain[2].broken,"far panel retains its scheduled later wave")
	b._physics_process(.002);check(chain[2].broken and b.pieces.is_empty() and b._collapse_pending.is_empty(),"far panel breaks at second wave and clears graph capacity")
	check(b.charges==999,"collapse never refunds build supply")
	await reset()
	box(Vector3(40,.5,40),Vector3(2,-.25,-2));await physics_frame;await physics_frame
	b._active=false;b.piece_index=0;b._set_piece()
	aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4))
	var at:Vector3=b._placement.origin
	b._update_placement({"origin":Vector3(.5,1.5,.5),"direction":Vector3.FORWARD,"head":at})
	check(not b.preview_valid and b.invalid_reason=="head_clearance","support acceptance never overrides protected head volume")
	game.targets=[{"position":at}];aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4))
	check(not b.preview_valid and b.invalid_reason=="objective_clearance","support acceptance never covers protected objective")
	game.targets.clear()
	var pillar:=CollisionShape3D.new();var pillar_shape:=BoxShape3D.new();pillar_shape.size=Vector3(1,4,.6);pillar.shape=pillar_shape;pillar.position=at-world_bodies[0].position;world_bodies[0].add_child(pillar);await physics_frame;await physics_frame
	aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4))
	check(not b.preview_valid and b.invalid_reason=="obstruction","compound map body's ground contact cannot hide its upper blocking shape")
	pillar.free();await physics_frame;await physics_frame
	aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4));check(b.preview_valid,"same world supports wall when actual blocking pillar removed")
	var late_blocker:=box(Vector3(1,3,.6),at+Vector3.UP*.2);await physics_frame;await physics_frame;before=b.charges;b._commit()
	check(b.pieces.is_empty() and b.charges==before and b.invalid_reason=="obstruction","world obstruction appearing after preview blocks commit without spend")
	world_bodies.erase(late_blocker);late_blocker.free();await physics_frame;await physics_frame;aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4))
	world_bodies[0].free();world_bodies.clear();await physics_frame;await physics_frame;before=b.charges;b._commit()
	check(b.pieces.is_empty() and b.charges==before and b.invalid_reason=="unsupported","support disappearing after preview blocks commit without expenditure")
	# World side contacts count only at the actual convex panel surface.
	box(Vector3(.2,12,4),Vector3(4.1,6,2));await physics_frame;await physics_frame
	check(b._connected_to_supported([entry("floor",Vector3(2,7.92,2))]),"horizontal platform can attach to a vertical map surface at height")
	check(not b._connected_to_supported([entry("floor",Vector3(1.8,7.92,2))]),"nearby vertical map surface separated by air is insufficient")
	await reset();chain=await make_chain()
	box(Vector3(.2,1,4),Vector3(16.1,-.5,2));await physics_frame;await physics_frame;b._refresh_support_graph();chain[0].hit(1000)
	check(b.pieces.size()==2 and b._supported.size()==2 and b._collapse_pending.is_empty(),"alternate world anchor preserves connected remainder")
	await reset();chain=await make_chain();chain[0].hit(1000);b._physics_process(.15)
	box(Vector3(.2,1,4),Vector3(16.1,-.5,2));await physics_frame;await physics_frame;b._refresh_support_graph();b._physics_process(1)
	check(b.pieces.size()==2 and b._collapse_pending.is_empty(),"reattached world support cancels pending collapse before due")
	await reset();chain=await make_chain();world_bodies[0].free();world_bodies.clear();await physics_frame;await physics_frame;b._physics_process(.25)
	check(b._collapse_pending.size()==3 and b._supported.is_empty(),"removed world surface detected by bounded periodic contact poll")
	game.paused=true;b._physics_process(5);check(not chain[0].broken,"paused gameplay freezes collapse timers")
	game.paused=false;b._physics_process(.301);check(chain[0].broken and not chain[1].broken,"world-anchor loss also advances outward one panel per wave")
	b.reset_builds();b._physics_process(5);check(b.pieces.is_empty() and b._collapse_pending.is_empty() and b.charges==999,"reset clears timers and restores finite stock without stale events")
	# Read-only audio verification; no audible/headset validation claimed.
	var place:=BuildAudio.stream();var breakup:=BuildAudio.stream(true)
	check(place.data.size()>6000 and breakup.data.size()>9000 and place.mix_rate==22050 and place.data!=breakup.data,"placement and break have distinct original PCM transients")
	await reset()
	box(Vector3(4,1,4),Vector3(2,-.5,2));await physics_frame;await physics_frame
	for i in 256:spawn("floor",Vector3(6.0+4.0*i,-.08,2))
	var started:=Time.get_ticks_usec();b._refresh_support_graph();var build_ms:=float(Time.get_ticks_usec()-started)/1000.0
	check(b._supported.size()==256 and b._collapse_pending.is_empty(),"full 256-panel runway support graph remains connected and bounded")
	b.pieces[0].hit(1000)
	var tail:StaticBody3D=b.pieces[-1]
	check(b._collapse_pending.size()==255 and absf(float(b._collapse_pending[tail.get_instance_id()])-76.5)<.001,"full-capacity chain schedules one outward deadline per panel")
	print("CONSTRUCTION_GRAPH_061 panels=256 refresh_ms=",build_ms," exact_native_performance_unverified=true")
	await reset();scene.free();await process_frame;await create_timer(.1).timeout
	print("CONSTRUCTION_SUPPORT_061 checks=",checks," failures=",failures," physics=true audio_pcm=true rendered=false headset_tested=false")
	quit(failures)
