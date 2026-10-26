extends RefCounted
## Preserve view direction while removing headset roll. No tracked pose is edited.
static func view_basis(view:Basis)->Basis:
	var z:=view.z.normalized()
	var x:=Vector3.UP.cross(z)
	# At a vertical view direction world-up has no screen projection. Pick a
	# deterministic world axis, rather than reintroducing the headset's roll.
	if x.length_squared()<0.000001:x=Vector3.RIGHT
	else:x=x.normalized()
	return Basis(x,z.cross(x).normalized(),z).orthonormalized()
