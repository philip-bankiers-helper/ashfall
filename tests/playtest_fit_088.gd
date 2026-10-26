extends SceneTree
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;print("FAIL ",label)
func base_center(gun:Node3D)->Vector3:
	if gun.has_meta("primary_grip_084"):return gun.get_meta("primary_grip_084")
	if gun.has_method("sample_motion"):return gun.hand_grip_center
	var id:=str(gun.get_meta("reference_id",""))
	if id=="px4":return Vector3(0,-.065,-.13)
	if id=="magnum":return Vector3(0,-.045,-.065)
	if id=="smaw":return gun.hand_grip_center
	return Vector3(0,-.057,.025)
func run()->void:
	ProjectSettings.set_setting("ashfall/lightweight_models",false)
	var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
	var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false);rack.set_physics_process(false)
	var moves:={2:Vector3(0,0,.0381),7:Vector3(0,0,.0381),9:Vector3(0,0,.0381),1:Vector3(0,0,.0381),5:Vector3(0,0,.0381),10:Vector3(0,0,.0381),14:Vector3(0,0,.0381),15:Vector3(0,0,.0381),16:Vector3(0,0,.0381),17:Vector3(0,-.0635,0),19:Vector3(0,-.0254,0),27:Vector3(0,.0254,.0254)}
	for gun in rack.weapons:gun.set_process(false);gun.set_physics_process(false)
	for side in ["right","left"]:
		actor.dominant_hand=side;rack._refresh_hands()
		for index in rack.ACTIVE_WEAPON_INDICES:
			rack.selected=index;rack.is_holstered=false;rack.is_selecting=false;rack._apply_selection()
			var parent:Node3D=rack.weapons[index]
			var list:Array=parent.guns if parent.has_method("get_reticle_entries") else [parent]
			for gun in list:
				gun.show()
				var hand:XRController3D=gun.right_hand
				for roll in [0.0,.8]:
					gun.global_basis=Basis.from_euler(Vector3(.2,.1,roll))
					var raw:Transform3D=hand.global_transform;var shot:Transform3D=gun.get_shot_transform();var before:Transform3D=gun.model.global_transform
					var contact:Dictionary=actor.get_hand_art_contact(hand)
					check(contact.role=="firing",side+" firing contact "+str(index))
					if contact.role!="firing":continue
					var delta:Vector3=(contact.center-base_center(gun))*gun.model.global_basis.get_scale().x
					check(delta.is_equal_approx(moves.get(index,Vector3.ZERO)),side+" exact physical hand offset "+str(index))
					actor.animate_hand(hand,1,.3,.1)
					var rig:Node3D=actor._hand_visuals[hand]
					var local_basis:Basis=gun.model.global_basis.orthonormalized().inverse()*rig.global_basis
					var unroll:=Basis(Vector3.FORWARD,-PI/2.0 if hand==actor.left_hand else PI/2.0).inverse()
					var expected:=Basis(Vector3.RIGHT,deg_to_rad(-35.0)) if index in [1,12,25] else Basis.IDENTITY
					check((local_basis*unroll).is_equal_approx(expected),side+" visual wrist tilt only "+str(index))
					check(rig.global_position.is_equal_approx(gun.model.to_global(contact.center)),"actual rendered glove follows adjusted grip")
					check(gun.get_shot_transform().is_equal_approx(shot) and hand.global_transform==raw and gun.model.global_transform==before,"hand fit never changes bore/weapon/controller")
	actor.dominant_hand="right";rack._refresh_hands()
	var s85:Node3D=rack.weapons[25];s85.show();s85.reset_weapon()
	check(not s85.magazine.visible,"S85 loaded ammunition fully inside receiver")
	s85.eject_magazine();s85._process(0);check(s85.hip_source.visible and not s85.magazine.visible,"S85 offers clip only after eject")
	s85.grab_magazine();s85._process(0);check(s85.loose_magazine.visible,"S85 held clip remains visible")
	check(s85.loose_magazine.global_basis.is_equal_approx(s85.model.global_basis),"S85 carried bullets align with bore rather than controller twist")
	s85.insert_magazine();check(not s85.magazine.visible and not s85.loose_magazine.visible,"S85 clip disappears immediately on insertion")
	for id in [0,21,25]:
		var ring:Node3D=rack.weapons[id].get_meta("ring_sight")
		check(ring.get_meta("floating_rings_088",false),"floating sight assembly installed")
		for part in ring.find_children("*","MeshInstance3D",true,false):
			if "Luminous" in str(part.name) or "FrontAlignment" in str(part.name) or "SolidFrontDot" in str(part.name):check(part.visible,"pink rings and red dot retained")
			else:check(not part.visible,"gray sight supports absent")
	var magnum:Node3D=rack.weapons[7]
	for part in magnum.sight_rear.get_parent().find_children("*","MeshInstance3D",true,false):check(not part.visible,"Magnum added sight meshes removed")
	var m60:Node3D=rack.weapons[8];m60._process(0)
	check(m60.get_box_seat().is_equal_approx(Vector3(-.0493100685,.0151253309,-.0492058127)),"M60 box 3in inward and .75in backward")
	check(m60.belt.position.is_equal_approx(Vector3(.0762,.0254,.01905)),"M60 eight belt rounds move with box and clear feed tray")
	check((m60.belt_feed_grip.position+m60.belt.position).is_equal_approx(m60.get_meta("m60_fit_087").belt_grab),"M60 feed cue follows actual belt without double offset")
	var scope:Node3D=rack.weapons[13].optic
	check(scope.find_children("RecessedOpticFastener088*","MeshInstance3D",false,false).size()==4,"SPR detailed optic fasteners")
	var body=load("res://scripts/player_body.gd").new();root.add_child(body);body.setup(actor);body.set_process(false)
	check(body.get_meta("detailed_arms_088",false) and body.pieces.size()==13,"detailed arms use existing 13 body pose nodes")
	var arm:Mesh=body.pieces.LForearm.mesh
	check(arm.get_faces().size()/3>2500 and arm.get_surface_count()<=4,"smooth tailored forearm, bounded material batches")
	check(body.pieces.LForearm.material_override==null and arm.surface_get_material(0).albedo_texture!=null,"actual arm fabric texture")
	check(is_equal_approx(actor.DEFAULT_PLAYER_TOP_HEIGHT_M,1.8288),"six-foot player top height retained")
	body.free();rack.shutdown();rack.free();actor.free();await process_frame
	print("PLAYTEST_FIT_088 checks=",checks," failures=",failures," xr_off=true headset_acceptance_pending=true");quit(failures)
