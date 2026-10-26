extends "res://scripts/weapon.gd"
## Original throw/rocket input. Numeric certainty is recorded in one_star_050.json.
signal explosive_launch(spec:Dictionary)
signal depleted
var profile_id:="frag"
var rocket_reserve:=2 # Instance-local: one chamber + two reloads for its entire lifetime.
var armed:=false
var _throw_previous:=true
var _hand_previous:=Vector3.INF
var _throw_velocity:=Vector3.ZERO
var arc:MeshInstance3D
var arc_mesh:ImmediateMesh
var payload:Node3D
const ARC_HALF_WIDTH:=.042 #50% wider visual cue; trajectory physics/range unchanged.
const ROCKET_MOUTH:=Vector3(0,.045,-.83)
const ROCKET_OFFER:=Vector3(0,.045,-1.15)
const ROCKET_INSERT:=Vector3(0,.045,-.96)
const ROCKET_GRIP:=Vector3(0,-.075,-.3195) # Center of authored tube +.20..-.839, not a world rescale.
const DEFAULT_HAND_CONTACT:=Vector3(0,-.057,.025)
var hand_grip_center:Vector3:
	get:return rocket_grip_point() if profile_id=="smaw" else DEFAULT_HAND_CONTACT
func rocket_grip_point()->Vector3:
	return Vector3(0,-.105,-.55) if has_meta("downloaded_heavy_085") else ROCKET_GRIP
var rocket_offer:Node3D
var rocket_held:Node3D
var rocket_arrow:Node3D
func rocket_offer_point()->Vector3:return ROCKET_OFFER+Vector3.BACK*(.3048/visual_model_scale())
func _rocket_rear_offer_local()->Vector3:return _rocket_local(rocket_offer_point())+Vector3.BACK*.06 # physical6cm extension
func _rocket_local(point:Vector3)->Vector3:return to_local(model.to_global(point)) if model!=null else point
func get_offered_magazine_transform()->Transform3D:
	if profile_id!="smaw":return super.get_offered_magazine_transform()
	return Transform3D(model.global_basis,model.to_global(rocket_offer_point()))
func get_reload_zones()->Array:
	if profile_id!="smaw":return []
	if reload_state=="needs_mag":return [{"position":_rocket_local(rocket_offer_point()),"radius":.18},{"position":_rocket_rear_offer_local(),"radius":.18}]
	if reload_state=="held_mag":return [{"position":_rocket_local(ROCKET_INSERT),"radius":.18}]
	return []
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	super.setup(actor,connect_desktop);magazine_size=1 if profile_id=="smaw" else 2;ammo=magazine_size
func allows_world_reticle()->bool:return profile_id=="smaw"
func _update_support(_delta:float)->void:
	supported=false;_support_weight=0;_release_support_visual()
func _apply_recoil_visual()->void:
	super._apply_recoil_visual()
	# Keep the tracked fist at its normal pose while seating the tube's actual
	# pistol grip in that fist. All reload/muzzle points remain model-relative.
	if profile_id=="smaw":model.position=Vector3(0,0,recoil)+DEFAULT_HAND_CONTACT-rocket_grip_point()*visual_model_scale()
func _process(delta:float)->void:
	super._process(delta)
	for part in [magazine,loose_magazine,hip_source,guide,insertion_arrow,charging_arrow,bolt,firing_carrier,muzzle_flash]:part.hide()
	payload.visible=ammo>0 or profile_id=="smaw"
	if profile_id=="smaw" and ammo_panel!=null:ammo_panel.show();ammo_label.show()
	if profile_id=="smaw":
		rocket_offer.visible=reload_state=="needs_mag" and reserve_rounds()>0 and _input_allowed()
		rocket_offer.global_transform=get_offered_magazine_transform()
		rocket_held.visible=reload_state=="held_mag" and _input_allowed() and (not _vr_active() or _hand_input_ready(left_hand))
		if rocket_held.visible:
			rocket_held.global_transform=Transform3D(model.global_basis,left_hand.global_position if _vr_active() else model.to_global(rocket_offer_point()))
		rocket_arrow.visible=reload_state in ["needs_mag","held_mag"] and _input_allowed() and reserve_rounds()>0
	_update_trajectory()
	if not _vr_active():
		var down:=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if not down:_requires_trigger_release=false
		if profile_id!="smaw":throw_input(down,true,-camera.global_basis.z*7.0)
func _poll_vr()->void:
	var valid:bool=_input_allowed() and _hand_input_ready(right_hand) and not _weapon_hand_climbing() and not player.get("head_obstructed")
	var pose:=corrected_grip_transform(right_hand.global_transform)
	var frame:=Transform3D(player.global_basis,player.get_locomotion_anchor_position())
	var point:Vector3=frame.affine_inverse()*pose.origin
	var dt:=get_process_delta_time()
	if dt>0 and dt<.15 and _hand_previous.is_finite() and point.distance_to(_hand_previous)<.8:
		_throw_velocity=frame.basis*((point-_hand_previous)/dt).limit_length(14)
	else:_throw_velocity=Vector3.ZERO
	_hand_previous=point
	var down:=right_hand.get_float("trigger")>.65 or right_hand.is_button_pressed("trigger_click")
	if profile_id!="smaw":throw_input(down,valid,_throw_velocity);return
	if not valid:_suspend_gestures();return
	if not down:_requires_trigger_release=false
	elif not _requires_trigger_release:fire()
	if not _hand_input_ready(left_hand) or _support_grip_reserved():_suspend_left_gestures();return
	var grip:=left_hand.get_float("grip")>.55 or left_hand.is_button_pressed("grip_click")
	if _resume_grip_release:
		if grip:return
		_resume_grip_release=false
	var local:=model.to_local(left_hand.global_position)
	if reload_state=="needs_mag" and grip and not _grip_previous and (_in_reload_reach(to_local(left_hand.global_position),_rocket_local(rocket_offer_point()),.18) or _in_reload_reach(to_local(left_hand.global_position),_rocket_rear_offer_local(),.18)):grab_magazine()
	elif reload_state=="held_mag":
		# Gun points-Z. Loading from its open end is a+Z push along the bore,
		# with the carried rocket aligned to that bore, never an upward-mag stroke.
		var radial:=Vector2(local.x-ROCKET_INSERT.x,local.y-ROCKET_INSERT.y).length()
		if grip and local.z-_mag_grab_local.z>=required_rocket_insertion_travel() and local.z>=ROCKET_INSERT.z-.035 and local.z<=ROCKET_MOUTH.z+.08 and radial<=.14:insert_magazine()
		elif not grip:_set_stage("needs_mag","")
	_grip_previous=grip
func required_rocket_insertion_travel()->float:
	# Rear pickup extension retains the true grab datum. Require a deliberate
	# positive push that can finish inside the unchanged mouth bounds, with
	# Up to1cm end margin. Central grabs retain14cm in model space.
	# A physical2cm floor keeps rear-edge pickups deliberate and finishable.
	var scale:float=visual_model_scale()
	var room:float=(ROCKET_MOUTH.z+.08-_mag_grab_local.z)*scale
	var margin:float=minf(.01,maxf(0.0,room-.02))
	return minf(.14,maxf(.02/scale,(room-margin)/scale)) #085 at least2cm physical push, room for every accepted rear grab
func grab_magazine()->void:
	if profile_id!="smaw":return
	if reload_state!="needs_mag" or reserve_rounds()==0 or not _input_allowed() or _support_hand_climbing():return
	_mag_grab_local=model.to_local(left_hand.global_position) if left_hand!=null else ROCKET_OFFER
	_set_stage("held_mag","");_haptic(left_hand,.34,.06)
func throw_input(down:bool,valid:bool,velocity:Vector3)->void:
	if not valid or not _input_allowed():armed=false;_throw_previous=true;_requires_trigger_release=true;return
	if not down:
		armed=false;_requires_trigger_release=false
	elif not _throw_previous and not _requires_trigger_release and cooldown<=0 and ammo>0:
		launch_payload(velocity) # Fresh trigger press throws; release only rearms.
	_throw_previous=down
func fire()->void:
	if profile_id!="smaw":return # Grenade press-edge is handled once by throw_input.
	if not _input_allowed() or _requires_trigger_release or _weapon_hand_climbing() or reload_state!="ready" or cooldown>0 or ammo<=0:return
	if _vr_active() and (not _hand_input_ready(right_hand) or player.get("head_obstructed")):return
	var speed:float=load("res://scripts/arsenal_data.gd").tuning().get("rocket_speed",20.0)
	launch_payload(-get_shot_transform().basis.z*speed)
func launch_payload(velocity:Vector3)->void:
	if ammo<=0 or not _input_allowed():return
	var pose:=get_shot_transform()
	var extra:Array[RID]=[]
	if player is CollisionObject3D:extra.append(player.get_rid())
	var wall:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(camera.global_position,pose.origin,1|8,extra))
	if not wall.is_empty():return # No ammo spent and no projectile created through a wall.
	if not velocity.is_finite():return
	var output:=velocity
	if profile_id!="smaw":output=assisted_throw_velocity(output)
	ammo-=1;armed=false;_requires_trigger_release=true;cooldown=.35
	explosive_launch.emit({"kind":profile_id,"origin":pose.origin,"velocity":prepared_velocity(output)})
	_play(load("res://scripts/audio_bank.gd").sample("rocket_launch" if profile_id=="smaw" else "grenade_throw"))
	_haptic(right_hand,.45,.06);update_ammo_display()
	if ammo==0:
		reload_state="needs_mag" if profile_id=="smaw" else "spent"
		if _has_hand_reservation:_reserve_support_hand(false)
		if profile_id!="smaw" or reserve_rounds()==0:depleted.emit()
func insert_magazine()->void:
	if profile_id!="smaw" or reload_state!="held_mag" or not _input_allowed() or _support_hand_climbing():return
	var round_count:=take_reserve(1)
	if round_count==0:return
	ammo=round_count;_seated_rounds=0;_set_stage("ready","");_requires_trigger_release=true
func eject_magazine()->void:pass # No tactical refund of an already loaded disposable rocket.
func _suspend_gestures()->void:
	super._suspend_gestures();armed=false;_throw_previous=true;_hand_previous=Vector3.INF;_throw_velocity=Vector3.ZERO
func reset_weapon()->void:
	rocket_reserve=2;super.reset_weapon();armed=false;_throw_previous=true;_hand_previous=Vector3.INF
func get_shot_transform()->Transform3D:
	return Transform3D(unit_model_basis(),model.to_global(Vector3(0,.045,-.85 if profile_id=="smaw" else -.10)))
func _build_model()->void:
	super._build_model()
	for child in model.get_children():child.hide()
	ammo_label.show();payload=Node3D.new();payload.name="OriginalExplosive_"+profile_id;model.add_child(payload)
	var alloy:=_material(Color("39483e"),.65,.58);var dark:=_material(Color("3b4244"),.55,.6);var band:=_material(Color("d23f86"),.5,.43)
	if profile_id=="smaw":
		load("res://scripts/smaw_tube_065.gd").build(payload,alloy,band)
		_beveled(Vector3(.045,.12,.065),ROCKET_GRIP,dark,.007,payload)
		_beveled(Vector3(.025,.07,.035),Vector3(0,.13,-.40),dark,.004,payload)
		load("res://scripts/explosive_finish_064.gd").launcher(payload)
		rocket_offer=_make_rocket("RocketOffer",alloy,band);rocket_held=_make_rocket("CarriedRocket",alloy,band)
		rocket_arrow=Node3D.new();rocket_arrow.name="PushRocketIntoTube";model.add_child(rocket_arrow);rocket_arrow.position=ROCKET_OFFER+Vector3(.09,.0,0)
		var cue:=_material(Color("ffd17f"),.1,.55)
		_rod(Vector3.ZERO,Vector3(0,0,.24),.0025,cue,8,rocket_arrow)
		for x in [-.025,.025]:_rod(Vector3(0,0,.24),Vector3(x,0,.20),.0025,cue,8,rocket_arrow)
		rocket_offer.hide();rocket_held.hide();rocket_arrow.hide()
		if not preload("res://scripts/asset_quality.gd").lightweight():preload("res://scripts/downloaded_heavy_085.gd").rocket(self)
	else:
		var prop:Node3D=load("res://scripts/explosive_finish_064.gd").grenade(payload,profile_id)
		prop.position=Vector3(0,-.015,-.03)

func _make_rocket(label:String,alloy:Material,band:Material)->Node3D:
	var item:=Node3D.new();item.name=label;add_child(item)
	load("res://scripts/explosive_finish_064.gd").rocket(item,alloy,band)
	return item

func prepared_velocity(value:Vector3)->Vector3:
	if profile_id=="smaw":return value.limit_length(240.0)
	# A press is an aimed throw, not a wrist-speed test. Use exactly the same
	# held aim and 45-degree elevation for the preview and emitted projectile.
	var pose:=get_shot_transform()
	var gravity:float=ProjectSettings.get_setting("physics/3d/default_gravity",9.8)
	var height:=2.0
	if is_instance_valid(player):height=maxf(.0,pose.origin.y-player.global_position.y)
	return load("res://scripts/grenade_ballistics.gd").launch_velocity(-pose.basis.z,height,gravity,pose.basis.x)
func assisted_throw_velocity(value:Vector3)->Vector3:
	if value.length()>=2.0:return value
	var assist:float=load("res://scripts/arsenal_data.gd").tuning().get("grenade_throw_assist",5.0)
	return -get_shot_transform().basis.z*assist+Vector3.UP*1.5
func trajectory_points(origin:Vector3,velocity:Vector3,space:PhysicsDirectSpaceState3D)->PackedVector3Array:
	var points:=PackedVector3Array([origin]);var at:=origin;var speed:=velocity
	var gravity:float=ProjectSettings.get_setting("physics/3d/default_gravity",9.8)
	var excluded:Array[RID]=[]
	if player is CollisionObject3D:excluded.append(player.get_rid())
	var max_time:=float(load("res://scripts/arsenal_data.gd").tuning().get("frag_fuse_seconds",3.5)) if profile_id=="frag" else 6.0
	var elapsed:=0.0
	for i in 100:
		var step:=minf(.06,max_time-elapsed)
		if step<=0:break
		var next:=at+speed*step+Vector3.DOWN*gravity*.5*step*step
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(at,next,1|8,excluded))
		points.append(next if hit.is_empty() else hit.position)
		if not hit.is_empty():break
		speed+=Vector3.DOWN*gravity*step;at=next;elapsed+=step
	return points
func _update_trajectory()->void:
	if arc==null:
		arc=MeshInstance3D.new();arc.name="LargeThrowTrajectory";arc.top_level=true;arc_mesh=ImmediateMesh.new();arc.mesh=arc_mesh;add_child(arc)
		var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=Color("d1a2ff") if profile_id=="zone" else Color("ffd17f");m.cull_mode=BaseMaterial3D.CULL_DISABLED;arc.material_override=m
	arc.visible=profile_id!="smaw" and ammo>0 and reload_state=="ready" and is_visible_in_tree() and model.is_visible_in_tree() and _input_allowed() and not _weapon_hand_climbing() and player.get("head_obstructed")!=true and (not _vr_active() or _hand_input_ready(right_hand))
	arc_mesh.clear_surfaces()
	if not arc.visible:return
	var pose:=get_shot_transform();var v:=_throw_velocity
	if not _vr_active():v=-camera.global_basis.z*7.0
	v=assisted_throw_velocity(v)
	var points:=trajectory_points(pose.origin,prepared_velocity(v),get_world_3d().direct_space_state)
	arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()):
		var tangent:Vector3=(points[i]-points[i-1]).normalized()
		var side:Vector3=tangent.cross(camera.global_position-points[i]).normalized()*ARC_HALF_WIDTH
		for point in [points[i-1]-side,points[i-1]+side,points[i]+side,points[i-1]-side,points[i]+side,points[i]-side]:arc_mesh.surface_add_vertex(point)
	arc_mesh.surface_end()

# Rocket reload zones already derive physical gun-local coordinates from model transforms.
func reload_local_point(world_point:Vector3)->Vector3:return to_local(world_point)
func reload_world_point(local_point:Vector3)->Vector3:return to_global(local_point)

func reload_frame_scale()->float:return 1.0 # Rocket targets already physical gun-local.

func reserve_rounds()->int:
	return rocket_reserve if profile_id=="smaw" else super.reserve_rounds()
func take_reserve(requested:int)->int:
	if profile_id!="smaw":return super.take_reserve(requested)
	var taken:=mini(maxi(0,requested),rocket_reserve);rocket_reserve-=taken;return taken
func refund_rounds(rounds:int)->int:
	return 0 if profile_id=="smaw" else super.refund_rounds(rounds)
func update_ammo_display()->void:
	if profile_id!="smaw":super.update_ammo_display();return
	if ammo_panel==null:return
	ammo_panel.stacked=true;ammo_panel.show();ammo_label.show()
	ammo_panel.update_display(ammo,rocket_reserve,player!=null and right_hand==player.left_hand,camera)
