extends Node3D
## Authored ground corridors. No player reference, perception or attack authority.
## Geometry anchors follow world.gd's existing stair/landing construction.
var _graph := AStar3D.new()
var _static_edges: Dictionary = {}
var _pending: Array[Dictionary] = []
var last_query_usec := 0
var completed_queries := 0
class Traversal extends RefCounted:
	var points := PackedVector3Array()
	var destination := Vector3.ZERO
	var index := 0
	var elapsed := 0.0
	var budget := 0.0
	var stalled := 0.0
	var best_distance := INF
	var finished := false
	var aborted := false
	var abort_reason := ""
	var pending := false

	func direction(position: Vector3, delta: float) -> Vector3:
		if finished or aborted: return Vector3.ZERO
		if pending: return Vector3.ZERO
		elapsed += delta
		if elapsed > budget:
			aborted = true
			abort_reason = "time_budget"
			return Vector3.ZERO
		while index < points.size():
			var flat := Vector3(points[index].x - position.x, 0, points[index].z - position.z)
			if flat.length() < 0.23 and absf(points[index].y - position.y) < 0.55:
				index += 1
				best_distance = INF
				stalled = 0.0
				continue
			var distance := position.distance_to(points[index])
			if distance < best_distance - 0.05:
				best_distance = distance
				stalled = 0.0
			else:
				stalled += delta
			if stalled > 3.0:
				aborted = true
				abort_reason = "blocked"
				return Vector3.ZERO
			return flat.normalized()
		finished = true
		return Vector3.ZERO
var _anchors := PackedVector3Array([
	Vector3(-29, 0, -27.5), Vector3(-29, 4, -41.5),
	Vector3(-29, 4, -43.7), Vector3(-25.65, 4, -43.7),
	Vector3(-25.65, 8, -31.5), Vector3(-20.7, 8, -30.4),
	Vector3(-20.7, 8, -38), Vector3(-18, 8, -38), Vector3(-18, 8, -43),
	Vector3(-11.4, 8, -43), Vector3(-11.4, 8, -47),
	Vector3(6, 8, -47), Vector3(6, 12, -60.5),
	Vector3(6, 12, -62.7), Vector3(2.5, 12, -62.7),
	Vector3(2.5, 16, -50.0), Vector3(8, 16, -50.0),
	Vector3(8, 16, -62), Vector3(15, 16, -69),
	# Side corridors around the summit equipment house; no path across its solid footprint.
	Vector3(20.5, 16, -71), Vector3(20.5, 16, -76),
	Vector3(9.5, 16, -71), Vector3(9.5, 16, -76)
])

func _ready() -> void:
	for index in range(_anchors.size()): _graph.add_point(index, _anchors[index])
	for index in range(18): _graph.connect_points(index, index + 1)
	for pair in [[18, 19], [19, 20], [18, 21], [21, 22]]:
		_graph.connect_points(pair[0], pair[1])

func invalidate_static_cache() -> void:
	_static_edges.clear()

func register_corridor(points: PackedVector3Array) -> bool:
	# Call after add_child. Registration supplies explicit author-approved links only;
	# physical support/clearance is still checked when a route is requested.
	# Exact nearby endpoints weld branches; mere spatial proximity never adds edges.
	if _graph.get_point_count() == 0 or points.size() < 2 or points.size() > 64: return false
	var proposed := _anchors.duplicate()
	var ids: Array[int] = []
	var has_link := false
	for index in range(points.size()):
		var point := points[index]
		if not point.is_finite() or point.length() > 4096.0: return false
		if index > 0 and point.distance_to(points[index - 1]) > 40.0: return false
		var id := -1
		for candidate in range(proposed.size()):
			if proposed[candidate].distance_squared_to(point) <= 0.01:
				id = candidate
				break
		if id < 0:
			if proposed.size() >= 256: return false
			id = proposed.size()
			proposed.append(point)
		if not ids.is_empty() and ids.back() != id: has_link = true
		ids.append(id)
	if not has_link: return false
	# Mutate only after the entire bounded request has validated.
	for index in range(_anchors.size(), proposed.size()): _graph.add_point(index, proposed[index])
	_anchors = proposed
	for index in range(ids.size() - 1):
		if ids[index] != ids[index + 1]: _graph.connect_points(ids[index], ids[index + 1])
	invalidate_static_cache()
	return true

func request_route(requester: Node, from: Vector3, destination: Vector3, speed: float, difficulty: float) -> Traversal:
	var traversal := Traversal.new()
	traversal.destination = destination
	traversal.pending = true
	# Replace obsolete requests by the same guard; never retain the guard itself.
	for index in range(_pending.size() - 1, -1, -1):
		if _pending[index].owner.get_ref() == requester:
			_pending[index].traversal.aborted = true
			_pending[index].traversal.abort_reason = "superseded"
			_pending.remove_at(index)
	if _pending.size() >= 32:
		traversal.pending = false
		traversal.aborted = true
		traversal.abort_reason = "queue_full"
		return traversal
	_pending.append({"owner": weakref(requester), "from": from, "destination": destination, "speed": speed, "difficulty": difficulty, "traversal": traversal})
	return traversal

func _physics_process(_delta: float) -> void:
	last_query_usec = 0
	while not _pending.is_empty():
		var request: Dictionary = _pending.pop_front()
		var owner: Node = request.owner.get_ref()
		if not is_instance_valid(owner) or owner.is_queued_for_deletion() or request.traversal.aborted: continue
		var before := Time.get_ticks_usec()
		var computed := begin_route(request.from, request.destination, request.speed, request.difficulty)
		var traversal: Traversal = request.traversal
		traversal.points = computed.points
		traversal.budget = computed.budget
		traversal.aborted = computed.aborted
		traversal.abort_reason = computed.abort_reason
		traversal.pending = false
		last_query_usec = Time.get_ticks_usec() - before
		completed_queries += 1
		break # Shared hard count budget: at most one route query per physics frame.

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func walkable_segment(from: Vector3, to: Vector3) -> bool:
	# Centre support plus chest clearance; collision steering enforces capsule width.
	# No point snapping to a different floor through a roof or tower wall.
	var samples := maxi(2, int(ceil(from.distance_to(to) / 0.45)))
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var side := flat.normalized().cross(Vector3.UP) * 0.58
	# Summit equipment corners need heavy-capsule clearance. Older authored stair
	# corridors are validated by actual traversal; side rays can hit sloped end caps.
	var offsets := [Vector3.ZERO, side, -side] if from.y > 15.0 and to.y > 15.0 else [Vector3.ZERO]
	for sample_index in range(samples + 1):
		var point := from.lerp(to, float(sample_index) / samples)
		for offset in [Vector3.ZERO]:
			var floor_hit := _ray(point + offset + Vector3.UP * 0.65, point + offset - Vector3.UP * 0.7)
			# Tiny angled end caps at ramp/landing joins are stepable; reject vertical sides.
			if floor_hit.is_empty() or floor_hit.normal.y < 0.25:
				return false
			if absf(floor_hit.position.y - point.y) > 0.6:
				return false
		if sample_index > 0:
			var previous := from.lerp(to, float(sample_index - 1) / samples)
			for height in [0.7, 1.4]:
				for offset in offsets:
					if not _ray(previous + offset + Vector3.UP * height, point + offset + Vector3.UP * height).is_empty():
						return false
	return true

func route(from: Vector3, remembered_destination: Vector3) -> PackedVector3Array:
	if _graph.get_point_count() == 0: return PackedVector3Array()
	# Gunshot reports can be at muzzle height. Project onto nearby support only;
	# never through a floor or from an unsupported ledge onto a distant lower storey.
	var support := _ray(remembered_destination + Vector3.UP * 0.25, remembered_destination - Vector3.UP * 2.2)
	if support.is_empty() or support.normal.y < 0.25: return PackedVector3Array()
	remembered_destination = support.position
	if absf(from.y - remembered_destination.y) < 0.7 and walkable_segment(from, remembered_destination):
		return PackedVector3Array([remembered_destination])
	var starts: Array[int] = []
	var ends: Array[int] = []
	var start_candidates: Array[Dictionary] = []
	var end_candidates: Array[Dictionary] = []
	for index in range(_anchors.size()):
		var anchor := _anchors[index]
		if absf(anchor.y - from.y) < 0.8 and anchor.distance_to(from) < 22.0: start_candidates.append({"index": index, "distance": anchor.distance_to(from)})
		if absf(anchor.y - remembered_destination.y) < 0.8 and anchor.distance_to(remembered_destination) < 22.0: end_candidates.append({"index": index, "distance": anchor.distance_to(remembered_destination)})
	start_candidates.sort_custom(func(a, b): return a.distance < b.distance)
	end_candidates.sort_custom(func(a, b): return a.distance < b.distance)
	# Three fresh, nearest usable attachments suffice for this connected authored graph.
	# Do not ray-test every far corner of a roof for each queued guard.
	for candidate in start_candidates:
		if walkable_segment(from, _anchors[candidate.index]): starts.append(candidate.index)
		if starts.size() >= 3: break
	for candidate in end_candidates:
		if walkable_segment(_anchors[candidate.index], remembered_destination): ends.append(candidate.index)
		if ends.size() >= 3: break
	var result := PackedVector3Array()
	var best := INF
	for start in starts:
		for end in ends:
			var candidate := _graph.get_point_path(start, end)
			if candidate.is_empty(): continue
			var length := from.distance_to(candidate[0]) + candidate[-1].distance_to(remembered_destination)
			for index in range(candidate.size() - 1): length += candidate[index].distance_to(candidate[index + 1])
			if length >= best: continue
			var valid := true
			for index in range(candidate.size() - 1):
				var edge_key := "%s:%s" % [candidate[index], candidate[index + 1]]
				# Only authored, immutable corridor edges persist between requests.
				# Endpoint attachments above always query current physics; local steering
				# and three-second stall abort still handle newly introduced blockers.
				if not _static_edges.has(edge_key): _static_edges[edge_key] = walkable_segment(candidate[index], candidate[index + 1])
				if not _static_edges[edge_key]:
					valid = false
					break
			if valid:
				best = length
				result = candidate
	if not result.is_empty(): result.append(remembered_destination)
	return result

static func length_of(from: Vector3, points: PackedVector3Array) -> float:
	var length := 0.0
	for point in points:
		length += from.distance_to(point)
		from = point
	return length

func begin_route(from: Vector3, remembered_destination: Vector3, speed: float, difficulty: float) -> Traversal:
	var traversal := Traversal.new()
	traversal.points = route(from, remembered_destination)
	traversal.destination = remembered_destination
	traversal.budget = minf(length_of(from, traversal.points) / maxf(speed, 0.5) + 5.0, lerpf(28.0, 55.0, clampf(difficulty, 0, 1)))
	if traversal.points.is_empty():
		traversal.aborted = true
		traversal.abort_reason = "no_supported_route"
	return traversal





