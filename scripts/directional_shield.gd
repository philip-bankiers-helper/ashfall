extends RefCounted
## Finite front-facing rectangular bullet intersection, matching the visible panel.
## Calling code must explicitly identify bullets; area/melee/environment never enter here.
static func intersect_bullet(origin:Vector3,endpoint:Vector3,plane:Transform3D,radii:Vector2)->Dictionary:
	if not origin.is_finite() or not endpoint.is_finite() or not plane.is_finite() or radii.x<=0 or radii.y<=0:return {}
	var normal:Vector3=-plane.basis.z.normalized()
	var ray:=endpoint-origin
	var divisor:=ray.dot(normal)
	if divisor>=-.00001:return {} # Rear/parallel shots do not strike the defensive face.
	var travel:float=(plane.origin-origin).dot(normal)/divisor
	if travel<0 or travel>1:return {}
	var point:=origin+ray*travel
	var local:Vector3=plane.affine_inverse()*point
	if absf(local.x)>radii.x or absf(local.y)>radii.y:return {}
	return {"position":point,"normal":normal,"fraction":travel}
