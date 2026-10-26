extends RefCounted
## Pure spatial pointer state. Caller supplies corrected rays and visible targets.
var _hands: Dictionary = {}
var captured_hand := ""
var captured_index := -1
var _capture_rect := Rect2()

func reset() -> void:
	_hands.clear()
	captured_hand = ""
	captured_index = -1

func step(hand_id: String, ray_origin: Vector3, ray_direction: Vector3, trigger: float, valid: bool, panel_transform: Transform3D, targets: Array) -> Dictionary:
	var result := {"hovered":-1, "index":-1, "value":-1.0, "pressed":false, "dragging":false, "released":false, "point":Vector3.ZERO, "hit":false}
	var state: Dictionary = _hands.get(hand_id, {"armed":false, "down":true})
	if not valid or not ray_origin.is_finite() or not ray_direction.is_finite() or not is_finite(trigger):
		state.armed = false
		state.down = true
		_hands[hand_id] = state
		if captured_hand == hand_id:
			result.released = true
			captured_hand = ""
			captured_index = -1
		return result
	var inverse := panel_transform.affine_inverse()
	var origin := inverse * ray_origin
	var direction := inverse.basis * ray_direction
	if absf(direction.z) > 0.00001:
		var distance := (0.02 - origin.z) / direction.z
		if distance > 0.0:
			result.point = origin + direction * distance
			result.hit = true
			for target in targets:
				var rect: Rect2 = target.rect
				if rect.has_point(Vector2(result.point.x, result.point.y)):
					result.hovered = int(target.id)
					break
	if not state.armed:
		if trigger <= 0.2:
			state.armed = true
			state.down = false
		_hands[hand_id] = state
		return result
	var down: bool = trigger > (0.35 if state.down else 0.55)
	var pressed: bool = down and not state.down
	state.down = down
	_hands[hand_id] = state
	if captured_hand == hand_id:
		var still_exists := false
		for target in targets:
			if int(target.id) == captured_index and bool(target.slider): still_exists = true
		if not down or not still_exists:
			result.released = true
			captured_hand = ""
			captured_index = -1
			return result
		result.index = captured_index
		result.dragging = true
		if result.hit: result.value = clampf((result.point.x - _capture_rect.position.x) / maxf(_capture_rect.size.x, 0.0001), 0, 1)
		return result
	if not captured_hand.is_empty() or not pressed or result.hovered < 0: return result
	result.pressed = true
	result.index = result.hovered
	for target in targets:
		if int(target.id) != result.index: continue
		if bool(target.slider):
			captured_hand = hand_id
			captured_index = result.index
			_capture_rect = target.rect
			result.dragging = true
			result.value = clampf((result.point.x - _capture_rect.position.x) / maxf(_capture_rect.size.x, 0.0001), 0, 1)
		break
	return result
