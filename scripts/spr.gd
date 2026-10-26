extends "res://scripts/weapon.gd"
## Separate original SPR: semiautomatic, magazine UP then charging handle BACK.
var optic:Node3D
var _semi_armed:=true
func _build_model()->void:
	super._build_model()
	preload("res://scripts/long_gun_finish_064.gd").spr(self)
	if preload("res://scripts/downloaded_firearm_model.gd").available("spr"):preload("res://scripts/downloaded_firearm_model.gd").build(self,"spr")
func allows_world_reticle()->bool:return false
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop);magazine_size=10;ammo=10;damage=78;fire_interval=.32
	var old_hood:Node3D=model.find_child("SPROpenOpticHood064",true,false)
	if old_hood!=null:old_hood.hide()
	for part in model.find_children("*","VisualInstance3D",true,false):part.layers=1<<18
	optic=load("res://scripts/spr_scope.gd").new();model.add_child(optic);optic.setup(self)
	preload("res://scripts/downloaded_firearm_model.gd").replace_debris(self)
	# Gemini scope is authored directly in the accepted donor model coordinates.
	optic.scale=Vector3.ONE;optic.position=Vector3.ZERO
func fire()->void:
	if not _semi_armed:return
	var before:=ammo;super.fire()
	if ammo<before:_semi_armed=false
func _poll_vr()->void:
	if right_hand.get_float("trigger")<.2 and not right_hand.is_button_pressed("trigger_click"):_semi_armed=true
	super._poll_vr()
func _process(delta:float)->void:
	if not _vr_active() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):_semi_armed=true
	super._process(delta)
	if optic!=null:optic.refresh_optic(delta)
func get_scope_overlay_active()->bool:return optic!=null and optic.active
func get_displayed_optic_pose()->Dictionary:
	return optic.get_displayed_pose() if optic!=null else {"valid":false,"pose":Transform3D.IDENTITY}
func _suspend_gestures()->void:
	super._suspend_gestures()
	if optic!=null:optic.shutdown()
func shutdown()->void:
	if optic!=null:optic.shutdown()
	super.shutdown()

var _recovery_start:=0.0
func reset_weapon()->void:
	super.reset_weapon();_recovery_start=0
func _kick_recoil(distance:float,angle:float)->void:
	# Prior peak gain retained; signed cycle timing is documented in reticle_motion_091.json.
	super._kick_recoil(distance*1.1,angle*1.12)
	_recovery_start=recoil_pitch
func _recover_recoil(delta:float)->void:
	super._recover_recoil(delta)

func get_magazine_offer_point()->Vector3:
	return super.get_magazine_offer_point()+Vector3.UP*(.127/visual_model_scale())
