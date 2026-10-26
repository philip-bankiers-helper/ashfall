extends SceneTree
class Provider extends Node:
	var weapons:Array=[]
	var selected:=0
	var is_holstered:=false
	var is_selecting:=false
	func get_hand_grip_pose(_hand:XRController3D)->float:return 1.0
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func run()->void:
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var provider:=Provider.new();root.add_child(provider);actor.sprint_conflict_provider=provider
	for side in ["right","left"]:
		actor.dominant_hand=side
		for path in ["weapon.gd","pistol.gd","compact_smg.gd","pump_shotgun.gd","revolver.gd","shotgun.gd","burst_carbine.gd","precision_rifle.gd","belt_lmg.gd","auto_shotgun.gd","top_feed_pdw.gd"]:
			var gun=load("res://scripts/"+path).new();root.add_child(gun);gun.setup(actor,false);gun.set_process(false);gun.set_physics_process(false)
			gun.global_transform=Transform3D(Basis.IDENTITY,Vector3(0,1.05,-.45));provider.weapons=[gun]
			var hand:XRController3D=gun.right_hand
			var raw:Transform3D=hand.global_transform
			var weaponpose:Transform3D=gun.global_transform
			var art:Node3D=hand.get_node("ArticulatedGlove");art.show()
			actor.animate_hand(hand,0,0,1.0)
			var context:Dictionary=actor.get_hand_art_contact(hand)
			var palm:Node3D=art.get_node("GripSurface/PalmSurface")
			var palmpos:Vector3=gun.model.to_local(palm.global_position)
			var mid:Dictionary=actor._finger_joints[hand][1]
			var tippos:Vector3=gun.model.to_local(mid.contact.global_position)
			var sign_x:=-1.0 if hand==actor.left_hand else 1.0
			var prefix:String=side+" "+path+" "
			check(context.role=="firing",prefix+" actual active weapon resolves firing hand")
			check(absf(palmpos.x-sign_x*.032)<.001,prefix+" palm skin lies on correct grip side")
			check(absf(palmpos.y-context.center.y)<.001 and absf(palmpos.z-context.center.z)<.001,prefix+" palm follows actual family grip center below receiver")
			var has_grip_contact:=false
			for mesh in gun.model.find_children("*","MeshInstance3D",true,false):
				if not mesh.is_visible_in_tree() or mesh.mesh==null:continue
				var start:Vector3=mesh.to_local(gun.model.to_global(Vector3(.06,palmpos.y,palmpos.z)))
				var end:Vector3=mesh.to_local(gun.model.to_global(Vector3(-.06,palmpos.y,palmpos.z)))
				var faces:PackedVector3Array=mesh.mesh.get_faces()
				for f in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(start,end,faces[f],faces[f+1],faces[f+2])!=null:has_grip_contact=true;break
			check(has_grip_contact,prefix+" palm cross-section intersects actual visible grip triangles")
			check(tippos.x*sign_x<0 and absf(tippos.x)<.04,prefix+" curled middle fingertip wraps across front to opposite grip side")
			check(absf(tippos.y-context.center.y)<.045 and absf(tippos.z-context.center.z)<.09,prefix+" actual fingertip remains inside compact grip contact envelope")
			var thumb:Dictionary=actor._finger_joints[hand][4]
			var thumbpos:Vector3=gun.model.to_local(thumb.contact.global_position)
			check(thumbpos.y>palmpos.y-.01,prefix+" mirrored thumb remains above palm rather than below grip")
			check(hand.global_transform.is_equal_approx(raw) and gun.global_transform.is_equal_approx(weaponpose),prefix+" rendered pose never changes raw tracking or weapon aim")
			check(art.find_children("*","CollisionObject3D",true,false).is_empty(),prefix+" no hand input collider introduced")
			check(palm.global_position.distance_to(actor.get_view_camera().global_position)>.25,prefix+" ordinary low-ready grip avoids face envelope")
			gun.supported=true;gun._update_support_visual()
			var off:XRController3D=gun.left_hand;var offraw:Transform3D=off.global_transform
			actor.animate_hand(off,1,0,1.0);gun._update_support_visual()
			var offart:Node3D=off.get_node("ArticulatedGlove")
			var offpalm:Vector3=gun.model.to_local(offart.get_node("GripSurface/PalmSurface").global_position)
			check(actor.get_hand_art_contact(off).role=="support",prefix+" support hand profile resolved")
			check(absf(offpalm.x)>.025 and absf(offpalm.x)<.045,prefix+" snapped support palm remains outside foregrip surface")
			check(off.global_transform.is_equal_approx(offraw),prefix+" support cupping preserves raw offhand")
			actor._grabs[hand]=hand.global_position
			check(actor.get_hand_art_contact(hand).role=="free",prefix+" real wall anchor takes precedence over rendered weapon pose")
			actor._grabs.clear()
			gun._release_support_visual();provider.is_holstered=true;actor.animate_hand(hand,0,0,1)
			check(art.transform.is_equal_approx(art.get_meta("rest_transform")),prefix+" holster restores free-hand local rest")
			provider.is_holstered=false;gun.shutdown();await create_timer(.12).timeout;gun.free();provider.weapons=[]
	var pair=load("res://scripts/dual_pistols.gd").new();root.add_child(pair);pair.setup(actor,false);pair.set_process(false);provider.weapons=[pair]
	for i in range(2):
		var child=pair.guns[i];child.set_process(false);child.global_transform=Transform3D(Basis.IDENTITY,Vector3(.15 if i==0 else -.15,1.05,-.45))
		var hand:XRController3D=child.right_hand;var raw:Transform3D=hand.global_transform
		actor.animate_hand(hand,0,0,1)
		var context:Dictionary=actor.get_hand_art_contact(hand)
		check(context.weapon==child and context.profile=="longgun","dual child%d actual independent compact Uzi grip profile"%i)
		check(hand.get_node("ArticulatedGlove").global_position.distance_to(child.model.to_global(context.center))<.0001,"dual child%d firing palm follows own pistol rather than pair wrapper"%i)
		check(hand.global_transform.is_equal_approx(raw),"dual child%d raw tracking unchanged"%i)
		check(not pair.toggle_stow(i) and actor.get_hand_art_contact(hand).role=="firing","dual child%d remains an occupied Uzi hand without a forced stow gesture"%i)
	pair.shutdown();await create_timer(.2).timeout;pair.free();provider.free();actor.free();await process_frame
	print("GRIP_POSE_CARRY_048 checks=",checks," failures=",failures," synthetic_geometry=true headset_tested=false");quit(failures)
