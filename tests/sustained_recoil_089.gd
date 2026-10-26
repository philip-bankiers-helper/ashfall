extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1;print("PASS " if value else "FAIL ",message)
	if not value:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
	var maxima:Dictionary={}
	var out:=FileAccess.open("user://sustained-recoil-production.csv",FileAccess.WRITE)
	out.store_line("weapon,hands,seconds,shot_count,pitch_up_deg,yaw_right_deg,model_pitch_euler_deg,model_yaw_euler_deg")
	for index in [8,17,18]:
		for two_hands in [false,true]:
			rack.selected=index;rack.is_holstered=false;rack._apply_selection()
			var gun=rack.weapons[index];gun.reset_weapon();gun.set_process(false);gun.supported=two_hands
			gun._requires_trigger_release=false
			var id:=str(gun.get_meta("reference_id"));var duration:=15.0 if index==8 else 2.6
			var values:Array[Vector2]=[];var shots:=0;var peak:=0.0;var trough:=1000.0;var falls:=0;var rises:=0
			var before:=Vector2.ZERO;var dt:=1.0/180.0;var worst_axis_error:=0.0
			for tick in range(ceili(duration/dt)):
				var t:=tick*dt
				gun._reference_clock+=dt;gun.cooldown=maxf(0,gun.cooldown-dt)
				gun._recover_recoil(dt)
				# Use real production fire: ammunition/cooldown/spool/reload paths remain active.
				var ammo_before:int=gun.ammo
				gun.fire()
				if gun.ammo<ammo_before:shots+=1
				gun._apply_recoil_visual()
				if gun._observed_burst_active and gun.recoil_idle<=.32:
					var filmed:Vector2=gun.ObservedRecoil.sample(id,two_hands,gun._observed_burst_time)*(1.1 if id=="mp5" else 1.0)
					var pitch:=deg_to_rad(filmed.x)*1.25;var right_yaw:=deg_to_rad(filmed.y)*1.25
					var expected:=Vector3(sin(right_yaw)*cos(pitch),sin(pitch),-cos(right_yaw)*cos(pitch))
					var actual:Vector3=gun.global_basis.inverse()*(-gun.get_shot_transform().basis.z.normalized())
					worst_axis_error=maxf(worst_axis_error,actual.distance_to(expected))
				var now:=Vector2(rad_to_deg(gun.recoil_pitch),rad_to_deg(gun.recoil_yaw))
				if t<10.5 or index!=8:
					peak=maxf(peak,now.x);trough=minf(trough,now.x)
					if now.x-before.x>.015:rises+=1
					if now.x-before.x<-.015:falls+=1
				before=now;values.append(now)
				if tick%3==0:out.store_line("%s,%s,%.6f,%d,%.6f,%.6f,%.6f,%.6f"%[id,"two" if two_hands else "one",t,shots,now.x,-now.y,rad_to_deg(gun.model.rotation.x),rad_to_deg(gun.model.rotation.y)])
			check(shots>10,id+" "+str(two_hands)+" actual production firing advances beyond old10-shot fit, shots="+str(shots))
			check(peak>1 and rises>20,id+" "+str(two_hands)+" starts and continues upward")
			check(absf(gun.model.rotation.x-gun.recoil_pitch*1.25)<.00001 and absf(gun.model.rotation.y-gun.recoil_yaw*1.25)<.00001,id+" actual visible model carries both axes")
			check(worst_axis_error<.0001,id+" actual barrel matches video RIGHT-positive yaw and UP-positive pitch; direction_error="+str(worst_axis_error))
			if index==8:
				check(falls>50,"M60 "+str(two_hands)+" sustains observed descents rather than accumulating to a fixed cap")
				var tail=values.slice(roundi(8.0/dt),roundi(10.5/dt));var lo:=1000.0;var hi:=-1000.0
				for value in tail:lo=minf(lo,value.x);hi=maxf(hi,value.x)
				check(hi-lo>(.2 if two_hands else 3.0),"M60 "+str(two_hands)+" late held burst still varies, excursion="+str(hi-lo))
				check(peak<8 if two_hands else peak>40,"M60 independent one/two-hand output trajectories")
			maxima[id+("_two" if two_hands else "_one")]=peak
			gun._recover_recoil(1.0)
			check(gun.recoil_pitch==0 and gun.recoil_yaw==0 and not gun._observed_burst_active,id+" release returns to neutral and rearms new burst")
			gun.supported=false
	out.close()
	check(float(maxima.mp9_one)<float(maxima.mp5_one)*.65,"MP9 one-hand climb remains materially lower than MP5")
	check(float(maxima.mp9_two)<float(maxima.mp5_two)*.8,"MP9 two-hand climb remains materially lower than MP5")
	var fal=rack.weapons[24];fal.reset_weapon();fal.recoil_idle=.6;fal.recoil_pitch=.2;fal._recover_recoil(.1)
	check(absf(fal.recoil_pitch-.2*exp(-9.0*1.3*.1))<.00001,"FAL recovery rate increases30percent without touching fire cadence")
	var spr=rack.weapons[13];spr.reset_weapon();spr._kick_recoil(.052,deg_to_rad(5.5));check(spr._recovery_start>deg_to_rad(5.5),"SPR receives modest extra bounce")
	print("SUSTAINED_RECOIL_CSV=",ProjectSettings.globalize_path("user://sustained-recoil-production.csv"))
	print("SUSTAINED_RECOIL_089 checks=",checks," failures=",failures," actual_production_fire=true rendered=false wrist_removed=false headset_tested=false")
	rack.shutdown();rack.free();actor.free();await create_timer(.2).timeout;quit(failures)
