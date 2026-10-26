extends SceneTree
const Consumables=preload("res://scripts/field_consumables.gd")
const Dummy=preload("res://scripts/practice_dummy.gd")
const Damage=preload("res://scripts/damage_feedback.gd")
const Hud=preload("res://scripts/combat_hud.gd")
class Actor extends Node3D:
	var input_enabled:=true
	var tracking_available:=true
	var head_obstructed:=false
	var xr_enabled:=false
	var camera:Camera3D
	var left_hand:XRController3D
	var right_hand:XRController3D
	var _grabs:Dictionary={}
	var _sprint_stamina:=5.0
	var sprint_stamina_seconds:=5.0
	func get_view_camera()->Camera3D:return camera
	func get_weapon_hand()->XRController3D:return right_hand
	func is_hand_input_ready(hand:XRController3D)->bool:return tracking_available and is_instance_valid(hand)
class Game extends Node3D:
	var health:=20.0
	var shield:=0.0
	var paused:=false
	var dead:=false
	var complete:=false
class Rack extends Node:
	var is_holstered:=false
	func set_holstered(value:bool)->void:is_holstered=value
var passed:=0
var failed:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;printerr("FAIL ",label)
func run()->void:
	var game:=Game.new();root.add_child(game)
	var actor:=Actor.new();game.add_child(actor)
	actor.camera=Camera3D.new();actor.add_child(actor.camera)
	actor.left_hand=XRController3D.new();actor.add_child(actor.left_hand)
	actor.right_hand=XRController3D.new();actor.add_child(actor.right_hand)
	var rack:=Rack.new();game.add_child(rack)
	var supplies:=Consumables.new();game.add_child(supplies);supplies.setup(actor,rack,game);supplies.set_process(false)
	# Supply gestures/capacity superseded by069 production integration tests.
	var dummy:=Dummy.new();game.add_child(dummy);dummy.set_process(false)
	var before:=Damage.snapshot(dummy);dummy.take_damage(130);var loss:=Damage.loss(before,dummy)
	check(loss.amount==130 and loss.shield==100 and loss.health==30,"dummy actual layered loss")
	before=Damage.snapshot(dummy);dummy.take_melee_damage(200);loss=Damage.loss(before,dummy)
	check(loss.amount==70 and loss.health==70 and dummy.health==0,"overkill clamped to remaining pool")
	dummy.take_damage(50);check(dummy.last_damage==0,"dead target cannot generate fake damage")
	dummy._process(1.6);check(dummy.health==100 and dummy.shield==100,"target resets after idle delay")
	dummy.take_melee_damage(25);check(dummy.shield==100 and dummy.health==75,"melee bypasses practice shield")
	var hud:=Hud.new();game.add_child(hud);hud.setup(actor,game);hud.set_process(false)
	hud.notify_outgoing(18,1,true);hud.notify_outgoing(18,1,true)
	check(hud.outgoing_number.text=="36" and hud.outgoing_number.visible,"bottom HUD aggregates actual rapid hits")
	hud.notify_outgoing(12,2,false);check(hud.outgoing_number.text=="12","new target resets burst total")
	hud.notify_outgoing(NAN,2);hud.notify_outgoing(-1,2);check(hud.outgoing_number.text=="12","invalid damage ignored")
	hud.notify_incoming(12);check(hud.incoming_number.visible,"incoming numeric damage enabled by default")
	check(hud.incoming_number.text=="-12","incoming amount has distinct loss sign")
	check(hud.outgoing_number.position.y<-.4 and hud.outgoing_number.position.x>0 and hud.incoming_number.position.x<0,"outgoing right incoming left alongside bottom bars")
	hud.refresh(1.2);check(not hud.outgoing_number.visible and not hud.incoming_number.visible,"numeric cues expire")
	hud.notify_outgoing(10,1);game.paused=true;hud.refresh(0)
	check(not hud.visible and hud.outgoing_remaining==0,"pause clears transient numbers")
	game.queue_free();await process_frame;await process_frame
	print("EQUIPMENT_061_RESULT passes=",passed," failures=",failed," synthetic=true headset_tested=false")
	quit(0 if failed==0 else 1)

