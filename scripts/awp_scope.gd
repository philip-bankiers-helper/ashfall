extends "res://scripts/longwatch_scope.gd"
## AWP support-grip scope: central magnified window with black surround.
## Per-eye render origins and angular compositor; physical HMD acceptance remains required.
const VIEW_DISTANCE:=.45
const VIEW_RADIUS:=.15
var right_viewport:SubViewport
var right_scope_camera:Camera3D
var eye_poses:Array[Transform3D]=[]
var _physical_lens:MeshInstance3D
var zoom_magnification:=4.0
var _zoom_forward_down:=true
var _zoom_session:=false
static func world_level_basis(forward:Vector3)->Basis:
	# Roll is removed in world space in BOTH stages: the scene camera and its
	# angular compositor. A head-local UV frame rotates the level image again.
	# At the pole no horizon exists; use a fixed world reference, never head roll.
	var up:=Vector3.FORWARD if absf(forward.normalized().dot(Vector3.UP))>.99999 else Vector3.UP
	return Basis.looking_at(forward,up)
func setup(owner_gun:Node3D)->void:
	super.setup(owner_gun)
	viewport.size=Vector2i(768,768)
	right_viewport=SubViewport.new();right_viewport.name="RightEyeOpticalView";right_viewport.size=viewport.size;right_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;right_viewport.world_3d=viewport.world_3d;right_viewport.handle_input_locally=false;gun.add_child(right_viewport)
	right_scope_camera=Camera3D.new();right_scope_camera.name="RightEyeOpticalCamera";right_scope_camera.near=.05;right_scope_camera.far=220;right_scope_camera.cull_mask=1;right_viewport.add_child(right_scope_camera);right_scope_camera.current=true
	_material.set_shader_parameter("optical_right",right_viewport.get_texture())
func zoom_sample(stick:Vector2,scoped:bool,valid:bool)->void:
	if not valid or not scoped or not stick.is_finite():
		zoom_magnification=4.0;_zoom_forward_down=true;_zoom_session=false;return
	if not _zoom_session:
		_zoom_session=true;zoom_magnification=4.0;_zoom_forward_down=stick.y>.25
	if stick.y<.25:_zoom_forward_down=false
	elif stick.y>.7 and absf(stick.x)<.5 and not _zoom_forward_down:
		zoom_magnification=8.0 if zoom_magnification<6.0 else 4.0
		_zoom_forward_down=true;_elapsed=RENDER_INTERVAL
func refresh_optic(delta:float)->void:
	var scoped:=alignment_allowed()
	var vr:bool=gun._vr_active()
	zoom_sample(gun.right_hand.get_vector2("primary") if vr else Vector2.ZERO,scoped,not vr or gun._hand_input_ready(gun.right_hand))
	super.refresh_optic(delta)
	if right_viewport!=null:right_viewport.render_target_update_mode=viewport.render_target_update_mode
func _build_geometry()->void:
	super._build_geometry();_physical_lens=lens;_physical_lens.hide()
	if gun.has_meta("downloaded_model_077"):
		for part in get_children():
			if part is MeshInstance3D:part.hide() # source scope is already in Body
	lens=MeshInstance3D.new();lens.name="AWPCentralScopeAndBlackout"
	var plane:=QuadMesh.new();plane.size=Vector2(4,4);lens.mesh=plane;lens.position=Vector3(0,0,-VIEW_DISTANCE);lens.layers=OPTIC_LAYER
	lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;
uniform sampler2D optical_view : source_color, filter_linear;
uniform sampler2D optical_right : source_color, filter_linear;
uniform vec3 view_right=vec3(1.0,0.0,0.0);
uniform vec3 view_up=vec3(0.0,1.0,0.0);
uniform vec3 view_forward=vec3(0.0,0.0,-1.0);
uniform float angular_scale=0.33333333;
uniform int eye_override=-1;
uniform vec2 aim_left=vec2(0.0);
uniform vec2 aim_right=vec2(0.0);
void vertex(){ POSITION=vec4(VERTEX.xy*0.5,1.0,1.0); }
void fragment(){
 // Inverse projection is the current eye's asymmetric XR projection. No finite
 // lens plane, guessed HMD FOV, screen-size percentage or shared-eye disparity.
 vec4 projected=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,1.0,1.0);
 // Godot multiview folds view_offset.inverse() into each eye projection.
 // Unprojection is a point in combined-camera space, not an eye-relative ray.
 vec3 ray=normalize((INV_VIEW_MATRIX*vec4(normalize(projected.xyz/projected.w-EYE_OFFSET),0.0)).xyz);
 float denominator=max(0.0001,dot(ray,view_forward));
 vec2 angular=vec2(dot(ray,view_right),dot(ray,view_up))/denominator;
 vec2 p=angular/angular_scale;
 float r=length(p);
 int eye=eye_override<0?VIEW_INDEX:eye_override;
 vec2 uv=vec2(p.x,-p.y)*0.5+0.5;
 vec3 colour=eye==1?texture(optical_right,uv).rgb:texture(optical_view,uv).rgb;
 float edge=1.0-smoothstep(0.96,1.0,r);
 vec2 aim=p-(eye==1?aim_right:aim_left);
 float cross=max(step(abs(aim.y),0.004)*step(abs(aim.x),0.90),step(abs(aim.x),0.004)*step(abs(aim.y),0.90));
 ALBEDO=r>=1.0?vec3(0.0):mix(colour*edge,vec3(0.002),cross);
 // Composite after opaque geometry and other scene transparency. With no
 // depth writes an opaque-pass quad can be overwritten by later world draws.
 ALPHA=1.0;
}"""
	_material=ShaderMaterial.new();_material.shader=shader;_material.render_priority=Material.RENDER_PRIORITY_MAX;lens.material_override=_material;gun.camera.add_child(lens);lens.hide()
func alignment_allowed()->bool:
	if not is_instance_valid(gun) or not gun.is_visible_in_tree() or not gun.model.is_visible_in_tree() or not gun._input_allowed():return false
	if gun.camera==null or not gun.camera.is_inside_tree() or gun.player.get("head_obstructed")==true:return false
	if not gun.camera.global_transform.is_finite() or not global_transform.is_finite() or not gun.get_shot_transform().is_finite():return false
	var exclude:Array[RID]=[]
	if gun.player is CollisionObject3D:exclude.append(gun.player.get_rid())
	var barrier:=PhysicsRayQueryParameters3D.create(gun.camera.global_position,gun.get_shot_transform().origin,1|8,exclude)
	if not gun.get_world_3d().direct_space_state.intersect_ray(barrier).is_empty():return false
	if gun._vr_active():
		return gun.supported and gun._hand_input_ready(gun.right_hand) and gun._hand_input_ready(gun.left_hand) and not gun._weapon_hand_climbing() and not gun._support_hand_climbing()
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
func _commit_displayed_frame()->void:
	var pose:Transform3D=gun.get_visual_reticle_pose_071(gun.get_shot_transform())
	scope_camera.fov=physical_lens_fov(VIEW_RADIUS,VIEW_DISTANCE,zoom_magnification)
	var forward:Vector3=-pose.basis.z.normalized()
	var upright:=world_level_basis(forward)
	_displayed_pose=Transform3D(upright,pose.origin);_displayed_valid=true
	# A binocular telescope presents the optical image and reticle at infinity.
	# Real-eye scene origins magnify IPD disparity by4/8 and can force extreme
	# near convergence when the firing ray intersects nearby cover. Use the
	# same muzzle-aligned optical image for both eyes, with current per-eye XR
	# projection retained by the angular compositor. No HMD projection/IPD edits.
	eye_poses=get_eye_poses()
	scope_camera.global_transform=_displayed_pose
	right_scope_camera.fov=scope_camera.fov
	right_scope_camera.global_transform=_displayed_pose
	_material.set_shader_parameter("aim_left",Vector2.ZERO)
	_material.set_shader_parameter("aim_right",Vector2.ZERO)
	var presentation:=world_level_basis(-gun.camera.global_basis.z.normalized())
	_material.set_shader_parameter("view_right",presentation.x)
	_material.set_shader_parameter("view_up",presentation.y)
	_material.set_shader_parameter("view_forward",-presentation.z)
	_material.set_shader_parameter("angular_scale",zoom_magnification*tan(deg_to_rad(scope_camera.fov)*.5))
	gun.publish_displayed_aim(_displayed_pose)
func _target_uv(view:Camera3D,target:Vector3)->Vector2:
	var local:=view.to_local(target)
	return Vector2(local.x,local.y)/maxf(.001,-local.z)/tan(deg_to_rad(view.fov)*.5)
func get_eye_poses()->Array[Transform3D]:
	var result:Array[Transform3D]=[]
	var interface:=XRServer.primary_interface
	if gun.camera is XRCamera3D and interface!=null and interface.is_initialized() and gun.camera.get_parent() is XROrigin3D:
		for index in mini(2,interface.get_view_count()):result.append(interface.get_transform_for_view(index,gun.camera.get_parent().global_transform))
	if result.is_empty():result.append(gun.camera.global_transform)
	return result
func shutdown()->void:
	super.shutdown()
	if right_viewport!=null:right_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	zoom_magnification=4.0;_zoom_forward_down=true;_zoom_session=false
	if _physical_lens!=null:_physical_lens.hide()
func _exit_tree()->void:
	if is_instance_valid(lens):lens.queue_free()
