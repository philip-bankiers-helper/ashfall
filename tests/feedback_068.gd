extends SceneTree
const Sight=preload("res://scripts/authored_ring_dot_sight.gd")
const Assets=preload("res://scripts/blade_assets.gd")
class Sword extends "res://scripts/melee_sword.gd":
	func _usable()->bool:return true
class Victim extends StaticBody3D:
	var hits:=0
	func take_melee_damage(_amount:float)->void:hits+=1
var checks:=0
var failures:=0
func _initialize()->void:Engine.max_fps=120;call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func stop(node:Node)->void:
	node.set_process(false);node.set_physics_process(false)
	for child in node.get_children():stop(child)
func run()->void:
	var game=load("res://scripts/main.gd").new();root.add_child(game);stop(game)
	var actor=game.player;var rack=game.weapon;var supplies=game.field_consumables
	game.paused=false;game.dead=false;game.complete=false;actor.input_enabled=true;actor.tracking_available=true
	await physics_frame;await physics_frame
	supplies.collect(9);supplies.collect(0)
	check(supplies.equip("shaker"),"shaker equip through ordinary selected-item provider")
	for i in 45:supplies.sample_shake(Vector3(0,.15*(i%2),0),.1)
	check(supplies.phase=="consume" and supplies.audio_events.has("ready"),"shake transitions directly to drink with ready audio")
	check(supplies.held_prop.get_node("Cap").visible,"ready shaker retains lid")
	var count:int=supplies.stock.shaker
	rack.toggle_selected_item()
	check(supplies.held_kind.is_empty() and supplies.stock.shaker==count,"A stows without spending")
	rack.toggle_selected_item()
	check(supplies.held_kind=="shaker" and supplies.phase=="consume","A reequips preserving readiness")
	check(rack.select_inventory_weapon(0) and supplies.held_kind.is_empty() and supplies.selected_kind.is_empty(),"gun selection releases item ownership")
	supplies.equip("shaker");game.shield=0
	check(supplies.consume_at_mouth(.7,true,true) and supplies.stock.shaker==count-1 and game.shield==50,"drink spends one ready shaker")
	check(supplies.audio_events.has("drink"),"drink emits sound")
	# Audit hand pose at arbitrary rigid transforms, both ownership choices.
	actor.xr_enabled=true
	for hand in [actor.left_hand,actor.right_hand]:
		hand.transform=Transform3D(Basis.from_euler(Vector3(.4,.6,-.3)),Vector3(.2,1.2,-.3))
		# XR runtime validity is deliberately not forged; test the exact production pose equation.
		var pose:Transform3D=preload("res://scripts/weapon.gd").corrected_grip_transform(hand.global_transform)
		check(pose.basis.y.normalized().dot(-hand.global_basis.z.normalized())>.99999,"drink long axis follows corrected thumb axis "+str(hand.name))
	actor.xr_enabled=false
	
	supplies.collect(1);supplies.equip("soda")
	var tap_ray:Transform3D=actor.get_view_camera().global_transform
	rack._a_blocked=false;rack._a_previous=false
	rack.update_a_input(.02,true,true,tap_ray)
	rack.update_a_input(.02,false,true,tap_ray)
	check(supplies.held_kind.is_empty() and supplies.selected_kind=="soda","actual A press/release stows selected soda")
	rack._a_blocked=false
	rack.update_a_input(.02,true,true,tap_ray)
	rack.update_a_input(.02,false,true,tap_ray)
	check(supplies.held_kind=="soda","actual A press/release reequips selected soda")
	rack.is_selecting=true;supplies._process(.1)
	check(not supplies.held_prop.visible and supplies.phase=="open","wheel selection suspends item gestures without resetting preparation")
	rack.is_selecting=false;supplies._process(.01)
	check(supplies.held_prop.visible,"selected item returns after closing wheel")
	supplies.stow()
	var selected:int=rack.selected;var ammo:int=rack.weapons[selected].ammo
	supplies.items.clear();supplies.selected_kind="";supplies.selected_instance=""
	game.weapon_inventory.owned.assign([26,25,8,17,2,14])
	var sorted:Array=game.weapon_inventory.owned_indices()
	check(sorted==[14,2,17,8,25,26],"category order swords pistols SMGs machine guns snipers grenades")
	check(game.weapon_inventory.category_rank(1)<game.weapon_inventory.category_rank(2),"shotguns precede pistols")
	rack.wheel.set_owned_indices(sorted)
	var expected_clocks:=[3.0,1.5,12.0,10.5,9.0,7.5]
	for i in rack.wheel.ITEM_SLOTS.size():
		var slot:int=rack.wheel.ITEM_SLOTS[i]
		check(rack.wheel.SLOT_CLOCK_HOURS[slot]==expected_clocks[i],"ordinary slots follow the requested clock arc")
		check(rack.wheel.SLOT_ACTIONS[slot]=="weapon_%d"%sorted[i],"radial arc preserves sorted instance identity")
	check(rack.selected==selected and rack.weapons[selected].ammo==ammo,"sorting preserves selected instance and ammunition")
	check(rack.wheel.ITEM_SLOTS.size()==6 and rack.wheel.SLOT_ACTIONS.filter(func(a):return str(a).begins_with("weapon_")).size()==6,"six occupied weapon slots leave no extra heal sectors")
	supplies._process(0)
	check(not supplies._pouch.visible,"no floating belt supplies")
	for index in [0,21,25]:
		var gun:Node3D=rack.weapons[index]
		var sight:Node3D=gun.get_meta("ring_sight")
		var rear:Node3D=sight.get_node("RearReference");var front:Node3D=sight.get_node("FrontReference")
		var inner:Node3D=sight.find_child("FrontAlignmentRing",true,false)
		check(inner.global_position.distance_to(rear.global_position.lerp(front.global_position,.5))<.00001,"inner ring is exactly halfway CX4/AK/S85 "+str(index))
		var axis:Vector3=(front.global_position-rear.global_position).normalized()
		var eye:Vector3=rear.global_position-axis*.22
		check(Sight.eye_aligned(sight,eye,axis),"aligned eye suppresses crosshair "+str(index))
		check(not Sight.eye_aligned(sight,eye+gun.global_basis.x*.10,axis),"off-axis eye restores crosshair "+str(index))
		check(not Sight.eye_aligned(sight,eye,-axis),"looking away restores crosshair "+str(index))
		var aligned:=Transform3D(Basis.looking_at(axis,Vector3.UP),eye)
		var missed:=aligned;missed.origin+=gun.global_basis.x*.12
		check(Sight.views_aligned(sight,[aligned,missed]) and Sight.views_aligned(sight,[missed,aligned]),"either runtime eye can suppress crosshair "+str(index))
		check(not Sight.views_aligned(sight,[missed]),"no aligned runtime eye keeps crosshair "+str(index))
	# Final transformed geometry, using actual runtime rack and all ancestor transforms.
	for index in [14,15,16]:
		var sword:Node3D=rack.weapons[index]
		sword.show();sword.model.show()
		sword.transform=Transform3D(Basis.from_euler(Vector3(.7,-.5,.3)),Vector3(3,2,-4))
		var pommel:MeshInstance3D=sword.model.get_node("Pommel")
		var bottom:Vector3=pommel.to_global(Vector3(0,-pommel.mesh.size.y*.5,0))
		var tip:Vector3=sword.blade_tip.global_position
		var grip:Vector3=sword.model.to_global(sword.hand_grip_center)
		check(absf(bottom.distance_to(tip)-1.4101590361445784)<.00001,"final transformed sword is four feet "+str(index))
		check(absf(bottom.distance_to(grip)-0.23502650602409636)<.00001,"final transformed primary grip is eight inches from pommel "+str(index))
		print("GEOMETRY068 ",index," length_m=",bottom.distance_to(tip)," grip_m=",bottom.distance_to(grip))
		var blade:MeshInstance3D=sword.model.get_node("AuthoredBlade")
		var longest:=0.0
		for surface in blade.mesh.get_surface_count():
			var arrays:Array=blade.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if indices.is_empty():
				for vertex_index in vertices.size():indices.append(vertex_index)
			for vertex_index in indices:longest=maxf(longest,bottom.distance_to(blade.to_global(vertices[vertex_index])))
		check(absf(longest-1.4101590361445784)<.00005,"actual referenced mesh vertices after final transforms span four feet "+str(index))
		print("MESH_GEOMETRY068 ",index," longest_pommel_to_vertex_m=",longest)
	game._quitting=true;rack.shutdown();game._stop_audio_tree(game)
	await create_timer(1.0).timeout
	game.queue_free();await process_frame;await process_frame
	# Isolated physics scene: actual swept collisions and emitted directional velocity.
	var player=load("res://scripts/player.gd").new();root.add_child(player);player.setup(false);stop(player)
	player.position=Vector3(0,0,0)
	for kind in ["katana","excalibur","cyberblade"]:
		var sword:=Sword.new();sword.archetype=kind;root.add_child(sword);sword.setup(player,false);stop(sword)
		var directions:Array[Vector3]=[Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK,Vector3(1,1,0).normalized(),Vector3(-1,-1,0).normalized()]
		for handedness in [-1,1]:
			for hz in [72,90,120]:
				for direction in directions:
					# Tilt the blade across the target; this also covers horizontal blade attitudes.
					var basis:=Basis.from_euler(Vector3(.2,.3,handedness*.8))
					var center:=Vector3(0,1,-1)
					var target:=Victim.new();target.collision_layer=4;root.add_child(target)
					target.position=center+basis*(sword.blade_base.position.lerp(sword.blade_tip.position,.6))
					var collision:=CollisionShape3D.new();var ball:=SphereShape3D.new();ball.radius=.045;collision.shape=ball;target.add_child(collision)
					await physics_frame;await physics_frame
					var emitted:Array=[]
					var callback:=func(body:Node3D,_point:Vector3,_amount:float,velocity:Vector3):
						if body==target:target.take_melee_damage(_amount);emitted.append(velocity)
					sword.melee_contact.connect(callback)
					sword._history_valid=false;sword._reset_stroke();sword._target_next_ms.clear()
					var steps:=int(ceil(hz*(2.0/2.8))) # Begin/end outside blade contact; retain about2.8m/s.
					for frame in steps+1:
						var t:=float(frame)/steps
						sword.transform=Transform3D(basis,center+direction*lerpf(-1.0,1.0,t))
						sword.sample_motion(1.0/hz)
					check(target.hits==1,"%s hand%d %dHz direction%s swept contact once"%[kind,handedness,hz,direction])
					check(emitted.size()==1 and emitted[0].dot(direction)>.99,"damage direction follows swing velocity")
					sword.melee_contact.disconnect(callback);target.free()

		# Real angular strokes: vertical and horizontal arcs, forehand and backhand.
		for axis in [Vector3.UP,Vector3.RIGHT,Vector3.FORWARD]:
			for handedness in [-1,1]:
				for hz in [72,90,120]:
					var pivot:=Vector3(0,1,-1)
					var rest:=Basis(Vector3.RIGHT,PI*.5) if axis==Vector3.UP else Basis.IDENTITY
					var midpoint:Vector3=rest*sword.blade_base.position.lerp(sword.blade_tip.position,.75)
					var target:=Victim.new();target.collision_layer=4;root.add_child(target);target.position=pivot+midpoint
					var collision:=CollisionShape3D.new();var ball:=SphereShape3D.new();ball.radius=.045;collision.shape=ball;target.add_child(collision)
					await physics_frame;await physics_frame
					var callback:=func(body:Node3D,_point:Vector3,amount:float,_direction:Vector3):
						if body==target:target.take_melee_damage(amount)
					sword.melee_contact.connect(callback);sword._history_valid=false;sword._reset_stroke();sword._target_next_ms.clear()
					var steps:=int(hz*.20)
					for frame in steps+1:
						var angle:float=handedness*lerpf(-.5,.5,float(frame)/steps)
						sword.transform=Transform3D(Basis(axis,angle)*rest,pivot);sword.sample_motion(1.0/hz)
					check(target.hits==1,"%s angular axis%s hand%d %dHz hits once"%[kind,axis,handedness,hz])
					sword.melee_contact.disconnect(callback);target.free()
		sword.shutdown();sword._sound.stream=null;sword._hum.stream=null;sword.free()
	player.free();await create_timer(.4).timeout
	print("FEEDBACK_068 checks=",checks," failures=",failures," headset_tested=false")
	quit(failures)
