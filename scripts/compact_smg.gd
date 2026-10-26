extends "res://scripts/weapon.gd"
const RemainingFinish=preload("res://scripts/remaining_firearm_finish.gd")
const AggressorModel=preload("res://scripts/ump_aggressor_model.gd")
## Latch compact automatic: original geometry and balance, shared physical magazine contract.
## Magazine feed and separate charging handle are deliberately retained, not a cosmetic rifle rescale.
func setup(actor:Node3D, connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	magazine_size=32
	ammo=32
	damage=19.0
	fire_interval=0.075
	update_ammo_display()
func get_shot_transform()->Transform3D:
	if has_meta("download_muzzle_084"):return fitted_download_shot()
	return Transform3D(unit_model_basis(),model.to_global(Vector3(0,0.045,-0.46)))
func uses_aggressor_model()->bool:
	# P90 and paired Uzi/Matador subclasses retain their independent visuals.
	return get_script().resource_path=="res://scripts/compact_smg.gd" and not preload("res://scripts/asset_quality.gd").lightweight()
func get_magazine_insert_point()->Vector3:
	return AggressorModel.MAGAZINE_HOME*AggressorModel.DISPLAY_SCALE if uses_aggressor_model() else super.get_magazine_insert_point()
func get_magazine_offer_point()->Vector3:
	return (AggressorModel.MAGAZINE_HOME+Vector3(0,-.168,0))*AggressorModel.DISPLAY_SCALE if uses_aggressor_model() else super.get_magazine_offer_point()
func get_reload_zones()->Array:
	if uses_aggressor_model() and reload_state=="needs_rack":return [{"position":Vector3(-.05,.064,-.10)*AggressorModel.DISPLAY_SCALE,"radius":.18}]
	return super.get_reload_zones()
func _process(delta:float)->void:
	super._process(delta)
	if uses_aggressor_model() and is_instance_valid(guide):
		# Base input targets are gun-local; this cue lives inside the scaled model.
		guide.position=Vector3(-.05,.064,-.10) if reload_state=="needs_rack" else AggressorModel.MAGAZINE_HOME
func _update_support_visual()->void:
	super._update_support_visual()
	if uses_aggressor_model() and is_instance_valid(_attached_visual):
		# Shrink the weapon, not the player's supporting glove.
		_attached_visual.global_basis=_attached_visual.global_basis.orthonormalized()
func _build_model()->void:
	# Construction-only compatibility: PairedUzi retains its frozen063 finish.
	var uzi_visual_063:=bool(get_meta("_paired_uzi_visual_063",false))
	if uses_aggressor_model():
		AggressorModel.build(self);return
	model=Node3D.new()
	add_child(model)
	var steel:=_material(Color("515b5c"),0.75,0.36)
	var dark:=_material(Color("20282a"),0.35,0.62)
	var rubber:=_material(Color("343b37"),0.0,0.8)
	var recess:=_material(Color("080d0e"),0.1,0.85)
	var cyan:=_material(Color(0.05,0.72,0.75),0.2,0.4,0.65)
	_bolt_finish=steel
	_reload_finish=cyan
	# Tall compact receiver, short shroud and open twin-rail stock.
	_beveled(Vector3(0.066,0.096,0.27),Vector3(0,0.036,-0.10),steel,0.012)
	if uzi_visual_063:
		_beveled(Vector3(0.061,0.071,0.18),Vector3(0,0.035,-0.315),dark,0.009)
	_rod(Vector3(0,0.045,-0.39),Vector3(0,0.045,-0.455 if uzi_visual_063 else -0.450),0.012,steel)
	if uzi_visual_063:
		_rod(Vector3(0,0.045,-0.455),Vector3(0,0.045,-0.461),0.006,recess)
	for x in [-0.026,0.026]:
		_rod(Vector3(x,0.035,0.025),Vector3(x,0.035,0.16),0.005,steel)
	_beveled(Vector3(0.06,0.102,0.018),Vector3(0,-0.003,0.17),rubber,0.005)
	var grip_mesh:=_beveled(Vector3(0.043,0.11,0.052),Vector3(0,-0.078,0.005),rubber,0.007)
	grip_mesh.rotation.x=-0.18
	_rod(Vector3(0,-0.027,-0.02),Vector3(0,-0.064,-0.032),0.004,dark)
	_rod(Vector3(0,-0.064,-0.032),Vector3(0,-0.064,-0.09),0.004,dark)
	_rod(Vector3(0,-0.064,-0.09),Vector3(0,-0.025,-0.095),0.004,dark)
	_rod(Vector3(0,-0.029,-0.055),Vector3(0,-0.048,-0.05),0.0025,steel)
	# Actual offhand contact stays at canonical tracked foregrip point.
	_beveled(Vector3(0.05,0.032,0.10),Vector3(0,-0.014,-0.36),rubber,0.007)
	for i in range(5):
		_box(Vector3(0.052,0.003,0.005),Vector3(0,-0.03,-0.40+i*0.02),dark)
		if uzi_visual_063:
			for x in [-0.031,0.031]:
				_box(Vector3(0.002,0.016,0.016),Vector3(x,0.037,-0.38+i*0.03),recess)
	magazine=_beveled(Vector3(0.035,0.18,0.043),Vector3(0,-0.11,-0.15),dark,0.006)
	for x in [-0.018,0.018]:
		_box(Vector3(0.002,0.13,0.005),Vector3(x,-0.006,0),steel,magazine)
	loose_magazine=_beveled(Vector3(0.035,0.18,0.043),Vector3.ZERO,dark,0.006,self)
	loose_magazine.hide()
	_beveled(Vector3(0.047,0.025,0.056),Vector3(0,-0.022,-0.15),dark,0.005)
	bolt=_beveled(Vector3(0.032,0.012,0.022),Vector3(-0.045,0.064,-0.10),steel,0.003)
	_box(Vector3(0.002,0.012,0.085),Vector3(-0.034,0.064,-0.10),recess)
	_box(Vector3(0.002,0.024,0.063),Vector3(0.034,0.035,-0.10),recess)
	firing_carrier=_beveled(Vector3(0.002,0.016,0.048),Vector3(0.035,0.035,-0.10),steel,0.0005)
	var sights:=WeaponFinish.zeroed_sights(model,-0.03,-0.36,0.11,Vector3(0,0.045,-0.46),35.0,steel,steel)
	sight_rear=sights.find_child("RearReference",true,false)
	sight_front=sights.find_child("FrontReference",true,false)
	guide=_box(Vector3(0.013,0.013,0.013),INSERT_POINT,cyan)
	guide.hide()
	hip_source=Node3D.new()
	add_child(hip_source)
	_beveled(Vector3(0.035,0.18,0.043),Vector3.ZERO,dark,0.006,hip_source)
	hip_source.hide()
	insertion_arrow=Node3D.new()
	model.add_child(insertion_arrow)
	insertion_arrow.hide()
	charging_arrow=Node3D.new()
	model.add_child(charging_arrow)
	charging_arrow.hide()
	ammo_label=Label3D.new()
	ammo_label.font_size=28
	ammo_label.pixel_size=0.00065
	model.add_child(ammo_label)
	muzzle_flash=_rod(Vector3(0,0.045,-0.465),Vector3(0,0.045,-0.52),0.015,_material(Color(1,0.65,0.16),0,0.5,3),5)
	muzzle_flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_flash.hide()
	_merge_static_parts()
	_build_debris_pool()
	if not uzi_visual_063:RemainingFinish.compact(self)
