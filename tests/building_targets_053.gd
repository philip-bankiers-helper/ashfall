extends SceneTree
class Actor extends Node3D:
	var tracking_available:=true
	func measured_eye_height()->float:return 1.65
var checks:=0
var failures:=0
var b
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func box(size:Vector3,at:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();var collider:=CollisionShape3D.new();var s:=BoxShape3D.new();s.size=size;collider.shape=s;body.add_child(collider);body.position=at;root.add_child(body);return body
func aim(direction:Vector3)->void:b._update_placement({"origin":Vector3(.5,1.5,.5),"direction":direction,"head":Vector3(.5,1.5,.5)})
func run()->void:
	var actor:=Actor.new();root.add_child(actor);b=load("res://scripts/field_builder.gd").new();root.add_child(b);b.setup(actor,null,null)
	var ground:=box(Vector3(40,.5,40),Vector3(0,-.25,0));await physics_frame;await physics_frame
	check(absf(b.grid_spacing-2.2*1.15)<.001 and b._shape.size.x==b._shape.size.y,"panels exactly15percent larger and square")
	var side:float=b.grid_spacing
	for direction in [Vector3.FORWARD,Vector3.RIGHT]:
		b.reset_builds();await physics_frame;await physics_frame;b.charges=12
		aim(direction);check(b.preview_valid,"first vertical plane valid "+str(direction));b._commit();await physics_frame
		var first:Transform3D=b._placement
		aim(direction);check(b.preview_valid and absf(b._placement.origin.y-first.origin.y)<.001 and absf((b._placement.origin-first.origin).dot(direction)-side)<.001,"same pointer builds through own wall exactly one depth cell, no upward fallback "+str(direction))
		b._commit();await physics_frame
		check(b.pieces.size()==2 and b.charges==10,"two depth panels cost exactly two charges")
		aim(direction);var before:int=b.charges;b._commit();check(not b.preview_valid and b.invalid_reason=="reach" and b.charges==before,"third depth outside sixmetre reach is rejected without charge")
	b.reset_builds();await physics_frame;await physics_frame;b.charges=12;b.piece_index=2;b._set_piece()
	var state:={"origin":Vector3(.7,1.4,.5),"direction":Vector3(1,-.5,0).normalized(),"head":Vector3(.5,1.5,.5)}
	b._update_placement(state);check(b.preview_valid,"horizontal floor first aimed cell valid");b._commit();await physics_frame
	var first_floor:Vector3=b._placement.origin
	b._update_placement(state);check(b.preview_valid and absf(b._placement.origin.y-first_floor.y)<.001 and absf(b._placement.origin.x-first_floor.x-side)<.001,"floor builds through own occupied cell along pointer azimuth without upward substitution");b._commit();await physics_frame
	check(b.pieces.size()==2 and b.charges==10,"horizontal depth extension costs two single panels")
	b.piece_index=0;b._set_piece()
	b.reset_builds();await physics_frame;await physics_frame;b.charges=12
	aim(Vector3.FORWARD);b._commit();await physics_frame
	var obstruction:=box(Vector3(4,4,.30),Vector3(1,2,-4));await physics_frame;await physics_frame
	aim(Vector3.FORWARD);check(not b.preview_valid,"world blocker prevents building through own wall into farther cell")
	obstruction.free();b.reset_builds();await physics_frame;await physics_frame
	ground.position.y=1.0;await physics_frame;aim(Vector3.FORWARD)
	check(not b.preview_valid and absf(b._placement.origin.y-side*.5)<.001,"excess terrain burial rejects aimed cell without automatic upward replacement")
	var piece=load("res://scripts/construction_piece.gd").new();var material:=StandardMaterial3D.new();piece.apply_panel_material(material)
	var image:Image=material.albedo_texture.get_image();var neutral:=true;var distinct:Dictionary={}
	for y in image.get_height():
		for x in image.get_width():
			var c:=image.get_pixel(x,y);neutral=neutral and absf(c.r-c.g)<.005 and absf(c.g-c.b)<.005;distinct[c.to_html()]=true
	check(neutral and material.albedo_color.r==material.albedo_color.b and not material.emission_enabled,"all steel texture pixels and tint neutral with no blue emission")
	check(image.get_width()==256 and distinct.size()>25,"steel texture retains original seams fasteners brushing and scratch detail")
	piece.free();ground.free();b.reset_builds();b.free();actor.free();await create_timer(.2).timeout
	print("BUILDING_TARGETS_053 checks=",checks," failures=",failures," physics_tested=true rendered=false")
	quit(failures)

