extends Node3D
## CC0 Godot XR Tools skin/poses; no tracking, collision, aim or grip-ownership authority.
const DIRECTORY:="res://assets/hands/xrtools086/"
var skin:Node3D
var skeleton:Skeleton3D
var poses:Dictionary={}
var side:="left"
var palm_reference:=Vector3.ZERO
func setup(is_left:bool)->void:
	name="SkinnedGlove086";side="left" if is_left else "right"
	skin=load(DIRECTORY+"Hand_Glove_low_%s.gltf"%("L" if is_left else "R")).instantiate();add_child(skin)
	skeleton=skin.find_child("Skeleton3D",true,false)
	var material:=ORMMaterial3D.new();material.albedo_texture=load(DIRECTORY+"textures_glove_caucasian_dark_camo.png");material.orm_texture=load(DIRECTORY+"textures_glove_fingerless_occlusionRoughnessMetallic.png");material.ao_on_uv2=false
	for part in skin.find_children("*","MeshInstance3D",true,false):part.material_override=material;part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var suffix:="_L" if is_left else "_R"
	var wrist:Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("Wrist"+suffix)).origin
	var knuckle:Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("Middle_Proximal"+suffix)).origin
	palm_reference=(wrist+knuckle)*.5
	skin.basis=Basis(Vector3.BACK,-PI*.5 if is_left else PI*.5)
	skin.position=Vector3(0,.032,0)-skin.basis*palm_reference
	for pose in ["Grip 5","Grip","Grip Shaft","Grip 1"]:
		var animation:Animation=load(DIRECTORY+side+"_"+pose+".res");var rotations:Dictionary={}
		for track in animation.get_track_count():
			if animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D:continue
			var path:NodePath=animation.track_get_path(track)
			if path.get_subname_count()>0:rotations[str(path.get_subname(0))]=animation.track_get_key_value(track,0)
		poses[pose]=rotations
	update_pose(0,0,{"role":"free"},1.0)
func update_pose(grip:float,trigger:float,contact:Dictionary,delta:float)->void:
	if skeleton==null:return
	var holding:bool=contact.get("role","free")!="free"
	var profile:String=contact.get("profile","free")
	var weapon:Node3D=contact.get("weapon")
	var id:=str(weapon.get_meta("reference_id","")) if is_instance_valid(weapon) else ""
	var closed:Dictionary=poses["Grip Shaft" if profile=="sword" else ("Grip 1" if id in ["px4","1911","tec9","mp9","magnum","matadors"] else "Grip")]
	var opened:Dictionary=poses["Grip 5"]
	var blend:=1.0-exp(-maxf(delta,0)*22.0)
	for i in skeleton.get_bone_count():
		var bone:=skeleton.get_bone_name(i)
		if not closed.has(bone):continue
		var index:=bone.begins_with("Index_")
		var amount:=clampf(trigger if index else grip,0,1)
		if holding:amount=closure_amount(id,profile,index,amount)
		var start:Quaternion=opened.get(bone,skeleton.get_bone_rest(i).basis.get_rotation_quaternion())
		var target:Quaternion=start.slerp(closed[bone],amount)
		skeleton.set_bone_pose_rotation(i,skeleton.get_bone_pose_rotation(i).slerp(target,blend))
	skeleton.force_update_all_bone_transforms()

static func closure_amount(id:String,profile:String,index:bool,requested:float)->float:
	# Extrapolate along the authored open-to-grip rotation, not an arbitrary bone axis.
	if id=="matadors":return .80 if index else 1.05 # Accepted pose, unchanged.
	if profile=="sword":return .86 if index else 1.12
	if id in ["magnum","tec9"]:return .86 if index else 1.12
	if id=="knife":return .80 if index else 1.05
	if id in ["px4","1911","mp9"]:return .62 if index else .85
	return .54 if index else .74 # Explicit held pose, not overridden by grip=1.
