extends SceneTree
class Actor extends Node3D:
	var tracking_available:=true
	func measured_eye_height()->float:return 1.65
var checks:=0
var failures:=0
var scene:Node3D
var b
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func box(size:Vector3,point:Vector3)->StaticBody3D:
	var body:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collider.shape=shape;body.add_child(collider);body.position=point;scene.add_child(body);return body
func aim(origin:Vector3,direction:Vector3)->void:
	b._update_placement({"origin":origin,"direction":direction.normalized(),"head":origin})
func face_hit(at:Transform3D,kind:String,origin:Vector3,direction:Vector3)->bool:
	var local:Vector3=at.affine_inverse()*origin
	var ray:Vector3=at.basis.inverse()*direction.normalized()
	var axis:=1 if kind=="floor" else 2
	if absf(ray[axis])<.00001:return false
	var distance:float=((.08 if kind=="floor" else 0.0)-local[axis])/ray[axis]
	var p:=local+ray*distance
	return distance>0 and distance<=b.placement_range and absf(p.x)<=b.grid_spacing*.5+.001 and absf(p.z if kind=="floor" else p.y)<=b.grid_spacing*.5+.001
func clear()->void:
	b.reset_builds();b.charges=12
	await physics_frame;await physics_frame
func run()->void:
	scene=Node3D.new();root.add_child(scene)
	var actor:=Actor.new();scene.add_child(actor)
	# Optional read-only comparison against the frozen predecessor, set only by
	# the dedicated audit command. Normal source/packed validation uses res://.
	var builder_script:=OS.get_environment("ASHFALL_BUILDING_AUDIT_SCRIPT")
	if builder_script.is_empty():builder_script="res://scripts/field_builder.gd"
	b=load(builder_script).new();scene.add_child(b);b.setup(actor,null,null)
	var side:float=b.grid_spacing
	check(absf(side-2.2*1.15)<.001 and b._shape.size.x==b._shape.size.y,"15percent larger square wall dimensions retained")
	var panel=load("res://scripts/construction_piece.gd").new();var material:=StandardMaterial3D.new();panel.apply_panel_material(material)
	var albedo:Image=material.albedo_texture.get_image();var neutral:=true;var shades:Dictionary={}
	for y in albedo.get_height():
		for x in albedo.get_width():
			var pixel:=albedo.get_pixel(x,y);neutral=neutral and absf(pixel.r-pixel.g)<.005 and absf(pixel.g-pixel.b)<.005;shades[pixel.to_html()]=true
	check(neutral and material.albedo_color.r==material.albedo_color.b and not material.emission_enabled,"every steel albedo pixel/tint neutral without steady blue emission")
	check(albedo.get_width()==256 and shades.size()>25 and material.roughness_texture!=null,"original detailed steel seams bolts brushing and scratches retained")
	panel.free()
	# Empty elevated space makes deeper floor faces possible; no terrain is
	# excluded to manufacture the through-panel success.
	for sign_y in [-1.0,1.0]:
		for lateral in [Vector2(.25,.1),Vector2(-.35,.2),Vector2(.04,-.2)]:
			await clear();b.piece_index=2;b._set_piece();b._active=true;b._level_y=8.37
			var origin:=Vector3(.6,9.62,.6)
			var direction:=Vector3(lateral.x,sign_y,lateral.y).normalized()
			aim(origin,direction);var first:Transform3D=b._placement
			check(b.preview_valid and face_hit(first,"floor",origin,direction),"floor first finite face on actual pointer "+str(direction))
			b._commit();await physics_frame
			aim(origin,direction)
			check(b.preview_valid and absf(b._placement.origin.y-first.origin.y-sign_y*side)<.001 and face_hit(b._placement,"floor",origin,direction),"through floor follows actual ray to next parallel plane "+str(direction))
			var before:int=b.charges;b._commit()
			check(b.pieces.filter(func(p):return p.get_meta("construction_kind","")=="floor").size()==2 and b.charges==before-2,"elevated floor plus one lower support commits atomically")
	# A near-vertical pointer has real depth along Y, while a horizontal or
	# too-shallow pointer cannot invent a floor under an unrelated endpoint.
	await clear();b.piece_index=2;b._set_piece();b._active=true;b._level_y=8.37
	for direction in [Vector3.RIGHT,Vector3(1,-.02,0).normalized()]:
		aim(Vector3(.6,9.62,.6),direction);var before:int=b.charges;b._commit()
		check(not b.preview_valid and b.pieces.is_empty() and b.charges==before,"nonintersecting floor pointer rejected without spend "+str(direction))
	# World geometry between the two horizontal planes must remain opaque.
	for blocker_y in [7.4,6.9]:
		await clear();b.piece_index=2;b._set_piece();b._active=true;b._level_y=8.37
		var origin:=Vector3(.6,9.62,.6);var direction:=Vector3(.08,-1,.02).normalized()
		aim(origin,direction);b._commit();await physics_frame
		var obstruction:=box(Vector3(3,.18,3),Vector3(.6,blocker_y,.6));await physics_frame;await physics_frame
		aim(origin,direction);var before:int=b.charges;b._commit()
		check(not b.preview_valid and b.invalid_reason=="obstruction" and b.charges==before,"own floor skip cannot bypass intervening world slab "+str(blocker_y))
		obstruction.free()
	# An oblique wall's lateral and height cell comes from the intersection with
	# its snapped depth plane, not the unrelated 2.5m ray endpoint.
	for direction in [Vector3(.6,.22,-1),Vector3(-.6,-.25,-1),Vector3(1,.18,.65),Vector3(-1,-.18,.65)]:
		await clear();b.piece_index=0;b._set_piece();b._active=true;b._level_y=8.37
		var origin:=Vector3(signf(direction.x)*.7,9.62,signf(direction.z)*.7);var ray:Vector3=direction.normalized()
		aim(origin,ray);var first:Transform3D=b._placement
		check(b.preview_valid and face_hit(first,"wall",origin,ray),"oblique first wall finite face contains pointer "+str(direction))
		b._commit();await physics_frame
		aim(origin,ray)
		check(b.preview_valid and face_hit(b._placement,"wall",origin,ray) and absf(absf((b._placement.origin-first.origin).dot(first.basis.z))-side)<.001,"oblique second depth face contains pointer "+str(direction))
		var normal:Vector3=first.basis.z
		var distance:float=(b._placement.origin-origin).dot(normal)/ray.dot(normal)
		var hit:Vector3=origin+ray*distance
		check(absf(b._placement.origin.y-(floorf((hit.y-8.37)/side)*side+8.37+side*.5))<.001,"oblique wall uses actually aimed height cell")
	# Adversarial boundary: the old endpoint-plus-grid-step chose the neighboring
	# lateral cell although the pointer missed its entire 16cm-thick collider.
	for quarter in 4:
		await clear();b.piece_index=0;b._set_piece();b._active=true;b._level_y=8.37
		var rotation:=Basis(Vector3.UP,quarter*PI*.5)
		var origin:Vector3=rotation*Vector3(-.7,9.62,-1)
		var direction:Vector3=rotation*Vector3(.15,.1,-1).normalized()
		aim(origin,direction)
		check(b.preview_valid and face_hit(b._placement,"wall",origin,direction),"boundary first wall follows pointer quarter="+str(quarter))
		b._commit();await physics_frame
		aim(origin,direction)
		check(b.preview_valid and face_hit(b._placement,"wall",origin,direction),"boundary next wall stays in actual lateral ray cell quarter="+str(quarter))
		b._commit();await physics_frame;await physics_frame
		var target:StaticBody3D=b.pieces[-1]
		var excluded:Array[RID]=[]
		for piece in b.pieces:
			if piece!=target:excluded.append(piece.get_rid())
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*b.placement_range,1,excluded)
		var collision:=scene.get_world_3d().direct_space_state.intersect_ray(query)
		check(not collision.is_empty() and collision.collider==target,"actual physics pointer hits farther wall finite collider quarter="+str(quarter))
	# Finite ramp wedges and their lower support track all four orientations.
	for direction in [Vector3(0,-.35,-1),Vector3(1,-.35,0),Vector3(0,-.35,1),Vector3(-1,-.35,0)]:
		await clear();b.piece_index=1;b._set_piece();b._active=true;b._level_y=8.37
		var origin:=Vector3(.6,9.62,.6)
		aim(origin,direction)
		check(b.preview_valid,"ramp actual finite wedge selected "+str(direction))
		if not b.preview_valid:continue
		b._commit();await physics_frame;await physics_frame
		var ramp:StaticBody3D=b.pieces[-1]
		var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction.normalized()*b.placement_range)
		var excluded:Array[RID]=[]
		for p in b.pieces:
			if p!=ramp:excluded.append(p.get_rid())
		query.exclude=excluded
		var hit:=scene.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider==ramp,"actual physics ray hits selected ramp wedge "+str(direction))
		var support:StaticBody3D=b.pieces[0]
		var expected:Vector3=ramp.position-ramp.basis.z*side*.5
		check(absf(support.position.x-expected.x)<.001 and absf(support.position.z-expected.z)<.001 and support.basis.z.dot(ramp.basis.z)>.99,"one lower support rotates with ramp edge "+str(direction))
		# A flat world slab earlier on that exact ray blocks further depth.
		var blocker:=box(Vector3(.4,.4,.4),origin+direction.normalized()*1.3);await physics_frame;await physics_frame
		aim(origin,direction);check(not b.preview_valid,"ramp cannot build behind world blocker "+str(direction));blocker.free()
	# A supporting body can also own an unrelated architectural shape. Only
	# the sampled ground shape may clip the floor, never the body's whole RID.
	await clear();b.piece_index=2;b._set_piece();b._active=false
	var terrain:=box(Vector3(30,.5,30),Vector3(0,-.25,0))
	var pillar:=CollisionShape3D.new();var pillar_shape:=BoxShape3D.new();pillar_shape.size=Vector3(.3,4,.3);pillar.shape=pillar_shape;pillar.position=Vector3(.7,2.25,.7);terrain.add_child(pillar)
	await physics_frame;await physics_frame
	aim(Vector3(.6,1.4,.6),Vector3.DOWN)
	check(not b.preview_valid and b.invalid_reason=="obstruction","sampled floor RID cannot exempt a separate upper pillar shape")
	pillar.free();await physics_frame;await physics_frame
	aim(Vector3(.6,1.4,.6),Vector3.DOWN)
	check(b.preview_valid and b.placement_cost==1,"actual sampled terrain surface still permits bounded floor overlap")
	terrain.free()
	await clear();scene.free();await create_timer(.2).timeout
	print("BUILDING_054_AIM checks=",checks," failures=",failures," actual_physics=true rendered=false headset_tested=false")
	quit(failures)
