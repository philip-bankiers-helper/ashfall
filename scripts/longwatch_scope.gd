extends Node3D
## Original bounded 2x Longwatch picture-in-picture optic. Never changes the HMD.
## A single shared view is rendered only while physically aligned; stereo optics
## and sustained frame cost still require headset acceptance.
const MAGNIFICATION:=2.0
const LIVE_WEAPON_LAYER:=1<<18
const OPTIC_LAYER:=1<<19
const LENS_RADIUS:=.024
const RESOLUTION:=384
const RENDER_INTERVAL:=1.0/30.0
const OCULAR:=Vector3(0,.151,.065)
var gun:Node3D
var viewport:SubViewport
var scope_camera:Camera3D
var lens:MeshInstance3D
var active:=false
var _elapsed:=0.0
var _material:ShaderMaterial
var _headless:=false
var _displayed_valid:=false
var _displayed_pose:=Transform3D.IDENTITY

static func magnified_fov(base_degrees:float,magnification:float)->float:
	return rad_to_deg(2.0*atan(tan(deg_to_rad(base_degrees)*.5)/maxf(magnification,1.0)))

static func physical_lens_fov(radius:float,eye_relief:float,magnification:float=2.0)->float:
	# A viewport texture occupies the physical lens, not the full HMD display.
	# tan(apparent_angle) / tan(world_angle) is the requested magnification.
	if not is_finite(radius) or not is_finite(eye_relief) or not is_finite(magnification) or radius<=0 or eye_relief<=0 or magnification<=0:
		return rad_to_deg(2.0*atan(.024/(.16*2.0)))
	return rad_to_deg(2.0*atan(maxf(radius,.0001)/(maxf(eye_relief,.001)*maxf(magnification,1.0))))

func _eye_relief()->float:
	return absf((gun.camera.global_position-lens.global_position).dot(lens.global_basis.z.normalized()))

func setup(owner_gun:Node3D)->void:
	gun=owner_gun
	name="OriginalLongwatchTwoPowerOptic"
	_headless=DisplayServer.get_name()=="headless"
	_build_geometry()
	# Viewport is outside model: inert ground clones cannot acquire cameras.
	viewport=SubViewport.new();viewport.name="BoundedOpticalView"
	viewport.size=Vector2i(RESOLUTION,RESOLUTION)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.handle_input_locally=false
	viewport.msaa_3d=Viewport.MSAA_DISABLED
	gun.add_child(viewport)
	viewport.world_3d=gun.get_world_3d()
	scope_camera=Camera3D.new();scope_camera.name="WeaponAlignedOpticalCamera"
	scope_camera.keep_aspect=Camera3D.KEEP_HEIGHT
	# Rack setup happens before the gun is posed into its tracked hand. That
	# arbitrary distance can produce a FOV below Camera3D's legal1-degree limit.
	# Use a valid inactive nominal projection until an aligned frame is committed.
	scope_camera.fov=physical_lens_fov(LENS_RADIUS,.16,MAGNIFICATION)
	scope_camera.near=.05;scope_camera.far=220.0
	scope_camera.cull_mask=1 # Live weapon19 and lens20 are excluded; world remains visible.
	viewport.add_child(scope_camera);scope_camera.current=true
	_material.set_shader_parameter("optical_view",viewport.get_texture())
	_elapsed=RENDER_INTERVAL
	set_process(false) # Owning gun dispatches once, after its current pose is applied.

func _build_geometry()->void:
	var alloy:=StandardMaterial3D.new();alloy.albedo_color=Color("222c31");alloy.metallic=.75;alloy.roughness=.34
	var glass:=StandardMaterial3D.new();glass.albedo_color=Color("071013");glass.roughness=.12
	for z in [-.035,-.245]:
		var mount:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.045,.055,.035)
		mount.mesh=box;mount.position=Vector3(0,.103,z);mount.material_override=alloy;add_child(mount)
	for item in [[.025,.30,-.09],[.031,.055,.035],[.034,.06,-.265]]:
		var tube:=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=item[0];mesh.bottom_radius=item[0];mesh.height=item[1];mesh.radial_segments=20
		tube.mesh=mesh;tube.rotation.x=PI*.5;tube.position=Vector3(0,.151,item[2]);tube.material_override=alloy;add_child(tube)
	var disk:=MeshInstance3D.new();var face:=CylinderMesh.new();face.top_radius=LENS_RADIUS;face.bottom_radius=LENS_RADIUS;face.height=.001;face.radial_segments=24
	disk.mesh=face;disk.rotation.x=PI*.5;disk.position=OCULAR;disk.material_override=glass;add_child(disk)
	var turret:=MeshInstance3D.new();var knob:=CylinderMesh.new();knob.top_radius=.016;knob.bottom_radius=.016;knob.height=.022;knob.radial_segments=12
	turret.mesh=knob;turret.position=Vector3(0,.184,-.12);turret.material_override=alloy;add_child(turret)
	lens=MeshInstance3D.new();lens.name="DynamicScopeLens";var quad:=QuadMesh.new();quad.size=Vector2.ONE*LENS_RADIUS*2.0
	lens.mesh=quad;lens.position=OCULAR+Vector3(0,0,.001);lens.layers=OPTIC_LAYER
	lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D optical_view : source_color, filter_linear;
uniform vec2 eye_shift = vec2(0.0);
void fragment(){
 vec2 p=UV*2.0-1.0;
 float r=length(p+eye_shift);
 if(length(p)>1.0) discard;
 vec3 image=texture(optical_view,UV).rgb;
 float edge=1.0-smoothstep(0.78,1.0,r);
 float h=step(abs(p.y),0.004)*step(abs(p.x),0.88);
 float v=step(abs(p.x),0.004)*step(abs(p.y),0.88);
 ALBEDO=mix(image*edge,vec3(0.005),max(h,v)*edge);
}"""
	_material=ShaderMaterial.new();_material.shader=shader;lens.material_override=_material;add_child(lens);lens.hide()
	for part in find_children("*","MeshInstance3D",true,false):
		if part!=lens:part.layers=LIVE_WEAPON_LAYER

func alignment_allowed()->bool:
	if not is_instance_valid(gun) or not gun.is_visible_in_tree() or not gun.model.is_visible_in_tree() or not gun._input_allowed():return false
	if gun.camera==null or not gun.camera.is_inside_tree():return false
	if not gun.camera.global_transform.is_finite() or not global_transform.is_finite():return false
	if gun._vr_active() and (not gun._hand_input_ready(gun.right_hand) or gun._weapon_hand_climbing()):return false
	if gun.player.get("head_obstructed")==true:return false
	var eye:Vector3=to_local(gun.camera.global_position)-OCULAR
	if eye.z<.045 or eye.z>.55 or Vector2(eye.x,eye.y).length()>.075:return false
	if (-gun.camera.global_basis.z).dot(-global_basis.z)<.96:return false
	# A magnifier cannot see around cover between the eye and its objective.
	var objective:=to_global(Vector3(0,.151,-.32))
	var exclude:Array[RID]=[]
	if gun.player is CollisionObject3D:exclude.append(gun.player.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(gun.camera.global_position,objective,1|8,exclude)
	return gun.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func refresh_optic(delta:float)->void:
	active=alignment_allowed()
	lens.visible=active
	if not active:
		shutdown();_elapsed=RENDER_INTERVAL;return
	_elapsed+=delta
	if not _headless and _elapsed>=RENDER_INTERVAL:
		_elapsed=fmod(_elapsed,RENDER_INTERVAL);_commit_displayed_frame()
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	else:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	# Held texture and firing authority must remain the same snapshot between updates.
	if _displayed_valid:gun.publish_displayed_aim(_displayed_pose)

func _commit_displayed_frame()->void:
	# Read the live candidate only when requesting its matching new optical frame.
	# Reading get_firing_pose here would feed the old displayed snapshot back into itself.
	var shot_pose:Transform3D=gun.get_visual_reticle_pose_071(gun.get_shot_transform())
	scope_camera.fov=physical_lens_fov(LENS_RADIUS,_eye_relief(),MAGNIFICATION)
	var shot_origin:Vector3=shot_pose.origin if gun._vr_active() else gun.camera.global_position
	_displayed_pose=Transform3D(shot_pose.basis,shot_origin);_displayed_valid=true
	var target:Vector3=shot_origin-shot_pose.basis.z*180.0
	var extra:Array=[]
	if gun.player is CollisionObject3D:extra.append(gun.player.get_rid())
	var ray=load("res://scripts/ballistic_query.gd").create(get_tree(),shot_origin,target,extra)
	var hit:=gun.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():target=hit.position
	scope_camera.global_position=to_global(Vector3(0,.151,-.32))
	if scope_camera.global_position.distance_to(target)>.1:scope_camera.look_at(target,shot_pose.basis.y)
	var eye:Vector3=to_local(gun.camera.global_position)-OCULAR
	_material.set_shader_parameter("eye_shift",Vector2(eye.x,eye.y)/.075)
	gun.publish_displayed_aim(_displayed_pose)

func get_displayed_pose()->Dictionary:
	return {"valid":active and _displayed_valid,"pose":_displayed_pose}

func simulate_displayed_frame_for_test()->bool:
	if not _headless or not alignment_allowed():return false
	active=true;lens.show();_commit_displayed_frame();_elapsed=0
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	return true

func _process(delta:float)->void:
	if viewport!=null:refresh_optic(delta)

func shutdown()->void:
	active=false
	if _displayed_valid and is_instance_valid(gun):
		gun._displayed_pose_valid=false;gun._external_aim_publication=false
	_displayed_valid=false
	if lens!=null:lens.hide()
	if viewport!=null:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
