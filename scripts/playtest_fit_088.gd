extends RefCounted
## Rendered hand calibration only. Tracked controllers, bore and recoil remain authoritative.
const BACKWARD_IDS=["px4","magnum","m1014","dt11","awp","p90","katana","excalibur","cyberblade"]
const LEAN_IDS=["matadors","dt11","s85"]
static func hand_offset(weapon:Node3D)->Vector3:
	var id:=str(weapon.get_meta("reference_id",""))
	if weapon.has_method("sample_motion"):id=str(weapon.archetype)
	var offset:=Vector3(0,0,.0381) if id in BACKWARD_IDS else Vector3.ZERO
	if id=="magnum":offset.z+=.01905
	elif id=="s85":offset+=Vector3.BACK*.127
	elif id=="dt11":offset+=hand_basis(weapon)*Vector3.UP*.127
	elif id=="matadors":offset+=hand_basis(weapon)*Vector3.DOWN*.1016
	elif id=="knife":offset+=Vector3.BACK*.0508 # Knife forward relative to the rendered hand
	if id=="mp5":offset.y=-.0635
	elif id=="1911":offset.y=-.0254
	elif id=="smaw":offset=Vector3(0,.0254,.0508) #093 hand back another inch
	# 090 headset corrections are deltas from the preserved 089 fit.
	if id=="matadors":offset.y+=.1524
	elif id=="s85":offset+=Vector3(0,.0762,-.0762) # 0991: hand up one inch, forward three inches from099
	elif id=="dt11":offset.z-=.0254
	elif id=="m1014":offset.y+=.0381 #093 hand up another half inch
	elif id=="mp9":offset.z-=.01905
	elif id=="mk18":offset.y-=.0127
	elif id=="m60":offset.z+=.0254
	if id in ["uzi","uzis","mk18","m60","akm"]:offset.z+=.0127 #094 explicit half-inch backward delta
	# Desired inches are physical, independent of each weapon's display size.
	return offset/weapon.model.global_basis.get_scale().x
static func hand_basis(weapon:Node3D)->Basis:
	return Basis(Vector3.RIGHT,deg_to_rad(-35.0)) if str(weapon.get_meta("reference_id","")) in LEAN_IDS else Basis.IDENTITY
static func hide_seated_clip(weapon:Node3D)->void:
	if weapon.profile_id=="s85":weapon.magazine.hide()
