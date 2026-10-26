extends "res://scripts/weapon.gd"
const RemainingFinish=preload("res://scripts/remaining_firearm_finish.gd")
## Three-round mechanically committed burst, original timing and balance.
var post_burst_interval:=.24
var burst_remaining:=0
var _burst_armed:=true
func setup(actor:Node3D, connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop)
	magazine_size=27
	ammo=27
	damage=27.0
	fire_interval=0.080 #058 faster intra-burst tuning; not a measured reference value.
func _process(delta:float)->void:
	var held := right_hand.get_float("trigger")>0.65 or right_hand.is_button_pressed("trigger_click") if _vr_active() else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not held and burst_remaining==0:_burst_armed=true
	super._process(delta)
	if not _input_allowed() or not visible:
		burst_remaining=0
		return
	if burst_remaining>0 and cooldown<=0:
		_emit_burst_round()
func fire()->void:
	if burst_remaining>0 or not _burst_armed or cooldown>0 or reload_state!="ready" or not _input_allowed():return
	_burst_armed=false
	burst_remaining=mini(3,ammo)
	_emit_burst_round()
func _emit_burst_round()->void:
	var before:=ammo
	super.fire()
	if ammo<before:
		burst_remaining-=1
		if burst_remaining==0:cooldown=post_burst_interval
	else:burst_remaining=0
func _suspend_gestures()->void:
	super._suspend_gestures()
	burst_remaining=0
	_burst_armed=false
func _build_model()->void:
	super._build_model()
	var shroud:=_material(Color("354e52"),0.6,0.45)
	# The rack owns the transparent reflex window. The old solid block occupied
	# that exact window and hid its glass/dot when viewed down the gun.
	var optic_foot:=_beveled(Vector3(.075,.010,.11),Vector3(0,.086,-.12),shroud,.002)
	optic_foot.name="AuthoredReflexRailFoot"
	RemainingFinish.burst(self)
	if preload("res://scripts/downloaded_firearm_model.gd").available("mk18"):preload("res://scripts/downloaded_firearm_model.gd").build(self,"mk18")
func rack_bolt()->void:
	super.rack_bolt()



func reset_weapon()->void:
	super.reset_weapon();burst_remaining=0;_burst_armed=true
