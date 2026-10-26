extends "res://scripts/longwatch_scope.gd"
## Broad physical 2x SPR window. Each eye samples its own angular scene.
const WINDOW_SIZE:=Vector2(.055,.0325)
const COMPACT_OCULAR:=Vector3(0,.103,.0185)
var compact_housing098:Node3D
const RETICLE_DEPTH_METRES:=1.0
const RETICLE_REFERENCE_RELIEF:=.20
var right_viewport:SubViewport
var right_scope_camera:Camera3D
var eye_poses:Array[Transform3D]=[]
func _build_geometry()->void:
	super._build_geometry()
	for part in get_children():
		if part is MeshInstance3D and part!=lens:part.hide()
	lens.position=COMPACT_OCULAR
	(lens.mesh as QuadMesh).size=WINDOW_SIZE
	compact_housing098=preload("res://scripts/gemini_scope099.gd").build(self)
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D optical_view : source_color, filter_linear;
uniform sampler2D optical_right : source_color, filter_linear;
uniform vec3 optic_right=vec3(1.0,0.0,0.0);
uniform vec3 optic_up=vec3(0.0,1.0,0.0);
uniform vec3 optic_forward=vec3(0.0,0.0,-1.0);
uniform vec2 tangent_left=vec2(0.1);
uniform vec2 tangent_right=vec2(0.1);
uniform vec2 aim_left=vec2(0.0);
uniform vec2 aim_right=vec2(0.0);
uniform vec3 reticle_center=vec3(0.0);
uniform vec2 reticle_half_extent=vec2(0.1);
uniform int eye_override=-1;
varying vec3 aperture_world;
void vertex(){ aperture_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 // EYE_OFFSET is in view space; include rotation and translation. Raw lens UV
 // would paste the same scene onto a near plane and impose its stereo disparity.
 vec3 eye=(INV_VIEW_MATRIX*vec4(EYE_OFFSET,1.0)).xyz;
 vec3 ray=aperture_world-eye;
 float depth=dot(ray,optic_forward);
 int index=eye_override<0?VIEW_INDEX:eye_override;
 vec2 angular=vec2(dot(ray,optic_right),dot(ray,optic_up))/max(0.0001,depth);
 vec2 extent=index==1?tangent_right:tangent_left;
 vec3 virtual_ray=reticle_center-eye;
 vec2 reticle_angle=vec2(dot(virtual_ray,optic_right),dot(virtual_ray,optic_up))/max(0.0001,dot(virtual_ray,optic_forward));
 vec2 target_angle=(index==1?aim_right:aim_left)*extent;
 vec2 p=((angular-reticle_angle)/2.0+target_angle)/extent;
 vec2 uv=vec2(p.x,-p.y)*0.5+0.5;
 vec3 image=index==1?texture(optical_right,uv).rgb:texture(optical_view,uv).rgb;
 if(depth<=0.0 || any(greaterThan(abs(p),vec2(1.0)))) image=vec3(0.0);
 // Intersect each actual eye's ray with a fixed virtual plane one metre
 // beyond the window. Its disparity no longer places the marking on the glass.
 // Plane distance and physical size never depend on the target range.
 float plane_depth=dot(reticle_center-eye,optic_forward);
 vec3 virtual_hit=eye+ray*(plane_depth/max(depth,0.0001));
 vec3 offset=virtual_hit-reticle_center;
 vec2 aim=vec2(dot(offset,optic_right),dot(offset,optic_up))/reticle_half_extent;
 vec2 circular=aim*vec2(520.0/307.0,1.0);
 float radius=length(circular);
 float ring=1.0-smoothstep(0.004,0.009,abs(radius-0.14));
 float dot=1.0-smoothstep(0.006,0.011,radius);
 float edge=1.0-smoothstep(0.64,1.0,max(abs(UV.x*2.0-1.0),abs(UV.y*2.0-1.0)));
 ALBEDO=mix(image*edge,vec3(0.94,0.055,0.10),max(ring,dot)*edge);
}"""
	_material=ShaderMaterial.new();_material.shader=shader;lens.material_override=_material
func setup(owner_gun:Node3D)->void:
	super.setup(owner_gun)
	viewport.size=Vector2i(520,307)
	right_viewport=SubViewport.new();right_viewport.name="RightEyeSPROpticalView";right_viewport.size=viewport.size
	right_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;right_viewport.world_3d=viewport.world_3d
	right_viewport.handle_input_locally=false;right_viewport.msaa_3d=Viewport.MSAA_DISABLED;gun.add_child(right_viewport)
	right_scope_camera=Camera3D.new();right_scope_camera.name="RightEyeSPROpticalCamera";right_scope_camera.keep_aspect=Camera3D.KEEP_HEIGHT
	right_scope_camera.near=.05;right_scope_camera.far=220;right_scope_camera.cull_mask=1
	right_viewport.add_child(right_scope_camera);right_scope_camera.current=true
	_material.set_shader_parameter("optical_right",right_viewport.get_texture())
func refresh_optic(delta:float)->void:
	#0992 SPR's angular stereo reprojection needs a current eye/scene snapshot on every frame.
	# The AWP keeps its accepted30Hz lens implementation.
	active=alignment_allowed();lens.visible=active
	if active:
		_commit_displayed_frame()
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if _headless else SubViewport.UPDATE_ALWAYS
		if right_viewport!=null:right_viewport.render_target_update_mode=viewport.render_target_update_mode
	else:shutdown()
	var glass:Node3D=compact_housing098.find_child("RearOcularGlass",true,false)
	if glass!=null:glass.visible=not active
func _commit_displayed_frame()->void:
	var pose:Transform3D=gun.get_visual_reticle_pose_071(gun.get_shot_transform())
	var origin:Vector3=pose.origin if gun._vr_active() else gun.camera.global_position
	_displayed_pose=Transform3D(pose.basis.orthonormalized(),origin);_displayed_valid=true
	var target:Vector3=origin-_displayed_pose.basis.z*180.0
	var excluded:Array=[]
	if gun.player is CollisionObject3D:excluded.append(gun.player.get_rid())
	var query=load("res://scripts/ballistic_query.gd").create(get_tree(),origin,target,excluded)
	var hit:=gun.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():target=hit.position
	var optical_basis:=pose.basis.orthonormalized()
	eye_poses=get_eye_poses()
	var left_extent:=_configure_eye(scope_camera,eye_poses[0].origin,optical_basis)
	var right_extent:=_configure_eye(right_scope_camera,eye_poses[mini(1,eye_poses.size()-1)].origin,optical_basis)
	_material.set_shader_parameter("optic_right",optical_basis.x)
	_material.set_shader_parameter("optic_up",optical_basis.y)
	_material.set_shader_parameter("optic_forward",-optical_basis.z)
	_material.set_shader_parameter("reticle_center",reticle_world_center())
	var reference_scale:=1.0+RETICLE_DEPTH_METRES/RETICLE_REFERENCE_RELIEF
	var lens_scale:=lens.global_basis.get_scale()
	_material.set_shader_parameter("reticle_half_extent",WINDOW_SIZE*Vector2(lens_scale.x,lens_scale.y)*.5*reference_scale)
	_material.set_shader_parameter("tangent_left",left_extent)
	_material.set_shader_parameter("tangent_right",right_extent)
	_material.set_shader_parameter("aim_left",_target_uv(scope_camera,target,left_extent))
	_material.set_shader_parameter("aim_right",_target_uv(right_scope_camera,target,right_extent))
	gun.publish_displayed_aim(_displayed_pose)
func reticle_world_center()->Vector3:
	var forward:Vector3=-_displayed_pose.basis.z if _displayed_valid else -gun.get_shot_transform().basis.z
	var pose:Transform3D=_displayed_pose if _displayed_valid else gun.get_shot_transform()
	forward=forward.normalized()
	var plane:Vector3=lens.global_position+forward*RETICLE_DEPTH_METRES
	return pose.origin+forward*(plane-pose.origin).dot(forward)
func _configure_eye(view:Camera3D,eye:Vector3,optical_basis:Basis)->Vector2:
	view.global_transform=Transform3D(optical_basis,eye)
	var aspect:=float(viewport.size.x)/float(viewport.size.y)
	var half_height:=.001
	# A symmetric source camera must cover the farthest corner, including an
	# off-axis eye. Its actual FOV is also the shader's sampling normalization.
	for x in [-.5,.5]:
		for y in [-.5,.5]:
			var corner:=view.to_local(lens.to_global(Vector3(WINDOW_SIZE.x*x,WINDOW_SIZE.y*y,0)))
			var depth:=maxf(.001,-corner.z)
			half_height=maxf(half_height,maxf(absf(corner.y),absf(corner.x)/aspect)/(depth*MAGNIFICATION))
	view.fov=clampf(rad_to_deg(2.0*atan(half_height)),1.0,179.0)
	var actual:=tan(deg_to_rad(view.fov)*.5)
	return Vector2(actual*aspect,actual)
func _target_uv(view:Camera3D,target:Vector3,extent:Vector2)->Vector2:
	var local:=view.to_local(target)
	return Vector2(local.x,local.y)/maxf(.001,-local.z)/extent
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
	if is_instance_valid(compact_housing098):
		var glass:Node3D=compact_housing098.find_child("RearOcularGlass",true,false)
		if glass!=null:glass.show()

func alignment_allowed()->bool:
	if not is_instance_valid(gun) or not gun.is_visible_in_tree() or not gun.model.is_visible_in_tree() or not gun._input_allowed():return false
	if gun.camera==null or not gun.camera.is_inside_tree():return false
	if not gun.camera.global_transform.is_finite() or not global_transform.is_finite():return false
	if gun._vr_active() and (not gun._hand_input_ready(gun.right_hand) or gun._weapon_hand_climbing()):return false
	if gun.player.get("head_obstructed")==true:return false
	var eye:Vector3=gun.camera.global_position-lens.global_position
	var axis:Vector3=global_basis.z.normalized()
	var relief:=eye.dot(axis)
	if relief<.05 or relief>.60 or (eye-axis*relief).length()>.085:return false
	if (-gun.camera.global_basis.z.normalized()).dot(-axis)<.96:return false
	var exclude:Array[RID]=[]
	if gun.player is CollisionObject3D:exclude.append(gun.player.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(gun.camera.global_position,to_global(Vector3(0,.103,-.27)),1|8,exclude)
	return gun.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
