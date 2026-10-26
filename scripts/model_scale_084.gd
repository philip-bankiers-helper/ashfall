extends RefCounted
## User playtest visual calibration relative to083. World/physics/recoil angles are unchanged.
const FACTORS={"akm":.945,"awp":1.0,"fal":1.037875,"rfb":.8,"1911":.55,"tec9":.72,"px4":.7,"mp9":1.0,"mp5":.684,"magnum":.84,"p90":.72,"mk18":.92,"s85":1.12,"uzi":.65436,"matadors":.9,"cx4":.855,"dt11":1.6,"m1014":1.0,"m60":1.0,"spr":1.32}
static func apply(w:Node3D)->void:
	if preload("res://scripts/asset_quality.gd").lightweight():return
	var id:=str(w.get_meta("downloaded_model_077",""))
	if w.has_meta("imported_tactical_1911"):id="1911"
	if w.has_meta("downloaded_magnum_081"):id="magnum"
	if w.has_meta("downloaded_pair_084"):id=str(w.get_meta("downloaded_pair_084"))
	if id=="":
		var path:String=w.get_script().resource_path
		if path=="res://scripts/belt_lmg.gd":id="m60"
		elif path=="res://scripts/explosive_weapon.gd" and w.profile_id=="smaw":id="smaw"
	# No melee/consumable/player scaling, no double UMP scaling.
	var factor:float=1.6 if id=="smaw" else float(FACTORS.get(id,1.0))
	if factor==1.0:return
	w.model.scale*=factor;w.set_meta("visual_fit_scale_084",factor);w.set_meta("visual_fit_id_084",id)
