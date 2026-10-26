extends RefCounted
## Al's 062 unit correction: each reported metre was two feet (0.6096 m).
## Level aim lands twelve 2.4384 m builds away on the player's flat foot plane.
## True SI gravity and supplied physical hand height are not scaled again.
const FLAT_RANGE:=29.2608 * preload("res://scripts/measurement_calibration.gd").FACTOR # 12 * (4 reported units * 0.6096 m/unit).
const AIM_ELEVATION:=PI*.25
const COLLISION_RADIUS:=.035

static func launch_velocity(aim:Vector3,hand_height:float,gravity:float,right:Vector3=Vector3.RIGHT)->Vector3:
	if not aim.is_finite() or aim.length_squared()<.000001 or not is_finite(hand_height) or not is_finite(gravity) or gravity<=0:return Vector3.ZERO
	var forward:=aim.normalized()
	var axis:=forward.cross(Vector3.UP)
	# At vertical aim, use the held grenade's right axis to keep the direction
	# well-defined. Else world-up elevation is independent of controller roll.
	if axis.length_squared()<.000001:axis=right-forward*right.dot(forward)
	if not axis.is_finite() or axis.length_squared()<.000001:axis=Vector3.RIGHT
	var direction:=forward.rotated(axis.normalized(),AIM_ELEVATION).normalized()
	var height:=maxf(0.0,hand_height-COLLISION_RADIUS)
	var speed:=sqrt(gravity*FLAT_RANGE*FLAT_RANGE/(FLAT_RANGE+height))
	var velocity:=direction*speed
	# The small height advantage makes the maximum-range angle slightly lower
	# than 45 degrees. Cap that sliver too, without stretching steep/low throws.
	var horizontal:=Vector2(velocity.x,velocity.z).length()
	var flight:=(velocity.y+sqrt(velocity.y*velocity.y+2.0*gravity*height))/gravity
	if horizontal*flight>FLAT_RANGE and horizontal>.000001:
		var slope:=direction.y/Vector2(direction.x,direction.z).length()
		var flat_speed:=sqrt(gravity*FLAT_RANGE*FLAT_RANGE/(2.0*(height+FLAT_RANGE*slope)))
		velocity=direction*(flat_speed/Vector2(direction.x,direction.z).length())
	return velocity
