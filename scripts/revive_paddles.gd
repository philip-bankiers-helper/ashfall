extends Node3D
## Original solo rescue tool. Two physical contacts revive explicit revivable allies only.
signal feedback(message:String)
const RUB_REACH:=.45 # tolerant electrode approach; still requires hand motion
const FASTEST_CHARGE_SECONDS:=5.5 #089 explicit playtest target
const SLOWEST_CHARGE_SECONDS:=10.0
const CHARGE_DRAIN_SECONDS:=2.5 #093 authored drain; orientation apart, never translation alone
const FULL_CHARGE_SPEED:=.50 # m/s gives the requested fastest charge
const CONTACT_REACH:=.40
const CONTACT_UP:=.90
const CONTACT_FORWARD:=.65
const FACING_DOT:=.20 # about78 degrees from direct facing; authored tolerance
var actor:Node3D
var rack:Node
var selected:=false
var active:=false
var charge:=0.0
var charge_ready:=false
var _separated:=false
var _have_sample:=false
var _previous_left_local:=Vector3.ZERO
var _previous_right_local:=Vector3.ZERO
var _paddles:Array[Node3D]=[]
var _label:Label3D
var _audio:AudioStreamPlayer3D
var successful_revives:=0
var _meter:Node3D
var _fill:MeshInstance3D
var _beep_clock:=0.0
var _shepard:AudioStreamPlayer3D
var _reference099:AudioStreamPlayer3D
var _facing:=false
var completion_events:=0
const READY_WINDOW_SECONDS097:=3.5 #0992 native-PTS full-to-empty reference interval, about3.5s
var ready_remaining097:=0.0
var _charged_arcs097:Node3D

func setup(player:Node3D,weapon_rack:Node)->void:
	actor=player;rack=weapon_rack;rack.revive_provider=self
	for i in 2:
		var paddle:=Node3D.new();paddle.name="RevivePaddleLeft" if i==0 else "RevivePaddleRight";add_child(paddle)
		preload("res://scripts/paddle_visual_089.gd").build(paddle);_paddles.append(paddle)
	_meter=Node3D.new();_meter.name="ReviveChargeMeter";add_child(_meter)
	_label=Label3D.new();_label.font_size=22;_label.pixel_size=.00065;_label.position=Vector3(0,0,.004);_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;_label.no_depth_test=false;_label.layers=1<<19;_label.render_priority=116;_meter.add_child(_label)
	var background:=MeshInstance3D.new();background.mesh=BoxMesh.new();background.mesh.size=Vector3(.29,.023,.003);background.material_override=preload("res://scripts/field_item_models.gd").material(Color("15252b"));_meter.add_child(background)
	_fill=MeshInstance3D.new();_fill.mesh=BoxMesh.new();_fill.mesh.size=Vector3(.286,.021,.002);_fill.position.z=.003;_fill.material_override=preload("res://scripts/field_item_models.gd").material(Color("00a9db"));_meter.add_child(_fill)
	for part in [background,_fill]:
		part.layers=1<<19;part.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;part.material_override.no_depth_test=false;part.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;part.material_override.render_priority=114 if part==background else 115
	_shepard=AudioStreamPlayer3D.new();_shepard.bus="SFX";_shepard.volume_db=-23;_shepard.max_distance=8;_shepard.stream=AshAudioBank.sample("revive_shepard");add_child(_shepard)
	_reference099=AudioStreamPlayer3D.new();_reference099.bus="SFX";_reference099.volume_db=-18;_reference099.max_distance=8;add_child(_reference099)
	_audio=AudioStreamPlayer3D.new();_audio.bus="SFX";_audio.volume_db=-13;add_child(_audio);hide()
	_charged_arcs097=preload("res://scripts/paddle_lightning097.gd").new();add_child(_charged_arcs097);_charged_arcs097.setup(_paddles);_charged_arcs097.hide()
func equip()->bool:
	if not _allowed():return false
	rack._clear_consumable_selection();selected=true;active=true;rack.is_holstered=true;rack._apply_selection();_clear_charge();show()
	feedback.emit("PADDLES | face electrodes together to charge; revive a rescue target" if actor.xr_enabled else "PADDLES | hold right mouse to charge; left click near rescue target")
	return true
func stow()->void:
	selected=false;active=false;_clear_charge();hide()
func toggle()->void:
	if not selected:return
	if active:active=false;_clear_charge();hide()
	elif _allowed():active=true;rack.is_holstered=true;rack._apply_selection();show()
func _allowed()->bool:
	return is_instance_valid(actor) and actor.input_enabled and not actor.inventory_open and not actor.mantling and not actor.head_obstructed and not actor.weapon_hand_climbing()
func _clear_charge()->void:
	charge=0;charge_ready=false;_separated=false;_have_sample=false;_beep_clock=0;_facing=false
	ready_remaining097=0
	if _charged_arcs097!=null:_charged_arcs097.hide()
	if is_instance_valid(_shepard):_shepard.stop()
	if is_instance_valid(_reference099):_reference099.stop()
	if is_instance_valid(_audio):_audio.stop()
func _cue(kind:String)->void:
	if _audio:_audio.stream=AshAudioBank.sample(kind);_audio.play()
func _process(delta:float)->void:
	if not active:return
	tick_ready_window097(delta)
	if not _allowed() or rack.is_selecting:
		hide();_have_sample=false;_shepard.stop();_reference099.stop();return
	show()
	if actor.xr_enabled:
		var left:Node3D=actor.left_hand;var right:Node3D=actor.right_hand
		var valid:bool=actor.is_hand_input_ready(left) and actor.is_hand_input_ready(right) and not actor._grabs.has(left) and not actor._grabs.has(right)
		if not valid:hide();_have_sample=false;_shepard.stop();_reference099.stop();return
		_paddles[0].global_transform=paddle_pose(left)
		_paddles[1].global_transform=paddle_pose(right)
		step_paddle_poses(delta,_paddles[0].global_transform,_paddles[1].global_transform,true)
	else:
		var camera:Camera3D=actor.get_view_camera()
		for i in 2:_paddles[i].global_transform=camera.global_transform*Transform3D(Basis.IDENTITY,Vector3(-.13 if i==0 else .13,-.18,-.42))
		_facing=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		if _facing:_add_charge(maxf(0,delta)/FASTEST_CHARGE_SECONDS)
		else:_drain_charge(delta)
	# Keep charge feedback attached to the actual paddles, independent of actor/world origin.
	var camera:Camera3D=actor.get_view_camera()
	var midpoint:Vector3=(_paddles[0].global_position+_paddles[1].global_position)*.5
	_shepard.global_position=midpoint
	if _facing and not charge_ready:
		if not _shepard.playing:_shepard.play()
	elif _shepard.playing:_shepard.stop()
	_update_reference099(midpoint)
	var view:Basis=preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis)
	_meter.global_transform=Transform3D(view.scaled(Vector3.ONE*2.5),camera.global_position+view*Vector3(-.02,-.350,-.80)*2.5)
	_fill.scale.x=maxf(.0001,charge);_fill.position.x=-.143*(1-charge)
	_beep_clock+=delta
	if charge>0 and not charge_ready and _beep_clock>=lerpf(.85,.22,charge):
		_beep_clock=0;_audio.global_position=midpoint;_audio.stream=AshAudioBank.sample("revive_charge",mini(9,floori(charge*10)));_audio.play()
	_label.text="READY %.1fs"%ready_remaining097 if charge_ready else "CHARGE %d%%"%roundi(charge*100)
	_charged_arcs097.visible=charge_ready
func _add_charge(amount:float)->void:
	if charge_ready:return
	charge=clampf(charge+maxf(0,amount),0,1)
	if charge>=1:
		_audio.global_position=(_paddles[0].global_position+_paddles[1].global_position)*.5
		charge_ready=true;ready_remaining097=READY_WINDOW_SECONDS097;completion_events+=1;_cue("revive_ready_full0992");feedback.emit("PADDLES READY")
		_charged_arcs097.show();_charged_arcs097._process(0)
func _drain_charge(delta:float)->void:
	if charge_ready:return # Fixed rescue window, regardless of paddle pose.
	charge=maxf(0,charge-maxf(0,delta)/CHARGE_DRAIN_SECONDS)
	if charge<1:charge_ready=false
func tick_ready_window097(delta:float)->void:
	if not charge_ready:return
	ready_remaining097=maxf(0,ready_remaining097-maxf(0,delta))
	if ready_remaining097<=0:_clear_charge();feedback.emit("PADDLES RESET")
func step_paddle_poses(delta:float,left:Transform3D,right:Transform3D,valid:bool)->bool:
	return step_contacts(delta,left.origin,right.origin,valid,-left.basis.z.normalized(),-right.basis.z.normalized())

func step_contacts(delta:float,left:Vector3,right:Vector3,valid:bool,left_normal:Vector3=Vector3.ZERO,right_normal:Vector3=Vector3.ZERO)->bool:
	# Per-hand actor-local displacement permits common-mode arm motion while rejecting locomotion.
	if not active or not valid or not _allowed():_have_sample=false;return false
	var relative:=right-left;var distance:=relative.length()
	var left_local:=actor.to_local(left);var right_local:=actor.to_local(right)
	_facing=_faces_together(relative,left_normal,right_normal)
	if not _facing:_drain_charge(delta)
	if _have_sample and not charge_ready and _facing and delta>0 and delta<=.10:
		var left_speed:=left_local.distance_to(_previous_left_local)/delta
		var right_speed:=right_local.distance_to(_previous_right_local)/delta
		# Stronger moving hand sets charge speed; two hands never double the capped rate.
		var speed:=maxf(left_speed,right_speed)
		if speed<=8.0:_add_charge(delta/charge_seconds(speed))
	_previous_left_local=left_local;_previous_right_local=right_local;_have_sample=true
	if not charge_ready:return false
	for target in get_tree().get_nodes_in_group("revivable_allies"):
		if not target.has_method("can_revive") or not target.can_revive():continue
		var pads:Array=target.revive_contacts()
		if pads.size()!=2:continue
		for order in [[0,1],[1,0]]:
			if _contact_contains(target,left,pads[order[0]]) and _contact_contains(target,right,pads[order[1]]) and _clear_line(left,pads[order[0]]) and _clear_line(right,pads[order[1]]):return _revive(target)
	return false
func _clear_line(start:Vector3,finish:Vector3)->bool:
	return rack.inventory._line_clear(start,finish)
func _revive(target:Node)->bool:
	if not charge_ready or not target.revive():return false
	var arcs:Node3D=preload("res://scripts/revive_discharge_fx_091.gd").new();get_parent().add_child(arcs)
	arcs.start(_paddles[0].global_position,_paddles[1].global_position,target.revive_contacts())
	successful_revives+=1
	#0993 multiple allies can use the original ready window; never reset or extend it.
	preload("res://scripts/sound_cues099.gd").play_at(self,"revive_discharge",(_paddles[0].global_position+_paddles[1].global_position)*.5)
	feedback.emit("RESCUE COMPLETE");return true
func desktop_discharge()->bool:
	if not active or actor.xr_enabled or not charge_ready or not _allowed():return false
	var camera:Camera3D=actor.get_view_camera();var forward:Vector3=-camera.global_basis.z
	for target in get_tree().get_nodes_in_group("revivable_allies"):
		if not target.can_revive():continue
		var pads:Array=target.revive_contacts();var point:Vector3=(pads[0]+pads[1])*.5;var offset:=point-camera.global_position
		if offset.length()<=2.0 and offset.normalized().dot(forward)>.93 and _clear_line(camera.global_position,point):return _revive(target)
	return false

func _faces_together(_relative:Vector3,left_normal:Vector3,right_normal:Vector3)->bool:
	# Electrode orientations only. Translation, distance and coincident positions do not matter.
	if left_normal==Vector3.ZERO and right_normal==Vector3.ZERO:return true # Legacy CPU fixtures.
	if not left_normal.is_finite() or not right_normal.is_finite() or left_normal.length_squared()<.000001 or right_normal.length_squared()<.000001:return false
	return left_normal.normalized().dot(right_normal.normalized())<=-FACING_DOT
func _contact_contains(target:Node3D,point:Vector3,pad:Vector3)->bool:
	# Target-local +Z is outward from the chest; enlarge above and in front,
	# while retaining two distinct hand contacts and wall occlusion checks.
	var offset:=target.global_basis.orthonormalized().inverse()*(point-pad)
	return absf(offset.x)<=CONTACT_REACH and offset.y>=-.20 and offset.y<=CONTACT_UP and offset.z>=-.15 and offset.z<=CONTACT_FORWARD


static func charge_seconds(speed:float)->float:
	return lerpf(SLOWEST_CHARGE_SECONDS,FASTEST_CHARGE_SECONDS,clampf(speed/FULL_CHARGE_SPEED,0,1))
func paddle_pose(hand:Node3D)->Transform3D:
	var corrected:=preload("res://scripts/weapon.gd").corrected_grip_transform(hand.global_transform)
	var glove:=hand.get_node_or_null("ArticulatedGlove/SkinnedGlove086")
	if glove==null or glove.skeleton==null:return corrected.translated_local(Vector3(0,0,-.10))
	var suffix:String="_L" if hand==actor.left_hand else "_R"
	var wrist:int=glove.skeleton.find_bone("Wrist"+suffix);var knuckle:int=glove.skeleton.find_bone("Middle_Proximal"+suffix)
	if wrist<0 or knuckle<0:return corrected.translated_local(Vector3(0,0,-.10))
	var w:Vector3=glove.skeleton.to_global(glove.skeleton.get_bone_global_pose(wrist).origin)
	var k:Vector3=glove.skeleton.to_global(glove.skeleton.get_bone_global_pose(knuckle).origin)
	var fingers:Vector3=(k-w).normalized();var up:Vector3=corrected.basis.y
	if absf(up.dot(fingers))>.95:up=corrected.basis.x
	return Transform3D(Basis.looking_at(fingers,up),k+fingers*.055)

func _update_reference099(point:Vector3)->void:
	if _reference099==null:return
	if charge_ready:_reference099.stop();return #Full activation plays once on _audio, without a repeating layer.
	var kind:="revive_ready" if charge_ready else "revive_facing"
	var sound:AudioStreamWAV=preload("res://scripts/reference_audio_099.gd").generic(kind,0)
	if sound==null or (not charge_ready and not _facing):_reference099.stop();return
	_reference099.global_position=point
	_reference099.pitch_scale=1.0 if charge_ready else lerpf(.85,1.15,charge)
	_reference099.volume_db=-14 if charge_ready else -18
	if _reference099.stream!=sound:_reference099.stop();_reference099.stream=sound
	if not _reference099.playing:_reference099.play()
