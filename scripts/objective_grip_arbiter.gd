extends RefCounted
## One fresh grip gesture claims an objective, never a held/recovered input.
var _down:Dictionary={}
var _claimed:Dictionary={}
const REACH:=.35
func reset(keep_claims:bool=false)->void:
	_down.clear()
	if not keep_claims:_claimed.clear()
func is_reserved(hand:Node3D)->bool:
	return bool(_claimed.get(hand,false))
func step(samples:Array,targets:Array,space:PhysicsDirectSpaceState3D,exclude:Array)->Dictionary:
	var excluded:Array[RID]=[]
	excluded.assign(exclude)
	var best:Dictionary={}
	var best_distance:=INF
	for sample in samples:
		var hand:Node3D=sample.hand
		if not bool(sample.ready):
			_down[hand]=true
			_claimed.erase(hand)
			continue
		var grip:float=sample.grip
		if grip<=.2:
			_down[hand]=false
			_claimed.erase(hand)
			continue
		if grip<.65 or bool(_down.get(hand,true)):continue
		_down[hand]=true
		if bool(sample.get("blocked",false)):continue
		var origin:Vector3=sample.position
		if not origin.is_finite():continue
		if sample.get("reference") is Vector3:
			var reach_ray:=PhysicsRayQueryParameters3D.create(sample.reference,origin,1,excluded)
			reach_ray.hit_from_inside=true
			if not space.intersect_ray(reach_ray).is_empty():continue
		for target in targets:
			if not target is Dictionary or not target.has("id") or not target.get("position") is Vector3:continue
			if target.has("hand") and target.hand!=hand:continue
			var point:Vector3=target.position
			if not point.is_finite():continue
			var distance:=origin.distance_to(point)
			var reach:=minf(2.0,float(target.get("reach",REACH))) if str(target.id).begins_with("inventory_pickup:") or str(target.id).begins_with("consumable:pickup:") or str(target.id).begins_with("supply:") else REACH
			if distance>reach:continue
			var ray:=PhysicsRayQueryParameters3D.create(origin,point,1,excluded)
			ray.hit_from_inside=true
			var hit:=space.intersect_ray(ray)
			# Targets should be on the exposed interaction face. Only tolerate
			# endpoint contact, never a wall between hand and control.
			if not hit.is_empty() and hit.position.distance_to(point)>.012:continue
			_claimed[hand]=true
			if distance<best_distance:
				best_distance=distance
				best={"id":str(target.id),"hand":hand}
	return best
