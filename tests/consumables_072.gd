extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func freeze(n:Node)->void:
	n.set_process(false);n.set_physics_process(false)
	for child in n.get_children():freeze(child)
func run()->void:
	var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame;await physics_frame;freeze(game)
	game.field_menu.set_open(false);game.paused=false;game.dead=false;game.complete=false
	var actor=game.player;actor.xr_enabled=false;actor.input_enabled=true;actor.tracking_available=true;actor.vertical_combat_initializing=false;actor.head_obstructed=false;actor.position=Vector3(1000,0,1000)
	var supply=game.field_consumables;supply.items={"test":{"kind":"shaker"}};supply.stock.shaker=1;supply.equip_instance("test")
	supply.sample_shake(Vector3.ZERO,.05)
	supply.sample_shake(Vector3(.05,0,0),.05)
	check(absf(supply._shake_distance-.065)<.00001 and absf(supply._shake_seconds-.065)<.00001,"shaker physical charge rate is1.3 times071")
	supply._shake_distance=.9;supply._shake_seconds=1.5;supply._reversals=3;supply._update_preparation_visual()
	var ring=supply.held_prop.get_node("ChargeRing")
	check(ring.get_meta("segments")==32 and ring.mesh.get_surface_count()==2,"half charge renders half circular progress with background")
	check(supply.held_prop.get_node("ItemTitle").text=="SHAKE","numeric shaker percentage replaced")
	var pose:=Transform3D(Basis(Vector3.RIGHT,.6),Vector3(2,3,4));supply.held_prop.global_transform=pose
	check(supply.consumption_anchor().distance_to(pose*Vector3(0,.127,.008))<.00001,"shaker consumption uses transformed spout rather than grip origin")
	var head:=Vector3(0,1.5,0)
	for direction in [Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		check(supply.within_headset_reach(head+direction*.44,head),"expanded head sphere accepts approach "+str(direction))
	check(not supply.within_headset_reach(head+Vector3.UP*.46,head),"head region remains bounded")
	game.shield=0;check(not supply.consume_at_mouth(1,true,true),"unready shaker cannot consume even inside head region")
	supply._ready_to_drink();supply._update_preparation_visual();check(ring.get_meta("segments")==64,"ready ring is complete")
	check(not supply.consume_at_mouth(.3,true,true) and supply.consume_at_mouth(.36,true,true),"ready shaker still needs continuous dwell")
	actor.global_position=Vector3.ZERO
	var tool=game.revive_paddles;tool.equip()
	for direction in [Vector3.RIGHT,Vector3.UP,Vector3.FORWARD]:
		tool._clear_charge()
		for i in 20:tool.step_contacts(.02,Vector3.ZERO,direction*.2,true,-direction,direction)
		check(tool.charge==0,"wrong-facing electrodes cannot charge")
		for i in 20:tool.step_contacts(.02,Vector3.ZERO,direction*.2,true,direction,-direction)
		check(tool.charge==0,"facing without movement cannot charge")
		for i in 10:tool.step_contacts(.02,Vector3.ZERO,direction*(.2+(.01 if i%2 else 0)),true,direction,-direction)
		check(tool.charge>0,"short facing strokes charge without large loops")
	tool._clear_charge();tool.step_contacts(.02,Vector3.ZERO,Vector3(.2,0,0),true,Vector3.RIGHT,Vector3.LEFT)
	tool.step_contacts(.02,Vector3.ZERO,Vector3(.204,0,0),true,Vector3.RIGHT,Vector3.LEFT);var slow:float=tool.charge
	tool._clear_charge();tool.step_contacts(.02,Vector3.ZERO,Vector3(.2,0,0),true,Vector3.RIGHT,Vector3.LEFT)
	tool.step_contacts(.02,Vector3.ZERO,Vector3(.208,0,0),true,Vector3.RIGHT,Vector3.LEFT)
	check(absf(tool.charge-2*slow)<.00001,"double movement speed gives double charge for equal time")
	for hz in [30,90]:
		var times:Array[float]=[]
		for speed in [1.0,.25]:
			tool._clear_charge();tool.step_contacts(1.0/hz,Vector3.ZERO,Vector3(.2,0,0),true,Vector3.RIGHT,Vector3.LEFT)
			var frames:=0
			while not tool.charge_ready and frames<hz*12:
				frames+=1
				tool.step_contacts(1.0/hz,Vector3.ZERO,Vector3(.2+(speed/hz if frames%2 else 0),0,0),true,Vector3.RIGHT,Vector3.LEFT)
			times.append(float(frames)/hz)
		check(times[0]>=5.36-.0001 and times[0]<=5.36+1.0/hz+.0001,"maximum speed charge bounded by5.36 seconds at%dHz"%hz)
		check(times[1]>times[0]*1.9 and times[1]<times[0]*2.1,"slower small strokes require longer at%dHz"%hz)
	for hz in [30,72,90,120]:
		tool._clear_charge();actor.global_position=Vector3.ZERO
		var left_local:=Vector3(-.1,1,0);var right_local:=Vector3(.1,1,0)
		tool.step_contacts(1.0/hz,left_local,right_local,true,Vector3.RIGHT,Vector3.LEFT)
		for frame in hz:
			actor.global_position+=Vector3(.01,0,.007)
			tool.step_contacts(1.0/hz,actor.to_global(left_local),actor.to_global(right_local),true,Vector3.RIGHT,Vector3.LEFT)
		check(tool.charge==0,"actor translation with stationary local hands gives no charge at%dHz"%hz)
		for mode in ["together","opposed"]:
			actor.global_position=Vector3.ZERO;tool._clear_charge()
			tool.step_contacts(1.0/hz,left_local,right_local,true,Vector3.RIGHT,Vector3.LEFT)
			var frames:=0
			while not tool.charge_ready and frames<hz*6:
				frames+=1
				var stroke:=Vector3(0,1.0/hz if frames%2 else 0,0)
				tool.step_contacts(1.0/hz,left_local+stroke,right_local+(stroke if mode=="together" else -stroke),true,Vector3.RIGHT,Vector3.LEFT)
			var elapsed:float=float(frames)/hz
			check(tool.charge_ready and elapsed>=5.36-.0001 and elapsed<=5.36+1.0/hz+.0001,"both-hand%s short strokes respect5.36s floor at%dHz"%[mode,hz])
	actor.global_position=Vector3(1000,0,1000)
	var target=game.rescue_dummy;target.global_position=Vector3(1000,0,1000);target.reset_training();var pads:Array=target.revive_contacts()
	check(tool._contact_contains(target,pads[0]+Vector3(0,.8,.6),pads[0]),"contact volume extends substantially upward and forward")
	check(not tool._contact_contains(target,pads[0]+Vector3(0,1,.8),pads[0]),"expanded revive contact remains bounded")
	tool.charge_ready=true;tool.charge=1;tool._separated=true
	check(tool.step_contacts(.02,pads[0]+Vector3(0,.8,.6),pads[1]+Vector3(0,.8,.6),true) and target.health==50,"expanded physical two-paddle contact revives actual solo target")
	print("CONSUMABLES_072 checks=",checks," failures=",failures)
	game.weapon.shutdown();game._stop_audio_tree(game);game.queue_free();await create_timer(.25).timeout;quit(0 if failures==0 else 1)
