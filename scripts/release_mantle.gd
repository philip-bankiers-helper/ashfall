extends RefCounted
## Original release assistance, not a claim about another game's exact tuning.
## Plans an optional setback, lift, and inward collision-swept route.
## Never disables a collider.
const GRAZING_REACH:=.115
const GRAZING_TOP_ABOVE:=.0025
const GRAZING_TOP_BELOW:=.065

## Current head-only player: finish the last local rim overlap on final grip
## release. The tracked hand can be beside the head, so its anchor bearing is
## a preference rather than the only direction in which a real top is sought.
## Standing elevation remains owned by the player's normal support resolver.
static func recover_grazing(body:CharacterBody3D,body_shape:CollisionShape3D,head:Vector3,anchor:Vector3)->bool:
	var route:=plan_grazing(body,body_shape,head,anchor)
	if route.is_empty():return false
	var before:=body.global_transform
	for motion:Vector3 in [route.lift,route.inward]:
		var expected:=body.global_position+motion
		var collision:=body.move_and_collide(motion)
		if collision!=null or body.global_position.distance_to(expected)>.001:
			# The complete route was checked without yielding. If the solver still
			# refuses it, keep a failed release at its original known position.
			body.global_transform=before
			return false
	return true

static func plan_grazing(body:CharacterBody3D,body_shape:CollisionShape3D,head:Vector3,anchor:Vector3)->Dictionary:
	if not is_instance_valid(body) or not body.is_inside_tree():return {}
	if not is_instance_valid(body_shape) or body_shape.shape==null or body_shape.disabled:return {}
	if not head.is_finite() or not anchor.is_finite() or head.distance_to(anchor)>1.0:return {}
	# The caller synchronizes the actual goggle collider to the current tracked
	# pose. A stale collider must never validate a different head's route.
	if body_shape.global_position.distance_to(head)>.01:return {}
	var toward:=Vector3(anchor.x-head.x,0,anchor.z-head.z)
	if toward.length()<.001:toward=Vector3.FORWARD
	toward=toward.normalized()
	var directions:Array[Vector3]=[toward]
	# Heading samples are relative to the hand, so rotated/non-grid surfaces
	# receive the same coverage. Search each radius before going farther away.
	for step in range(1,17):
		var angle:=float(step)*PI/16.0
		directions.append(toward.rotated(Vector3.UP,angle))
		if step<16:directions.append(toward.rotated(Vector3.UP,-angle))
	var space:=body.get_world_3d().direct_space_state
	for reach in [.0125,.025,.0375,.05,.0625,.075,.0875,.1,.112,.115]:
		for direction:Vector3 in directions:
			var inward:=direction*minf(float(reach)+.003,GRAZING_REACH)
			var point:=head+inward
			var hit:=_grazing_top(space,body,head,point)
			if hit.is_empty():continue
			var lift:=Vector3.UP*maxf(.006,hit.position.y-head.y+.006)
			var raised:=body.global_transform
			if body.test_move(raised,lift):continue
			raised.origin+=lift
			if body.test_move(raised,inward):continue
			var standing:=raised
			standing.origin+=inward
			var rise:float=hit.position.y-standing.origin.y
			if rise<.02 or body.test_move(standing,Vector3.UP*rise):continue
			return {"lift":lift,"inward":inward,"top":hit.position,"collider":hit.collider}
	return {}

static func _grazing_top(space:PhysicsDirectSpaceState3D,body:CharacterBody3D,head:Vector3,point:Vector3)->Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.018,point-Vector3.UP*.08,body.collision_mask,[body.get_rid()])
	var hit:=space.intersect_ray(query)
	if hit.is_empty() or hit.normal.y<cos(body.floor_max_angle):return {}
	if hit.position.y>head.y+GRAZING_TOP_ABOVE or head.y-hit.position.y>GRAZING_TOP_BELOW:return {}
	return hit

# Retained capsule planner for old standalone fixtures. Production release
# uses recover_grazing above with the player's actual goggle collision shape.
static func plan(body: CharacterBody3D, body_shape: CollisionShape3D, head: Vector3, anchor: Vector3, direction: Vector3) -> Dictionary:
	if not head.is_finite() or not anchor.is_finite() or not direction.is_finite(): return {}
	if not body_shape.shape is CapsuleShape3D: return {}
	var forward:=Vector3(direction.x,0,direction.z).normalized()
	if forward.length_squared()<.5: return {}
	var feet:=body.global_position
	if Vector2(head.x-feet.x,head.z-feet.z).length()>1.0: return {}
	var space:=body.get_world_3d().direct_space_state
	var capsule:=CapsuleShape3D.new()
	capsule.radius=(body_shape.shape as CapsuleShape3D).radius
	capsule.height=maxf(1.65,(body_shape.shape as CapsuleShape3D).height)
	# The released contact must still be local; stale/remote grabs cannot teleport.
	if anchor.distance_to(head)>1.25: return {}
	for distance in [.55,.7,.85]:
		var ahead:Vector3=feet+forward*distance
		var ray:=PhysicsRayQueryParameters3D.create(Vector3(ahead.x,head.y+.04,ahead.z),Vector3(ahead.x,feet.y+.08,ahead.z),1,[body.get_rid()])
		var hit:=space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<.85: continue
		var top:Vector3=hit.position
		var rise:=top.y-feet.y+.045
		# The tracked head, not the capsule's feet, decides whether this is a
		# reachable lip. The top must be a full foot below the HMD.
		if rise<.12 or rise>1.8 or head.y-top.y<.3048: continue
		if absf(anchor.y-top.y)>.85: continue
		var supported:=true
		# Reject edges and narrow rails before committing a standing destination.
		for offset in [Vector3.ZERO,Vector3.RIGHT*capsule.radius,Vector3.LEFT*capsule.radius,Vector3.FORWARD*capsule.radius,Vector3.BACK*capsule.radius]:
			var point:Vector3=top+offset
			var support:=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.08,point-Vector3.UP*.1,1,[body.get_rid()]))
			if support.is_empty() or support.normal.y<.85 or absf(support.position.y-top.y)>.07:
				supported=false
				break
		if not supported: continue
		var target:=Vector3(ahead.x,feet.y+rise,ahead.z)
		# Separate an existing floor contact by 6 mm for the clearance query;
		# the real body's upward sweep below still validates the actual motion.
		var head_shape:=SphereShape3D.new()
		head_shape.radius=.10
		# A flush wall can block a straight vertical capsule sweep. Step back
		# just enough to lift clear, then cross the lip onto the supported top.
		for setback in [0.0, .2, .4, .6]:
			var outward:Vector3=-forward*setback
			var lift:=Vector3.UP*rise
			var raised:=feet+outward+lift
			var inward:=target-raised
			var upright:=Transform3D(Basis.IDENTITY,feet+Vector3.UP*(capsule.height*.5+.006))
			if not _shape_clear(space,capsule,upright,outward,body): continue
			upright.origin+=outward
			if not _shape_clear(space,capsule,upright,lift,body): continue
			upright.origin+=lift
			if not _shape_clear(space,capsule,upright,inward,body): continue
			upright.origin+=inward
			if not _shape_clear(space,capsule,upright,Vector3.ZERO,body): continue
			if not _shape_clear(space,head_shape,Transform3D(Basis.IDENTITY,head),outward,body): continue
			if not _shape_clear(space,head_shape,Transform3D(Basis.IDENTITY,head+outward),lift,body): continue
			if not _shape_clear(space,head_shape,Transform3D(Basis.IDENTITY,head+outward+lift),inward,body): continue
			# Validate the actual body shape as well as the standing capsule.
			if body.test_move(body.global_transform,outward): continue
			var backed:=body.global_transform
			backed.origin+=outward
			if body.test_move(backed,lift): continue
			backed.origin+=lift
			if body.test_move(backed,inward): continue
			return {"outward":feet+outward,"raised":raised,"target":target}
	return {}

static func head_motion_clear(body:CharacterBody3D,head:Vector3,motion:Vector3)->bool:
	if not head.is_finite() or not motion.is_finite():return false
	var sphere:=SphereShape3D.new()
	sphere.radius=.10
	return _shape_clear(body.get_world_3d().direct_space_state,sphere,Transform3D(Basis.IDENTITY,head),motion,body)

static func _shape_clear(space:PhysicsDirectSpaceState3D,shape:Shape3D,transform:Transform3D,motion:Vector3,body:CharacterBody3D)->bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.transform=transform
	query.collision_mask=body.collision_mask
	query.exclude=[body.get_rid()]
	query.margin=.002
	if not space.intersect_shape(query,1).is_empty(): return false
	if motion.length_squared()<.000001: return true
	query.motion=motion
	var fractions:=space.cast_motion(query)
	return fractions.size()==2 and fractions[0]>.9999
