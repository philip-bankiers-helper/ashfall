extends SceneTree
## Exercise real empty reload transactions, rather than just setup-time capacities.
class Reserve extends Node:
	var count:=0
	func get_ammo_display_state(_slot:int)->Dictionary:return {"reserve":count}
	func consume_weapon_reserve(_slot:int,wanted:int)->int:
		var taken:=mini(count,wanted);count-=taken;return taken
	func refund_weapon_reserve(_slot:int,wanted:int)->int:
		var returned:=mini(wanted,9999-count);count+=returned;return returned
const Arsenal=preload("res://scripts/arsenal_data.gd")
const PATHS:Dictionary={0:"catalog_firearm",1:"dt11",2:"pistol",3:"burst_carbine",5:"precision_rifle",6:"compact_smg",7:"revolver",8:"belt_lmg",9:"auto_shotgun",10:"top_feed_pdw",11:"dual_pistols",12:"dual_matadors",13:"spr",17:"catalog_firearm",18:"catalog_firearm",19:"catalog_firearm",20:"catalog_firearm",21:"catalog_firearm",23:"catalog_firearm",24:"catalog_firearm",25:"catalog_firearm"}
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func empty_and_open(gun,index:int)->void:
	gun.reset_weapon();Arsenal.apply(gun,index)
	if index in [11,12]:
		for child in gun.guns:child.ammo=0;child.eject_magazine()
		gun._sync_pair();return
	gun.ammo=0;gun._seated_rounds=0
	if index==1:gun.action.ammo=0;gun.action.loaded=0;gun.chamber_states.fill("empty")
	if index==7:gun.chambers.fill("empty");gun._sync()
	if index==8:gun.seated=0
	if index==5:gun.chambered=false;gun.spent_chamber=false
	gun.eject_magazine()
func finish(gun)->void:
	for step in 8:
		if gun.reload_state=="ready":break
		gun.desktop_reload_step()
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	for index in PATHS:
		var data:Dictionary=Arsenal.profile(index)
		var gun=load("res://scripts/"+PATHS[index]+".gd").new()
		if PATHS[index]=="catalog_firearm":gun.profile_id=data.id;gun.mode=data.fire_mode
		root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
		var bank:=Reserve.new();root.add_child(bank);gun.ammo_provider=bank;gun.ammo_slot=0;gun.update_ammo_display()
		var capacity:int=int(data.magazine_per_hand)*int(data.hands)
		for supplied in [capacity+17,maxi(1,capacity-1),1,0]:
			bank.count=supplied;empty_and_open(gun,index);finish(gun)
			var loaded:int=gun.get_loaded_rounds()
			check(loaded==mini(capacity,supplied),str(data.id)+" real reload uses configured capacity with reserve "+str(supplied))
			check(loaded+bank.count==supplied,str(data.id)+" reload conserves reserve "+str(supplied))
			var funded:=loaded+bank.count
			finish(gun);check(gun.get_loaded_rounds()+bank.count==funded,str(data.id)+" repeated completion cannot duplicate rounds")
			if loaded>0:check(gun.reload_state=="ready",str(data.id)+" finite loaded reload reaches ready")
		if index==8:
			bank.count=100;empty_and_open(gun,index);gun.grab_magazine();gun.insert_magazine()
			check(gun.seated==75 and bank.count==25,"M60 stores75 funded rounds before feed/cover/charge")
			gun.close_cover();gun.rack_bolt();check(gun.reload_state=="needs_feed","M60 capacity correction preserves four-step order")
			gun.feed_belt();gun.close_cover();gun.rack_bolt()
			gun.ammo-=9;gun.seated=gun.ammo;var total:int=gun.ammo+bank.count
			gun.begin_reload();finish(gun)
			check(gun.ammo==75 and gun.ammo+bank.count==total,"M60 partial tactical reload refills75 without losing remaining rounds")
		gun.shutdown();gun.free();bank.free();actor.left_hand_reserved=false
	actor.free();await create_timer(.2).timeout
	print("ARSENAL_054_CAPACITY checks=",checks," failures=",failures," firearm_profiles=21 measured_reference_rates=false")
	quit(failures)
