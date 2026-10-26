extends RefCounted
## 091 signed pulse timing: native-PTS video review and explicit authored fallbacks.
## See assets/data/reticle_motion_091.json for evidence, confidence and unchanged peak policy.
const PROFILES:Dictionary={
	"dt11":{"peak_deg":17.6,"peak_s":.11,"zero_s":.235,"under_s":.31,"end_s":.48,"under":.18},
	"fal":{"peak_deg":6.05,"peak_s":.125,"zero_s":.270,"under_s":.333,"end_s":.51,"under":.16},
	"1911":{"peak_deg":6.05,"peak_s":.097,"zero_s":.205,"under_s":.264,"end_s":.43,"under":.28},
	"px4":{"peak_deg":6.655,"peak_s":.097,"zero_s":.226,"under_s":.278,"end_s":.45,"under":.18},
	"magnum":{"peak_deg":8.47,"peak_s":.09,"zero_s":.24,"under_s":.31,"end_s":.50,"under":.18},
	"matadors":{"peak_deg":7.7,"peak_s":.09,"zero_s":.21,"under_s":.28,"end_s":.43,"under":.18},
	"spr":{"peak_deg":6.776,"peak_s":.09,"zero_s":.22,"under_s":.33,"end_s":.48,"under":.30}
}
static func profile(weapon:Node3D)->Dictionary:
	return PROFILES.get(str(weapon.get_meta("reference_id","")),{})
static func presentation_pose(weapon:Node3D,ballistic_pose:Transform3D,pitch:float)->Transform3D:
	if profile(weapon).is_empty() or weapon.model==null:return ballistic_pose
	# Recover the model-local muzzle frame before removing placement recoil.
	# 072 publishes this pose to both UI and firing. The underlying model
	# animation remains separate; no second visual-only ray is displayed.
	var local_muzzle:Transform3D=weapon.model.global_transform.affine_inverse()*ballistic_pose
	if not weapon.model.scale.is_equal_approx(Vector3.ONE):
		local_muzzle.origin*=weapon.model.scale;local_muzzle.basis=local_muzzle.basis.orthonormalized()
	var rest_origin:Vector3=weapon.to_global(Vector3(weapon.model.position.x,weapon.model.position.y,0))
	var neutral:=Transform3D(weapon.global_basis,rest_origin)*local_muzzle
	return upright_pulse(neutral,pitch)
static func upright_pulse(neutral:Transform3D,pitch:float)->Transform3D:
	var forward:Vector3=-neutral.basis.z.normalized()
	# Project world-up onto the aim plane: weapon roll must never turn this
	# presentation pulse sideways. Stop at the upper pole rather than flipping
	# azimuth beyond it. At either exact pole use projected world-right, never
	# weapon-right, so the otherwise undefined axis is deterministic.
	var axis:=forward.cross(Vector3.UP)
	if axis.length_squared()<.00000001:
		axis=Vector3.RIGHT-forward*forward.dot(Vector3.RIGHT)
	axis=axis.normalized()
	var rise:=clampf(pitch,-acos(clampf(forward.dot(Vector3.DOWN),-1.0,1.0)),acos(clampf(forward.dot(Vector3.UP),-1.0,1.0)))
	# Keep the neutral muzzle origin fixed: rotating its offset around a rolled
	# model would reintroduce lateral parallax even with the correct ray axis.
	return Transform3D(Basis(axis,rise)*neutral.basis,neutral.origin)

static func pulse(seconds:float,p:Dictionary)->float:
	if seconds<=0 or seconds>=float(p.end_s):return 0.0
	var times:=[0.0,float(p.peak_s),float(p.zero_s),float(p.under_s),float(p.end_s)]
	var values:=[0.0,1.0,0.0,-float(p.under),0.0]
	var down_a:float=-1.0/(times[2]-times[1]);var down_b:float=-float(p.under)/(times[3]-times[2])
	var middle:float=2.0*down_a*down_b/(down_a+down_b)
	var slopes:=[1.8/times[1],0.0,middle,0.0,0.0]
	for i in 4:
		if seconds<=times[i+1]:
			var span:float=times[i+1]-times[i];var u:float=(seconds-times[i])/span
			return (2*u*u*u-3*u*u+1)*values[i]+(u*u*u-2*u*u+u)*span*slopes[i]+(-2*u*u*u+3*u*u)*values[i+1]+(u*u*u-u*u)*span*slopes[i+1]
	return 0.0
