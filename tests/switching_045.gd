extends SceneTree
var failed:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,label:String)->void:
	checks+=1
	print("PASS " if value else "FAIL ",label)
	if not value:failed+=1
func snap(gun)->Dictionary:
	var result:Dictionary={"loaded":gun.get_loaded_rounds(),"ammo":gun.ammo}
	var names:Array=[]
	for prop in gun.get_property_list():names.append(prop.name)
	for key in ["chambered","spent_chamber","tube_rounds","_seated_rounds","seated","chambers","bolt_phase"]:
		if names.has(key):
			var value=gun.get(key)
			result[key]=value.duplicate(true) if value is Array or value is Dictionary else value
	return result
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false)
	actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for index in range(rack.weapons.size()):
		var gun=rack.weapons[index]
		gun.reset_weapon()
		for step in range(8):
			rack.selected=index;rack.is_selecting=false;rack.is_holstered=false
			gun.cooldown=0
			gun.desktop_reload_step()
			var state:String=gun.reload_state
			var before:=snap(gun)
			var reserve:Dictionary=rack.reserves.duplicate(true)
			var other:int=(index+1)%rack.weapons.size()
			check(rack.select_weapon(other),"slot%d state%s switches away"%[index,state])
			check(snap(gun)==before and rack.reserves==reserve,"slot%d state%s preserves mechanical ammo/progress"%[index,state])
			check(not gun._rack_grabbed and gun._requires_trigger_release,"slot%d state%s cancels contacts and requires fresh trigger"%[index,state])
			check(rack.select_inventory_weapon(index),"slot%d state%s backpack return allowed"%[index,state])
			check(snap(gun)==before and rack.reserves==reserve,"slot%d state%s return cannot duplicate rounds"%[index,state])
	rack.selected=0;rack.is_holstered=false
	var rifle=rack.weapons[0]
	rifle.reset_weapon();rifle.eject_magazine();rifle.grab_magazine();rifle.insert_magazine()
	var wheel_before:=snap(rifle)
	var reserve_before:Dictionary=rack.reserves.duplicate(true)
	var opening:=Transform3D(Basis.IDENTITY,Vector3(.15,1.3,0))
	rack.update_a_input(.01,false,true,opening)
	rack.update_a_input(.01,true,true,opening)
	var target:Vector3=rack.wheel.to_global(rack.wheel.slot_position(5,.25))
	var choice:=Transform3D(Basis.looking_at(target-opening.origin,Vector3.UP),opening.origin)
	rack.update_a_input(.01,true,true,choice)
	rack.update_a_input(.01,false,true,choice)
	check(rack.selected==2,"real A-wheel selects another gun with seated uncharged magazine")
	check(snap(rifle)==wheel_before and rack.reserves==reserve_before,"wheel opening and release preserve seated rounds and family reserve")
	var bank:int=rack.reserves.rifle
	check(rack.refund_weapon_reserve(0,-5)==0 and rack.reserves.rifle==bank,"negative refund cannot remove reserve")
	rack.reserves.rifle=rack.MAX_RESERVE-2
	check(rack.refund_weapon_reserve(0,5)==2 and rack.reserves.rifle==rack.MAX_RESERVE,"refund hook returns exact capped credit")
	check(rack.refund_weapon_reserve(-1,2)==0,"invalid refund slot rejects")
	rack.shutdown();await create_timer(.2).timeout;rack.free();actor.free()
	print("SWITCHING_045 checks=",checks," failures=",failed," synthetic=true headset_tested=false")
	quit(failed)


