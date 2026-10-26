extends RefCounted
## Finite, convex panel contacts. No center-distance or infinite-column support.
const CONTACT_TOLERANCE := 0.045
const MIN_EDGE_CONTACT := 0.25

static func vertices(kind:String, at:Transform3D, side:float)->PackedVector3Array:
	var half:=side*.5
	var points:=PackedVector3Array()
	if kind=="ramp":
		for x in [-half,half]:
			points.append(at*Vector3(x,0,-half));points.append(at*Vector3(x,0,half));points.append(at*Vector3(x,side,-half))
	else:
		var size:=Vector3(side,side,.08) if kind=="wall" else Vector3(side,.08,side)
		for x in [-.5,.5]:
			for y in [-.5,.5]:
				for z in [-.5,.5]:points.append(at*(size*Vector3(x,y,z)))
	return points

static func bounds(points:PackedVector3Array)->AABB:
	var box:=AABB(points[0],Vector3.ZERO)
	for point in points:box=box.expand(point)
	return box

static func connected(a:Dictionary,b:Dictionary,side:float)->bool:
	prepare(a,side);prepare(b,side)
	var ab:AABB=a._bounds;var bb:AABB=b._bounds
	if not ab.grow(CONTACT_TOLERANCE).intersects(bb.grow(CONTACT_TOLERANCE)):return false
	# A corner/point alone does not carry another panel; a shared edge does.
	var overlap:Vector3=(ab.end.min(bb.end)-ab.position.max(bb.position)).max(Vector3.ZERO)
	if maxf(overlap.x,maxf(overlap.y,overlap.z))<MIN_EDGE_CONTACT:return false
	var av:PackedVector3Array=a._vertices;var bv:PackedVector3Array=b._vertices
	var axes:Array[Vector3]=[];var ae:Array[Vector3]=[];var be:Array[Vector3]=[]
	for entry in [a,b]:
		var basis:Basis=entry.at.basis
		for axis in [basis.x,basis.y,basis.z]:axes.append(axis)
		if entry.kind=="ramp":axes.append((basis*Vector3(0,1,1)).normalized())
	for pair in [[a,ae],[b,be]]:
		var basis:Basis=pair[0].at.basis
		for edge in [basis.x,basis.y,basis.z]:pair[1].append(edge)
		if pair[0].kind=="ramp":pair[1].append((basis*Vector3(0,1,-1)).normalized())
	for edge_a in ae:
		for edge_b in be:
			var axis:=edge_a.cross(edge_b)
			if axis.length_squared()>.00001:axes.append(axis.normalized())
	for axis in axes:
		var amin:=INF;var amax:=-INF;var bmin:=INF;var bmax:=-INF
		for point in av:
			var d:=point.dot(axis);amin=minf(amin,d);amax=maxf(amax,d)
		for point in bv:
			var d:=point.dot(axis);bmin=minf(bmin,d);bmax=maxf(bmax,d)
		if amax<bmin-CONTACT_TOLERANCE or bmax<amin-CONTACT_TOLERANCE:return false
	return true

static func prepare(entry:Dictionary,side:float)->void:
	if entry.has("_vertices"):return
	entry._vertices=vertices(entry.kind,entry.at,side)
	entry._bounds=bounds(entry._vertices)
