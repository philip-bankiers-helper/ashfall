extends RefCounted
## One world lattice. All panels are faces of the same cells, including negatives.
static func intersections(origin:Vector3,direction:Vector3,grid_origin:Vector3,side:float,minimum:float,maximum:float)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if side<=0 or not origin.is_finite() or not direction.is_finite() or direction.length_squared()<.001:return result
	var ray:=direction.normalized()
	for axis in 3:
		if absf(ray[axis])<.000001:continue
		var first:=floori((origin[axis]+ray[axis]*minimum-grid_origin[axis])/side)-1
		var last:=ceili((origin[axis]+ray[axis]*maximum-grid_origin[axis])/side)+1
		for plane in range(mini(first,last)-1,maxi(first,last)+2):
			var depth:=grid_origin[axis]+plane*side
			var distance:float=(depth-origin[axis])/ray[axis]
			if distance<minimum-.00001 or distance>maximum+.00001:continue
			var point:=origin+ray*distance
			var center:=grid_origin
			for component in 3:
				center[component]+=(floorf((point[component]-grid_origin[component])/side+ray[component]*.000001)+.5)*side
			center[axis]=depth
			var basis:=Basis(Vector3.UP,PI*.5) if axis==0 else Basis.IDENTITY
			var kind:="floor" if axis==1 else "wall"
			result.append({"kind":kind,"axis":axis,"at":Transform3D(basis,center),"base_y":center.y if axis==1 else center.y-side*.5,"distance":distance})
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		if absf(a.distance-b.distance)<.00001:return int(a.axis)<int(b.axis)
		return float(a.distance)<float(b.distance))
	return result
