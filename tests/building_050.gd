extends SceneTree
class Actor extends Node3D:
	var eye:=1.95
	var tracking_available:=true
	func measured_eye_height()->float:return eye
class Protected extends Node:
	var targets:Array=[]
	func _construction_protected_targets()->Array:return targets
var checks:=0
var failures:=0
var scene:Node3D
var builder
var game
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func box(size:Vector3,point:Vector3)->StaticBody3D:
	var b:=StaticBody3D.new();var c:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;c.shape=s;b.add_child(c);b.position=point;scene.add_child(b);return b
func aim(origin:Vector3,direction:Vector3)->void:
	builder._update_placement({"origin":origin,"direction":direction.normalized(),"head":origin,"exclusions":[]})
func run()->void:
	scene=Node3D.new();root.add_child(scene)
	var actor:=Actor.new();scene.add_child(actor);game=Protected.new();scene.add_child(game)
	builder=load("res://scripts/field_builder.gd").new();scene.add_child(builder);builder.setup(actor,null,game)
	var floor:=box(Vector3(40,.5,40),Vector3(0,-.25,0));await physics_frame;await physics_frame
	var side:float=builder.grid_spacing
	check(side>=actor.eye+.18 and is_equal_approx(side,builder.wall_height),"B01 square panels exceed head height with original18cm allowance")
	check(builder._shape.size.x==builder._shape.size.y,"B01 wall collider square")
	aim(Vector3(.5,1.5,.5),Vector3.FORWARD)
	check(builder.preview_valid and builder.placement_cost==1,"B03 flat-ground wall valid")
	var zface:Transform3D=builder._placement;builder._commit()
	await physics_frame;await physics_frame
	aim(Vector3(.5,1.5,-2.8),Vector3.RIGHT)
	check(builder.preview_valid,"B02 perpendicular face valid without center crossing")
	var xface:Transform3D=builder._placement;builder._commit()
	await physics_frame;await physics_frame
	check(absf(xface.basis.z.x)>.99 and absf(zface.basis.z.z)>.99,"B02 both vertical panel planes")
	var zcorner:=zface.origin+zface.basis*Vector3(side*.5,-side*.5,0)
	var xcorner:=xface.origin+xface.basis*Vector3(-side*.5,-side*.5,0)
	check(zcorner.distance_to(xcorner)<.001,"B02 perpendicular faces share corner instead of center")
	var before:int=builder.charges;builder._commit()
	check(builder.pieces.size()==2 and builder.charges==before,"B04 repeated placement cannot duplicate or spend")
	builder.piece_index=2;builder._set_piece();aim(Vector3(.5,1.5,-2.8),Vector3.DOWN)
	check(builder.preview_valid and builder._shape.size.x==builder._shape.size.z,"B02 horizontal floor is square and placeable")
	builder._commit();await physics_frame
	check(builder.pieces.size()==3,"B02 three planes committed as physical construction")
	builder.reset_builds();await physics_frame;await physics_frame
	floor.position.y=.35;await physics_frame # top.60, under one-third2.2m.
	builder.piece_index=0;builder._set_piece();aim(Vector3(.5,1.7,.5),Vector3.FORWARD)
	check(builder.preview_valid and builder.placement_cost==1,"B03 non-grid ground clips60cm, within declared one-third band")
	check(is_equal_approx(builder._placement.origin.y,side*.5),"B03 burial does not shift primary off its grid")
	floor.position.y=-.35;await physics_frame # top-.10 below primary base.
	aim(Vector3(.5,1.5,.5),Vector3.FORWARD)
	check(builder.preview_valid and builder.placement_cost==2 and builder._planned.size()==2,"B04 ground below tile creates one lower support and primary")
	builder.charges=1;aim(Vector3(.5,1.5,.5),Vector3.FORWARD);builder._commit()
	check(not builder.preview_valid and builder.pieces.is_empty() and builder.charges==1,"B04 insufficient two-piece budget commits neither member")
	builder.charges=6;aim(Vector3(.5,1.5,.5),Vector3.FORWARD);builder._commit()
	check(builder.pieces.size()==2 and builder.charges==4,"B04 two-piece cost atomic")
	check(absf(builder.pieces[1].position.y-builder.pieces[0].position.y-side)<.001,"B04 lower support exactly one panel below")
	builder.reset_builds();await physics_frame;await physics_frame
	floor.position.y=.02;floor.rotation.z=.10;await physics_frame
	aim(Vector3(.5,1.7,.5),Vector3.FORWARD)
	check(builder.preview_valid,"B03 real sloping non-grid support accepted without flatness gate")
	floor.queue_free();await physics_frame;await physics_frame
	aim(Vector3(.5,1.5,.5),Vector3.FORWARD)
	check(builder.preview_valid and builder.placement_cost==2,"B04 air placement permits explicit two-tile plan, no infinite column assumption")
	# Shared RID floor+pillar: lower terrain tolerance must not ignore an upper wall.
	var compound:=box(Vector3(40,.5,40),Vector3(0,-.25,0));var pillar:=CollisionShape3D.new();var ps:=BoxShape3D.new();ps.size=Vector3(1,4,.6);pillar.shape=ps;pillar.position=Vector3(side*.5,2.25,-side);compound.add_child(pillar);await physics_frame
	aim(Vector3(.5,1.5,.5),Vector3.FORWARD)
	check(not builder.preview_valid and builder.invalid_reason=="obstruction","B03 compound supporting RID cannot hide upper obstruction")
	compound.queue_free();await physics_frame;await physics_frame
	game.targets=[{"position":Vector3(side*.5,1,-side)}];aim(Vector3(.5,1.5,.5),Vector3.FORWARD)
	check(not builder.preview_valid and builder.invalid_reason=="objective_clearance","P01 objective clearance retained")
	game.targets=[];builder._update_placement({"origin":Vector3(.5,1.5,.5),"direction":Vector3.FORWARD,"head":Vector3(side*.5,1,-side)})
	check(not builder.preview_valid and builder.invalid_reason=="head_clearance","P01 head clearance retained")
	# Real player walks from a roof over two chained horizontal tiles.
	var roof:=box(Vector3(4,2.2,4),Vector3(-1.1,1.1,-1.1));await physics_frame
	builder.piece_index=2;builder._set_piece();builder.charges=12
	aim(Vector3(-.4,3.7,-1.1),Vector3(1,-1.8,0))
	check(builder.preview_valid,"B02 first horizontal roof extension valid")
	builder._commit();await physics_frame;await physics_frame
	aim(Vector3(1.8,3.7,-1.1),Vector3(1,-1.8,0))
	check(builder.preview_valid,"B02 next horizontal tile can extend from first")
	builder._commit();await physics_frame;await physics_frame
	var walker=load("res://scripts/player.gd").new();scene.add_child(walker);walker.setup(false);walker.set_process(false);walker.set_physics_process(false);walker.position=Vector3(.5,2.2,-1.1)
	await physics_frame
	var continuously_supported:=true
	for i in 37:
		walker.apply_locomotion_motion(Vector3.RIGHT,Vector3.FORWARD,false,false,1.0/90.0);await physics_frame
		if not walker.is_supported() or absf(walker.position.y-2.2)>.03:continuously_supported=false
	check(walker.position.x>3 and absf(walker.position.y-2.2)<.03 and continuously_supported,"B02 actual player continuously walks roof -> first -> second floor tile without gap drop")
	walker.free();roof.free();builder.reset_builds();scene.free();await create_timer(.2).timeout
	print("BUILDING_050 checks=",checks," failures=",failures," actual_geometry=true terrain_rules_original_assumption=true headset_tested=false")
	quit(failures)
