extends SceneTree
const SIDE := 2.8203180722891568 # Independent eight-foot acceptance value in true SI.
const HALF := SIDE*.5
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
	box(Vector3(SIDE,1,SIDE),Vector3(HALF,-.5,HALF));await physics_frame;await physics_frame
	var result:Array[StaticBody3D]=[]
	for x in [SIDE*1.5,SIDE*2.5,SIDE*3.5]:result.append(spawn("floor",Vector3(x,-.08,HALF)))
	b._refresh_support_graph();return result
func run()->void:
	scene=Node3D.new();root.add_child(scene);actor=Actor.new();scene.add_child(actor);game=Game.new();scene.add_child(game)
	b=Builder.new();scene.add_child(b);b.setup(actor,null,game);b.set_physics_process(false)
	check(is_equal_approx(b.grid_spacing,SIDE) and is_equal_approx(b.wall_height,SIDE),"eight-foot (2.8203180722891568m) measured dimensions converted once, independent of player height")
	check(b.charges==999 and b.max_charges==999 and b.max_live_pieces==256,"expanded finite testing stock and bounded 256-panel scene")
	check(b._geometry("floor").shape.size==Vector3(SIDE,.08,SIDE),"horizontal panel has actual square walkable collider")
	check(b._geometry("wall").shape.size==Vector3(SIDE,SIDE,.08) and is_equal_approx(b.minimum_wall_height,SIDE),"wall width, height and minimum use eight feet while physical thickness stays8cm")
	var ramp_bounds:=Support.bounds(b._geometry("ramp").shape.points)
	check(ramp_bounds.size.is_equal_approx(Vector3(SIDE,SIDE,SIDE)),"ramp footprint and rise scale once, retaining45degree slope")
	check(Support.CONTACT_TOLERANCE==.045 and Support.MIN_EDGE_CONTACT==.25 and b.placement_range==6.0 and b.grid_height_step==.1,"true-SI support and tool tolerances remain unscaled")
	check(b.scale==Vector3.ONE and b.collapse_step_seconds==.30 and b.support_poll_seconds==.25 and b.debris_lifetime==.65,"no global scale or time conversion compounds the measured correction")
	var a:=entry("floor",Vector3(HALF,SIDE-.08,HALF))
	check(Support.connected(a,entry("floor",Vector3(SIDE*1.5,SIDE-.08,HALF)),SIDE),"finite shared floor edge carries support")
	check(not Support.connected(a,entry("floor",Vector3(SIDE*1.5+.2,SIDE-.08,HALF)),SIDE),"20cm air gap does not carry support")
	check(Support.connected(a,entry("floor",Vector3(SIDE*1.5+.04,SIDE-.08,HALF)),SIDE) and not Support.connected(a,entry("floor",Vector3(SIDE*1.5+.06,SIDE-.08,HALF)),SIDE),"4cm and6cm seam probes retain the original4.5cm physical boundary")
	check(not Support.connected(a,entry("floor",Vector3(SIDE*1.5,SIDE-.08,SIDE*1.5)),SIDE),"diagonal corner alone does not carry measured panel")
	check(Support.connected(a,entry("wall",Vector3(HALF,HALF,0)),SIDE),"wall upper edge supports horizontal roof")
	check(not Support.connected(entry("floor",Vector3(HALF,SIDE-.08,SIDE*1.425)),entry("ramp",Vector3(HALF,0,HALF)),SIDE),"solid ramp AABB empty upper space does not create support")
	for quarter in 4:
		var rotation:=Basis(Vector3.UP,quarter*PI*.5);var ramp:=entry("ramp",Vector3(HALF,0,HALF),rotation)
		check(Support.connected(ramp,entry("floor",Vector3(HALF,0,HALF)+rotation*Vector3(0,SIDE-.08,-SIDE)),SIDE),"finite ramp high edge supports next floor quarter="+str(quarter))
		check(Support.connected(ramp,entry("floor",Vector3(HALF,0,HALF)+rotation*Vector3(0,-.08,SIDE)),SIDE),"finite ramp low edge supports next floor quarter="+str(quarter))
	# Real preview + trigger input places a horizontal runway from a roof edge.
	box(Vector3(SIDE,1,SIDE),Vector3(HALF,-.5,HALF));await physics_frame;await physics_frame
	b.piece_index=0;b._set_piece()
	b.tick_input({"trigger":false,"cycle":false,"tracking":true,"eligible":true,"origin":Vector3(SIDE-.3,1.3,HALF),"direction":Vector3(1,-.5,0),"head":Vector3(SIDE-.3,1.8,HALF)})
	for i in 2:
		b.tick_input({"trigger":false,"cycle":true,"tracking":true,"eligible":true,"origin":Vector3(SIDE-.3,1.3,HALF),"direction":Vector3(1,-.5,0),"head":Vector3(SIDE-.3,1.8,HALF)})
		b.tick_input({"trigger":false,"cycle":false,"tracking":true,"eligible":true,"origin":Vector3(SIDE-.3,1.3,HALF),"direction":Vector3(1,-.5,0),"head":Vector3(SIDE-.3,1.8,HALF)})
	check(b.piece_index==0 and b.pieces.is_empty(),"legacy cycle input cannot select a shape or place a panel")
	for i in 3:
		var x:=SIDE*1.5+i*SIDE;var origin:=Vector3(x-(HALF-.3),1.3,HALF);var direction:Vector3=(Vector3(x,0,HALF)-origin).normalized()
		var state:={"trigger":false,"cycle":false,"tracking":true,"eligible":true,"origin":origin,"direction":direction,"head":origin+Vector3.UP*.4}
		b.tick_input(state);state.trigger=true;b.tick_input(state);state.trigger=false;b.tick_input(state)
		check(b.pieces.size()==i+1 and b.pieces[-1].get_meta("construction_kind")=="floor","actual trigger builds horizontal extension "+str(i))
		check(b.charges==998-i and b.pieces.all(func(p):return p.get_meta("construction_kind")=="floor"),"supported horizontal extension does not spend on hanging lower wall "+str(i))
		await physics_frame;await physics_frame
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(x,1,HALF),Vector3(x,-1,HALF),1)
		var hit:=scene.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and hit.collider==b.pieces[-1] and absf(hit.position.y-.04)<.002,"horizontal extension has shared-plane center and8cm collider top "+str(i))
	check(b.charges==996 and b._audio_voices.size()==8 and b._audio_voices[0].stream!=null,"three successful placements spend three and trigger bounded positional sound")
	await reset()
	b.piece_index=1;b._set_piece();b._active=true;b._level_y=20
	aim(Vector3(SIDE-.3,21.3,HALF),Vector3(SIDE*1.5,20,HALF));var before:int=b.charges;b._commit()
	check(not b.preview_valid and b.invalid_reason=="unsupported" and b.pieces.is_empty() and b.charges==before,"no floor or invented hanging wall may float high above world")
	box(Vector3(40,.5,40),Vector3(HALF,-.25,HALF));await physics_frame;await physics_frame
	aim(Vector3(SIDE-.3,21.3,HALF),Vector3(SIDE*1.5,20,HALF));check(not b.preview_valid and b.invalid_reason=="unsupported","world terrain 20m below does not count as touching support")
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
	check(not b.preview_valid or b._placement.origin.distance_to(at)>.3,"support acceptance never overrides protected head volume")
	game.targets=[{"position":at}];aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4))
	check(not b.preview_valid or b._placement.origin.distance_to(at)>.5,"support acceptance never covers protected objective")
	game.targets.clear()
	var pillar:=CollisionShape3D.new();var pillar_shape:=BoxShape3D.new();pillar_shape.size=Vector3(1,4,.6);pillar.shape=pillar_shape;pillar.position=at-world_bodies[0].position;world_bodies[0].add_child(pillar);await physics_frame;await physics_frame
	aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4))
	check(b.preview_valid,"compound map object may overlap supported panel")
	pillar.free();await physics_frame;await physics_frame
	aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4));check(b.preview_valid,"same world supports wall when actual blocking pillar removed")
	var late_blocker:=box(Vector3(1,3,.6),at+Vector3.UP*.2);await physics_frame;await physics_frame;before=b.charges;b._commit()
	check(b.pieces.size()==1 and b.charges==before-1,"world object appearing after preview permits supported commit");b.reset_builds();await physics_frame;await physics_frame
	world_bodies.erase(late_blocker);late_blocker.free();await physics_frame;await physics_frame;aim(Vector3(.5,1.5,.5),Vector3(.5,1.5,-4))
	world_bodies[0].free();world_bodies.clear();await physics_frame;await physics_frame;before=b.charges;b._commit()
	check(b.pieces.is_empty() and b.charges==before and b.invalid_reason=="unsupported","support disappearing after preview blocks commit without expenditure")
	# World side contacts count only at the actual convex panel surface.
	box(Vector3(.2,12,SIDE),Vector3(SIDE+.1,6,HALF));await physics_frame;await physics_frame
	check(b._connected_to_supported([entry("floor",Vector3(HALF,7.92,HALF))]),"horizontal platform can attach to a vertical map surface at height")
	check(not b._connected_to_supported([entry("floor",Vector3(HALF-.2,7.92,HALF))]),"nearby vertical map surface separated by air is insufficient")
	await reset();chain=await make_chain()
	box(Vector3(.2,1,SIDE),Vector3(SIDE*4+.1,-.5,HALF));await physics_frame;await physics_frame;b._refresh_support_graph();chain[0].hit(1000)
	check(b.pieces.size()==2 and b._supported.size()==2 and b._collapse_pending.is_empty(),"alternate world anchor preserves connected remainder")
	await reset();chain=await make_chain();chain[0].hit(1000);b._physics_process(.15)
	box(Vector3(.2,1,SIDE),Vector3(SIDE*4+.1,-.5,HALF));await physics_frame;await physics_frame;b._refresh_support_graph();b._physics_process(1)
	check(b.pieces.size()==2 and b._collapse_pending.is_empty(),"reattached world support cancels pending collapse before due")
	await reset();chain=await make_chain();world_bodies[0].free();world_bodies.clear();await physics_frame;await physics_frame;b._physics_process(.25)
	check(b._collapse_pending.size()==3 and b._supported.is_empty(),"removed world surface detected by bounded periodic contact poll")
	game.paused=true;b._physics_process(5);check(not chain[0].broken,"paused gameplay freezes collapse timers")
	game.paused=false;b._physics_process(.301);check(chain[0].broken and not chain[1].broken,"world-anchor loss also advances outward one panel per wave")
	b.reset_builds();b._physics_process(5);check(b.pieces.is_empty() and b._collapse_pending.is_empty() and b.charges==999,"reset clears timers and restores finite stock without stale events")
	check(is_equal_approx(b.grid_spacing,2.8203180722891568) and is_equal_approx(b.wall_height,2.8203180722891568),"reset and input cycles do not compound0.6096 conversion")
	# Read-only audio verification; no audible/headset validation claimed.
	var place:=BuildAudio.stream();var breakup:=BuildAudio.stream(true)
	check(place.data.size()>6000 and breakup.data.size()>9000 and place.mix_rate==22050 and place.data!=breakup.data,"placement and break have distinct original PCM transients")
	await reset()
	box(Vector3(SIDE,1,SIDE),Vector3(HALF,-.5,HALF));await physics_frame;await physics_frame
	for i in 256:spawn("floor",Vector3(SIDE*1.5+SIDE*i,-.08,HALF))
	var started:=Time.get_ticks_usec();b._refresh_support_graph();var build_ms:=float(Time.get_ticks_usec()-started)/1000.0
	check(b._supported.size()==256 and b._collapse_pending.is_empty(),"full 256-panel runway support graph remains connected and bounded")
	b.pieces[0].hit(1000)
	var tail:StaticBody3D=b.pieces[-1]
	check(b._collapse_pending.size()==255 and absf(float(b._collapse_pending[tail.get_instance_id()])-76.5)<.001,"full-capacity chain schedules one outward deadline per panel")
	print("CONSTRUCTION_GRAPH_062 panels=256 refresh_ms=",build_ms," exact_native_performance_unverified=true")
	await reset();scene.free();await process_frame;await create_timer(.1).timeout
	print("CONSTRUCTION_SUPPORT_062 checks=",checks," failures=",failures," physics=true audio_pcm=true rendered=false headset_tested=false")
	quit(failures)
