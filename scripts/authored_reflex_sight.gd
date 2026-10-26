extends Node3D
## Optional original nonmagnifying sights. Root opts individual weapons into a mount.
## "rings" is concentric alignment + dot; "window" is a transparent rectangle.
## Neither creates a viewport, modifies a camera, or claims a reference gun identity.
const LIVE_WEAPON_LAYER:=1<<18
const WINDOW_LINEAR_SCALE:=1.4142135623730951 # sqrt(2): twice the clear area, same aspect.
const WINDOW_SIZE:=Vector2(.039,.035)*WINDOW_LINEAR_SCALE
const DOT_RADIUS:=.0007 # User prefers the existing solid aiming dot.
const Ballistics=preload("res://scripts/ballistic_query.gd")
var style:="window"
var reticle_parts:Array[MeshInstance3D]=[]
var window:MeshInstance3D
var gun:Node3D
var aim_target:=Vector3.ZERO
var collimated_dot:MeshInstance3D
var _aim_material:ShaderMaterial
func setup(kind:String="window",mount:Transform3D=Transform3D.IDENTITY,owner_gun:Node3D=null)->void:
	gun=owner_gun
	process_priority=101 # After production world-reticle publishes its displayed ray.
	style=kind if kind in ["window","holographic","rings"] else "window"
	transform=mount;name="AuthoredNonmagnifying_"+style
	var metal:=preload("res://scripts/optic_material_094.gd").metal()
	var light:=StandardMaterial3D.new();light.albedo_color=Color("e7b871");light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;light.cull_mode=BaseMaterial3D.CULL_DISABLED
	if style=="rings":
		_ring(.016,.018,0,metal)
		reticle_parts.append(_ring(.011,.0116,.002,light))
		reticle_parts.append(_ring(.0056,.0061,.002,light))
	else:
		var half:=WINDOW_SIZE*.5
		var frame_depth:=.028 if style=="holographic" else .006
		for side in [-1,1]:
			_box(Vector3(WINDOW_SIZE.x+.006,.003,frame_depth),Vector3(0,side*(half.y+.0015),-frame_depth*.4),metal)
			_box(Vector3(.003,WINDOW_SIZE.y,.028 if style=="holographic" else .006),Vector3(side*(half.x+.0015),0,-frame_depth*.4),metal)
		if style=="holographic":
			# Original protected-window housing and rail foot; no borrowed branded mesh.
			_box(Vector3(WINDOW_SIZE.x+.012,.012,.068),Vector3(0,-half.y-.009,-.014),metal)
			_box(Vector3(.034,.008,.052),Vector3(0,-half.y-.019,-.014),metal)
			for side in [-1,1]:
				_box(Vector3(.005,.007,.010),Vector3(side*(half.x+.005),-half.y-.006,.008),metal)
				for z in [-.033,.006]:
					_box(Vector3(.006,.002,.006),Vector3(side*(half.x+.005),-half.y-.002,z),light)
				for i in 5:
					var rib:=_box(Vector3(.0025,.010,.0015),Vector3(side*(half.x+.0028),-.008,-.018+i*.004),metal)
					rib.name="EmbeddedReflexRib094_"+str(side)+"_"+str(i)
			var steel:=StandardMaterial3D.new();steel.albedo_color=Color("6c7477");steel.metallic=.9;steel.roughness=.24
			for x in [-.013,.013]:
				_box(Vector3(.006,.002,.005),Vector3(x,-half.y-.002,.006),steel)
				_box(Vector3(.001,.0025,.004),Vector3(x,-half.y-.0005,.006),metal)
			_box(Vector3(.020,.002,.034),Vector3(0,-half.y-.001,-.012),steel)
		window=MeshInstance3D.new();window.name="ClearSightWindow";var quad:=QuadMesh.new();quad.size=WINDOW_SIZE;window.mesh=quad
		var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.5,.8,.85,.045);glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.cull_mode=BaseMaterial3D.CULL_DISABLED;glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		window.material_override=glass;_add_mesh(window)
	if gun!=null:_build_collimated_dot();update_aim()
	else:
		var dot:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.00065;sphere.height=.0013;dot.mesh=sphere;dot.position.z=.003;dot.material_override=light;_add_mesh(dot);reticle_parts.append(dot)
	set_process(gun!=null)
func _build_collimated_dot()->void:
	collimated_dot=MeshInstance3D.new();collimated_dot.name="DynamicReflexReticle"
	var quad:=QuadMesh.new();quad.size=Vector2(.034,.034) if style=="rings" else WINDOW_SIZE;collimated_dot.mesh=quad;collimated_dot.position.z=.004
	var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded,cull_disabled,fog_disabled,depth_draw_never;
uniform vec3 aim_target_world;
uniform bool circular_window=false;
uniform float dot_radius=0.0007;
varying vec3 fragment_world;
varying vec3 plane_origin;
varying vec3 plane_normal;
void vertex(){
 fragment_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 plane_origin=MODEL_MATRIX[3].xyz;
 plane_normal=normalize((MODEL_MATRIX*vec4(0.0,0.0,1.0,0.0)).xyz);
}
void fragment(){
 vec2 p=UV*2.0-1.0;
 if(circular_window && length(p)>0.88) discard;
 vec3 eye=(INV_VIEW_MATRIX*vec4(EYE_OFFSET,1.0)).xyz;
 vec3 ray=aim_target_world-eye;
 float divisor=dot(ray,plane_normal);
 if(abs(divisor)<0.00001) discard;
 float travel=dot(plane_origin-eye,plane_normal)/divisor;
 if(travel<=0.0 || travel>=1.0) discard;
 vec3 projection=eye+ray*travel;
 float distance_to_aim=length(projection-fragment_world);
 if(distance_to_aim>dot_radius) discard;
 ALBEDO=vec3(1.0,0.19,0.045);ALPHA=1.0;
}"""
	_aim_material=ShaderMaterial.new();_aim_material.shader=shader;_aim_material.set_shader_parameter("circular_window",style=="rings")
	_aim_material.set_shader_parameter("dot_radius",DOT_RADIUS)
	collimated_dot.material_override=_aim_material;_add_mesh(collimated_dot);reticle_parts.append(collimated_dot)
func update_aim()->void:
	if not is_instance_valid(gun):return
	var pose:Transform3D=gun.get_firing_pose()
	var origin:Vector3=pose.origin if gun._vr_active() else gun.camera.global_position
	aim_target=origin-pose.basis.z*180.0
	var extra:Array=[]
	if gun.player is CollisionObject3D:extra.append(gun.player.get_rid())
	var query:=Ballistics.create(get_tree(),origin,aim_target,extra)
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():aim_target=hit.position
	set_aim_target(aim_target)
func set_aim_target(target:Vector3)->void:
	aim_target=target
	if _aim_material!=null:_aim_material.set_shader_parameter("aim_target_world",aim_target)
func project_aim_to_lens(eye:Vector3)->Dictionary:
	return project_target_to_lens(eye,aim_target)
func project_target_to_lens(eye:Vector3,target:Vector3)->Dictionary:
	if collimated_dot==null:return {"valid":false}
	var plane:Transform3D=collimated_dot.global_transform
	var ray:=target-eye;var normal:=plane.basis.z.normalized()
	var divisor:=ray.dot(normal)
	if absf(divisor)<.00001:return {"valid":false}
	var travel:float=(plane.origin-eye).dot(normal)/divisor
	var projected:Vector3=eye+ray*travel;var local:Vector3=plane.affine_inverse()*projected
	var clipped:bool=Vector2(local.x,local.y).length()>.015 if style=="rings" else absf(local.x)>WINDOW_SIZE.x*.5 or absf(local.y)>WINDOW_SIZE.y*.5
	return {"valid":travel>0 and travel<1 and not clipped,"point":projected,"clipped":clipped}
func get_view_eye_poses(view_camera:Camera3D)->Array[Transform3D]:
	# Use the runtime's real stereo views, rather than guessing IPD from head centre.
	var views:Array[Transform3D]=[]
	var interface:=XRServer.primary_interface
	if view_camera is XRCamera3D and interface!=null and interface.is_initialized() and view_camera.get_parent() is XROrigin3D:
		for index in interface.get_view_count():
			views.append(interface.get_transform_for_view(index,view_camera.get_parent().global_transform))
	else:views.append(view_camera.global_transform)
	return views
func is_viewing_through(view_camera:Camera3D,target:Vector3)->bool:
	if view_camera==null or collimated_dot==null or not is_visible_in_tree():return false
	var plane:Transform3D=collimated_dot.global_transform
	for eye in get_view_eye_poses(view_camera):
		var local_eye:Vector3=plane.affine_inverse()*eye.origin
		if local_eye.z<.035 or local_eye.z>.85:continue
		# A lens held in front of the eye must also face the user's view direction.
		if (-eye.basis.z).dot((target-eye.origin).normalized())<cos(deg_to_rad(10.0)):continue
		if project_target_to_lens(eye.origin,target).valid:return true
	return false
func _process(_delta:float)->void:update_aim()
func _add_mesh(mesh:MeshInstance3D)->void:
	mesh.layers=LIVE_WEAPON_LAYER;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(mesh)
func _box(size:Vector3,at:Vector3,material:Material)->MeshInstance3D:
	var part:=MeshInstance3D.new();part.mesh=preload("res://scripts/field_item_models.gd").rounded_box(size,minf(.0012,minf(size.x,minf(size.y,size.z))*.28));part.position=at;part.material_override=material;_add_mesh(part);return part
func _ring(inner:float,outer:float,z:float,material:Material)->MeshInstance3D:
	var part:=MeshInstance3D.new();var mesh:=TorusMesh.new();mesh.inner_radius=inner;mesh.outer_radius=outer;mesh.rings=24;mesh.ring_segments=6;part.mesh=mesh;part.rotation.x=PI*.5;part.position.z=z;part.material_override=material;_add_mesh(part);return part
