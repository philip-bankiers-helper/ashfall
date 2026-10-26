extends Node3D
const Ballistics = preload("res://scripts/ballistic_query.gd")
## Stereo world-space crosshair, aimed by active weapon, never head gaze.
var actor:Node3D
var rack:Node3D
var game:Node
var hit_position:=Vector3.ZERO
var ray_origin:=Vector3.ZERO
var ray_direction:=Vector3.FORWARD
var last_hit:Dictionary={}
var white_parts:Array[MeshInstance3D]=[]
const WHITE_WORLD_SEPARATION:=0.01
const SIZE_MULTIPLIER:=4.0
const BLACK_INNER_GAP:=0.10
const RED_INNER_GAP:=0.14
var query:=PhysicsRayQueryParameters3D.new()
var obstruction:=PhysicsRayQueryParameters3D.new()
var presentation_query_071:=PhysicsRayQueryParameters3D.new()
var presentation_direction_071:=Vector3.FORWARD
var _paired_children:Array[Node3D]=[]
var _paired_child:=false
var _weapon_override:Node3D
var _hand_override:XRController3D
var _reference_geometry_key:=""
var _reload_symbol:MeshInstance3D
func setup(owner_actor:Node3D,owner_rack:Node3D,owner_game:Node)->void:
	actor=owner_actor; rack=owner_rack; game=owner_game
	process_priority=100
	query.collision_mask=1|4|8
	query.exclude=Ballistics.exclusions(get_tree(),[actor.get_rid()])
	obstruction.collision_mask=1|8
	obstruction.exclude=Ballistics.exclusions(get_tree(),[actor.get_rid()])
	presentation_query_071.collision_mask=query.collision_mask
	presentation_query_071.exclude=query.exclude
	for color in [Color.BLACK,Color(1.0,0.045,0.025)]:
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color=color
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.no_depth_test=true # Entire four-arm plane remains visible across angled contact surfaces.
		# Opaque sorting can overwrite even a depth-disabled arm. Draw after the
		# opaque scene, with deterministic outline then red ordering; alpha stays 1.
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.render_priority=119 if color==Color.BLACK else 120
		# Four separate arms preserve an open exact aim point in both layers.
		var outer:=0.50 if color==Color.BLACK else 0.42
		var inner:=BLACK_INNER_GAP if color==Color.BLACK else RED_INNER_GAP
		var width:=0.10 if color==Color.BLACK else 0.035
		for axis in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			var part:=MeshInstance3D.new()
			part.layers=1<<19 # Main eyes see this; weapon scope view excludes UI/lens layer20.
			var quad:=QuadMesh.new()
			var length:=outer-inner
			quad.size=Vector2(length,width) if axis.x!=0 else Vector2(width,length)
			part.position=Vector3(axis.x,axis.y,0)*(inner+length*0.5)
			part.mesh=quad;part.material_override=material
			part.set_meta("original_mesh",quad);part.set_meta("original_position",part.position)
			if color!=Color.BLACK:white_parts.append(part)
			part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(part)
	visible=false
func _process(_delta:float)->void:update_reticle()
func update_reticle()->void:
	visible=false
	if is_instance_valid(_reload_symbol):_reload_symbol.hide()
	if not _paired_child:
		for child in _paired_children:child.visible=false
	if actor==null or rack==null or game==null:return
	if not actor.xr_enabled or not actor.input_enabled or game.paused or game.dead or game.complete:return
	if rack.is_holstered or rack.is_selecting or rack.weapons.is_empty():return
	var weapon:Node3D=_weapon_override if _paired_child else rack.weapons[rack.selected]
	var reference:Dictionary=preload("res://scripts/reference_response.gd").profile(weapon)
	if reference.is_empty() and not _reference_geometry_key.is_empty():
		for i in 8:
			var part:MeshInstance3D=get_child(i)
			part.mesh=part.get_meta("original_mesh");part.position=part.get_meta("original_position")
		for part in white_parts:(part.material_override as StandardMaterial3D).albedo_color=Color(1.0,.045,.025)
		_reference_geometry_key=""
	if reference.get("shape","")=="laser":return # Each Uzi has its own physical beam.
	if weapon.has_method("allows_world_reticle") and not weapon.allows_world_reticle():return
	if weapon.has_method("get_scope_overlay_active") and weapon.get_scope_overlay_active():return
	if not _paired_child and weapon.has_method("get_reticle_entries"):
		var entries:Array=weapon.get_reticle_entries()
		for i in mini(2,entries.size()):
			if i>=_paired_children.size():
				var child:Node3D=load("res://scripts/aim_reticle.gd").new()
				child._paired_child=true
				get_parent().add_child(child)
				child.setup(actor,rack,game)
				child.set_process(false)
				_paired_children.append(child)
			var child:Node3D=_paired_children[i]
			child._weapon_override=entries[i].weapon
			child._hand_override=entries[i].hand
			child.update_reticle()
		return
	var firing_hand:XRController3D=_hand_override if _paired_child else (actor.get_weapon_hand() if actor.has_method("get_weapon_hand") else actor.right_hand)
	var climbing:bool=actor.weapon_hand_climbing() if not _paired_child and actor.has_method("weapon_hand_climbing") else bool(actor.get("climbing_left" if firing_hand==actor.left_hand else "climbing_right"))
	var anchors=actor.get("_grabs")
	if anchors is Dictionary and anchors.has(firing_hand):climbing=true
	if not actor.is_hand_input_ready(firing_hand) or climbing or actor.head_obstructed:return
	var empty:bool=weapon.reload_state!="ready" or weapon.ammo<=0
	if empty and reference.get("shape","") not in ["bracket","chevron"]:return
	var shotgun:bool=weapon.magazine_size==2
	var displayed_pose:=Transform3D.IDENTITY
	if weapon.has_method("get_shot_transform"):
		var firing_pose: Transform3D = weapon.get_shot_transform()
		# 072: the visible recovery pose is the authoritative shared shot ray.
		if weapon.has_method("get_visual_reticle_pose_071"):
			firing_pose=weapon.get_visual_reticle_pose_071(firing_pose)
		# A bounded optic can retain a rendered frame between refreshes. Keep
		# fire synchronized with that displayed frame instead of an occluded
		# world reticle silently replacing its ray each physics tick.
		if weapon.has_method("get_displayed_optic_pose"):
			var optical: Dictionary = weapon.get_displayed_optic_pose()
			if optical.get("valid",false): firing_pose=optical.pose
		displayed_pose=firing_pose
		ray_origin = firing_pose.origin
		ray_direction = -firing_pose.basis.z.normalized()
	else:
		ray_origin=weapon.to_global(Vector3(0,0.04,-0.65) if shotgun else Vector3(0,0.045,-0.69))
		ray_direction=-weapon.global_basis.z.normalized()
	var camera:Camera3D=actor.get_view_camera()
	obstruction.from=camera.global_position
	obstruction.to=ray_origin
	if not get_world_3d().direct_space_state.intersect_ray(obstruction).is_empty():return
	query.from=ray_origin
	query.to=ray_origin+ray_direction*(40.0 if shotgun else 180.0)
	last_hit=get_world_3d().direct_space_state.intersect_ray(query)
	hit_position=last_hit.position if not last_hit.is_empty() else query.to
	# A reflex dot and the world crosshair share this exact displayed ballistic ray.
	# Publish even when ADS hides the crosshair, so sustained aim cannot freeze.
	if weapon.has_method("publish_displayed_aim"):weapon.publish_displayed_aim(displayed_pose)
	if weapon.has_meta("ring_sight") and preload("res://scripts/authored_ring_dot_sight.gd").is_viewing_through(weapon.get_meta("ring_sight"),camera):return
	var sight:Node3D=weapon.get_meta("reflex_sight") if weapon.has_meta("reflex_sight") else null
	if is_instance_valid(sight):
		sight.set_aim_target(hit_position)
		if sight.is_viewing_through(camera,hit_position):return
	global_position=hit_position-ray_direction*0.015
	presentation_direction_071=ray_direction
	global_basis=preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis)
	var size:=clampf(camera.global_position.distance_to(global_position)*0.010,0.010,0.60)*SIZE_MULTIPLIER
	scale=Vector3.ONE*size
	if not reference.is_empty():
		var geometry_key:String=str(reference.get("shape","cross"))+str(reference.get("arm_px",21))+str(reference.get("stroke_px",3))
		if geometry_key!=_reference_geometry_key:
			preload("res://scripts/reticle_geometry.gd").rebuild(self,reference);_reference_geometry_key=geometry_key
		var width:float=float(reference.get("supported_rest_px",58.0) if weapon.supported else reference.get("rest_px",70.0))
		if weapon.has_method("get_reference_bloom"):width+=weapon.get_reference_bloom()
		var yellow:bool=empty or reference.get("colour","")=="yellow" or (reference.get("unsupported_yellow",false) and not weapon.supported)
		preload("res://scripts/reticle_geometry.gd").layout(self,reference,width,Color(1,.88,0) if yellow else Color(1.0,.045,.025))
		if empty and reference.get("shape","") in ["bracket","chevron"]:
			if not is_instance_valid(_reload_symbol):
				_reload_symbol=MeshInstance3D.new();_reload_symbol.name="ReloadSymbol"
				_reload_symbol.mesh=preload("res://scripts/reticle_geometry.gd").reload_mesh()
				_reload_symbol.material_override=white_parts[0].material_override.duplicate()
				_reload_symbol.layers=1<<19;_reload_symbol.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(_reload_symbol)
			_reload_symbol.position.z=WHITE_WORLD_SEPARATION/size;_reload_symbol.show()
	# Constant world-space separation avoids scaled micron gaps at near/far ranges.
	# Surface contact is selected by physics; the overlay arms cannot be clipped by that surface.
	for part in white_parts:part.position.z=WHITE_WORLD_SEPARATION/size
	visible=true

func _exit_tree()->void:
	for child in _paired_children:
		if is_instance_valid(child) and not child.is_queued_for_deletion():child.queue_free()




