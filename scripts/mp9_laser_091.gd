extends Node3D
## Physical red beam follows the authoritative firing muzzle, clipped by ballistics.
var gun:Node3D
var visual:=MeshInstance3D.new()
var mesh:=ImmediateMesh.new()
func setup(owner_gun:Node3D)->void:
	gun=owner_gun;process_priority=95;visual.mesh=mesh;visual.top_level=true;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(1,.012,.008,.8);mat.emission_enabled=true;mat.emission=Color(1,.01,.005);mat.emission_energy_multiplier=2;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;visual.material_override=mat
func _process(_delta:float)->void:
	visual.hide();mesh.clear_surfaces()
	if not gun.is_visible_in_tree() or not gun._input_allowed() or gun._weapon_hand_climbing() or gun.player.head_obstructed:return
	if gun._vr_active() and not gun._hand_input_ready(gun.right_hand):return
	var pose:Transform3D=gun.get_visual_reticle_pose_071(gun.get_shot_transform());gun.publish_displayed_aim(pose);var start:=pose.origin;var finish:=start-pose.basis.z*180
	var excluded:Array=[gun.player.get_rid()]
	var blocked:=get_world_3d().direct_space_state.intersect_ray(preload("res://scripts/ballistic_query.gd").create(get_tree(),gun.camera.global_position,start,excluded))
	if not blocked.is_empty():return
	var hit:=get_world_3d().direct_space_state.intersect_ray(preload("res://scripts/ballistic_query.gd").create(get_tree(),start,finish,excluded))
	if not hit.is_empty():finish=hit.position
	var side:Vector3=(finish-start).normalized().cross(gun.camera.global_position-start).normalized()*.0012
	if side.length_squared()<.0000001:side=pose.basis.x*.0012
	visual.global_transform=Transform3D.IDENTITY;mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [start-side,start+side,finish+side,start-side,finish+side,finish-side]:mesh.surface_add_vertex(point)
	mesh.surface_end();visual.show()
