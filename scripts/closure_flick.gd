extends RefCounted
## Original recognition tolerances; no claim of measured reference thresholds.
var history:Array[Dictionary]=[]
var clock:=0.0
var neutral:=0.0
var armed:=false
func reset()->void:
	history.clear();neutral=0;armed=false
func sample(point:Vector3,forward:Vector3,axis:Vector3,delta:float,valid:bool,trigger:bool,up:Vector3=Vector3.ZERO)->bool:
	if not valid or not point.is_finite() or not forward.is_finite() or not up.is_finite() or delta<=0 or delta>.15:
		reset();return false
	clock+=delta
	var last:Dictionary=history.back() if not history.is_empty() else {}
	if not last.is_empty() and point.distance_to(last.point)>.7:reset();return false
	var speed:=point.distance_to(last.point)/delta if not last.is_empty() else 0.0
	var angular:=forward.angle_to(last.forward)/delta if not last.is_empty() else 0.0
	if not last.is_empty() and up.length_squared()>.5 and last.get("up",Vector3.ZERO).length_squared()>.5:angular=maxf(angular,up.angle_to(last.up)/delta)
	if not trigger and speed<.35 and angular<1.2:
		neutral+=delta
		if neutral>=.035:armed=true
	else:neutral=0
	while not history.is_empty() and clock-float(history[0].time)>.22:history.pop_front()
	if armed and not trigger and not history.is_empty():
		var first:Dictionary=history[0]
		var elapsed:=maxf(.001,clock-float(first.time))
		var travel:float=(point-first.point).dot(axis)
		var pitch:float=(forward-first.forward).dot(axis)
		var roll:float=(up-first.up).dot(axis) if up.length_squared()>.5 and first.up.length_squared()>.5 else 0.0
		var displacement:Vector3=point-first.point
		var lateral:float=(displacement-axis*travel).length()
		if (travel>=.045 and travel/elapsed>=.32 and travel>lateral*.65) or (pitch>=.28 and pitch/elapsed>=1.4) or (roll>=.28 and roll/elapsed>=1.4):
			reset();return true
	history.append({"point":point,"forward":forward,"up":up,"time":clock})
	return false
