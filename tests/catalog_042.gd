extends SceneTree
var passes:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passes+=1;print("PASS ",label)
 else:failures+=1;printerr("FAIL ",label)
func run():
 if not OS.get_user_data_dir().replace("\\","/").contains("reports/QA/test-appdata"):quit(2);return
 var game=load("res://main.tscn").instantiate();root.add_child(game)
 await process_frame;await physics_frame
 game._stop_audio_tree(game);game.field_menu.set_open(false);game.paused=false;game.player.input_enabled=true
 for frame in range(80):await physics_frame
 game.set_process(false);game.player.set_physics_process(false)
 var rack=game.weapon
 check(rack.weapons.size()==12,"production Main wires twelve distinct weapon instances")
 check(rack.weapon_ids.size()==rack.weapons.size() and rack.AMMO_FAMILIES.size()==rack.weapons.size(),"catalog identity and finite reserve family mapping complete")
 check(game.weapon_inventory.owned_indices()==[0,2,4],"three carried slots preserved")
 check(game.weapon_inventory.pickups.size()==rack.weapons.size()-3,"every other type represented by real ground prop")
 for i in range(rack.weapons.size()):
  var gun=rack.weapons[i]
  check(gun.ammo_provider==rack and gun.ammo_slot==i,"type%d routes reserves through actual rack"%i)
  check(gun.get_loaded_rounds()>=0 and gun.get_loaded_rounds()<=gun.magazine_size,"type%d loaded state bounded"%i)
  check(gun.get_shot_transform().origin.is_finite(),"type%d actual muzzle transform finite"%i)
  check(ResourceLoader.exists("res://assets/ui/wheel_weapon_%d.svg"%i),"type%d flat backpack/wheel picture exists"%i)
 var inv=game.weapon_inventory
 for index in inv.owned_indices():check(inv.drop_weapon(index),"safe production inventory drop%d"%index)
 check(inv.owned_indices().is_empty(),"no phantom carried gun after dropping all")
 for index in [5,7,9]:check(inv.pickup_weapon(index),"new family%d enters finite inventory"%index)
 check(not inv.pickup_weapon(6),"full inventory refuses another family without destroying pickup")
 rack.wheel.set_owned_indices(inv.owned_indices())
 for index in [5,7,9]:
  check(rack.wheel.SLOT_ACTIONS.has("weapon_%d"%index),"new family%d reachable on angular wheel"%index)
  rack.is_holstered=false;rack.is_selecting=false;rack.selected=index;rack._apply_selection()
  check(rack.weapons[index].visible,"new family%d selected instance visible"%index)
  var state:Dictionary=rack.get_ammo_display_state(index)
  var family:String=rack.AMMO_FAMILIES[index]
  var previous:int=rack.reserves[family]
  var consumed:int=rack.weapons[index].take_reserve(3)
  check(consumed==mini(3,previous) and rack.reserves[family]==previous-consumed,"new family%d consumes finite actual family exactly once"%index)
 check(rack.wheel.SLOT_ACTIONS.count("backpack")==1 and rack.wheel.SLOT_ACTIONS[0]=="empty","utility and central cancel semantics preserved")
 var labels:Array=game._loadout_labels();var icons:Array=game._loadout_icons()
 check(labels.size()==4 and icons.size()==4 and icons[0]!=null and icons[2]!=null,"backpack maps three carried new families to flat pictures")
 var snapshot:Dictionary=rack.reserves.duplicate()
 inv.relocate_pickups(game.player.global_position)
 check(rack.reserves==snapshot and inv.owned_indices()==[5,7,9],"checkpoint prop relocation preserves ownership and finite reserves")
 for index in range(rack.weapons.size()):
  for carried in inv.owned_indices():check(inv.drop_weapon(carried),"catalog sweep safe drop%d"%carried)
  var loaded:int=rack.weapons[index].get_loaded_rounds()
  var bank:Dictionary=rack.reserves.duplicate()
  check(inv.pickup_weapon(index),"catalog sweep actual pickup%d"%index)
  rack.wheel.set_owned_indices(inv.owned_indices())
  check(rack.wheel.SLOT_ACTIONS.has("weapon_%d"%index),"every family reaches angular sector%d"%index)
  check(rack.weapons[index].get_loaded_rounds()==loaded and rack.reserves==bank,"every transfer preserves existing ammunition%d"%index)
 var pair=rack.weapons[11]
 pair.guns[0].ammo=3;pair.guns[1].ammo=5;pair._sync_pair()
 check(inv.drop_weapon(11) and inv.pickup_weapon(11),"dual bundle supports actual ground drop and pickup")
 check(pair.guns[0].ammo==3 and pair.guns[1].ammo==5,"dual ground transfer preserves both independent magazines")
 game._stop_audio_tree(game);game.queue_free();await process_frame;await create_timer(.3).timeout
 print("CATALOG_042_RESULT passes=",passes," failures=",failures," headset_tested=false")
 quit(0 if failures==0 else 1)
