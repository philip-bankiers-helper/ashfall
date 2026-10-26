extends "res://tests/integration.gd"
func key(game,code:int):
 var event:=InputEventKey.new();event.pressed=true;event.keycode=code;event.physical_keycode=code;game._unhandled_input(event)
func run():
 if not OS.get_user_data_dir().replace("\\","/").contains("reports/QA/test-appdata"):quit(2);return
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame
 game._stop_audio_tree(game);game.set_process(false);game.field_menu.set_open(false);game.paused=false;game.player.input_enabled=true
 var actor=game.player;actor.set_process(false);actor.set_physics_process(false);actor.global_position=Vector3(100,0,100)
 var floor:=StaticBody3D.new();floor.position=Vector3(100,-.1,100);var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.2,20);col.shape=box;floor.add_child(col);root.add_child(floor)
 var inv=game.weapon_inventory;inv.relocate_pickups(actor.global_position)
 await physics_frame;await physics_frame
 var cam:Camera3D=actor.get_view_camera();var target:Node3D=inv.pickups[5]
 for index in inv.pickups:
  if index!=5:inv.pickups[index].global_position=Vector3(120+index,0,120)
 target.global_position=Vector3(100,.1,98.9);cam.look_at(target.global_position)
 var bank:Dictionary=game.weapon.reserves.duplicate();var loaded:int=game.weapon.weapons[5].ammo
 key(game,KEY_H);check(inv.owned_indices()==[0,2,4] and inv.pickups.has(5),"desktop pickup cannot bypass three-slot capacity")
 key(game,KEY_K);check(not inv.has_weapon(0) and inv.owned_indices().size()==2,"desktop drop uses real safe floor placement")
 inv.pickups[0].global_position=Vector3(125,0,125)
 var wall:=StaticBody3D.new();wall.position=(cam.global_position+target.global_position)*.5
 var c:=CollisionShape3D.new();var b:=BoxShape3D.new();b.size=Vector3(1,2,.1);c.shape=b;wall.add_child(c);root.add_child(wall);await physics_frame
 key(game,KEY_H);check(not inv.has_weapon(5),"desktop pickup obeys actual wall occlusion")
 wall.queue_free();await physics_frame;await physics_frame
 key(game,KEY_H);check(inv.has_weapon(5) and game.weapon.selected==5,"actual H key picks and equips aimed new family")
 check(game.weapon.reserves==bank and game.weapon.weapons[5].ammo==loaded,"desktop transfer never grants reserve or loaded rounds")
 check(inv.drop_weapon(5),"new desktop-owned family can drop safely")
 target=inv.pickups[5];target.global_position=cam.global_position-Vector3(0,0,4);cam.look_at(target.global_position)
 key(game,KEY_H);check(not inv.has_weapon(5),"desktop pickup rejects out-of-reach ground gun")
 target.global_position=Vector3(100,.1,98.9);cam.look_at(target.global_position);game.paused=true;key(game,KEY_H);check(not inv.has_weapon(5),"paused desktop cannot pick up")
 game.paused=false;game.xr_enabled=true;key(game,KEY_H);check(not inv.has_weapon(5),"keyboard adapter cannot bypass physical VR pickup")
 game.xr_enabled=false;game._stop_audio_tree(game);game.queue_free();floor.queue_free();await process_frame;await create_timer(.3).timeout
 print("DESKTOP_INVENTORY_042_RESULT passes=",passed," failures=",failures.size());quit(0 if failures.is_empty() else 1)
