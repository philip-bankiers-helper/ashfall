extends Node3D
## Original standalone lobby level, spatially isolated from the active play map.
const Items=preload("res://scripts/field_item_models.gd")
var pedestals:Array[Node3D]=[]
var avatars:Array[Node3D]=[]
func material(color:String,metal:float=.0,glow:bool=false)->StandardMaterial3D:
	var m:StandardMaterial3D=Items.material(Color(color),metal,.48)
	if glow:m.emission_enabled=true;m.emission=Color(color);m.emission_energy_multiplier=1.5
	return m
func box(label:String,size:Vector3,at:Vector3,mat:Material,collision:bool=false)->void:
	Items._box(self,label,size,at,mat,.025)
	if collision:
		var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=size;body.add_child(shape);add_child(body);body.position=at
func build()->void:
	name="StandaloneLobbyMap091"
	var alloy:=material("414b58",.65);var dark:=material("1b2432",.5);var cyan:=material("18e3f0",.2,true);var pink:=material("dc3488",.2,true)
	box("LobbyDeck",Vector3(22,.30,18),Vector3(0,-.15,-2),alloy,true)
	# Collision only: invisible force fields sit inside all four deck edges.
	for spec in [[Vector3(-10.75,5.8,-2),Vector3(.25,12,18)],[Vector3(10.75,5.8,-2),Vector3(.25,12,18)],[Vector3(0,5.8,-10.75),Vector3(22,12,.25)],[Vector3(0,5.8,6.75),Vector3(22,12,.25)]]:
		var field:=StaticBody3D.new();field.name="InvisibleLobbyForceField";field.collision_layer=1;field.collision_mask=1;field.add_to_group("lobby_force_field")
		var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=spec[1];field.add_child(shape);add_child(field);field.position=spec[0]
	for x in [-8.0,8.0]:
		box("DeckPerimeter",Vector3(.12,.12,16),Vector3(x,.12,-2),dark)
		box("DeckLight",Vector3(.035,.035,16),Vector3(x,.19,-2),cyan)
	for z in [-8.0,-4.0,0.0,4.0]:box("DeckSeam",Vector3(16,.005,.018),Vector3(0,.005,z),dark)
	for i in 3:
		var x:float=(i-1)*1.8;var at:=Vector3(x,.70,1.0-absf(x)*.3)
		var pedestal:=Node3D.new();add_child(pedestal);pedestal.position=at;pedestals.append(pedestal)
		Items._cylinder(pedestal,"DisplayPedestal",.83,.3,Vector3.ZERO,dark)
		Items._ring(pedestal,"CyanPedestalRim",.76,.018,Vector3(0,.16,0),cyan)
		var avatar:=make_avatar([1,0,2][i]);pedestal.add_child(avatar);avatar.position.y=.16;avatar.rotation.y=PI;avatars.append(avatar)
	# A new skyline belongs to this lobby scene; no gameplay map/source is repurposed.
	var rng:=RandomNumberGenerator.new();rng.seed=91091
	var facade:=ShaderMaterial.new();facade.shader=preload("res://assets/materials/lobby_facade_091.gdshader")
	for i in 28:
		var x:=rng.randf_range(-40,40);var z:=rng.randf_range(-55,-18);var height:=rng.randf_range(5,25);var width:=rng.randf_range(2,5)
		box("SkylineTower%d"%i,Vector3(width,height,width),Vector3(x,height*.5-2,z),facade)
		for band in 4:
			box("TowerNeonBand",Vector3(width+.025,.10,width+.025),Vector3(x,height*(.2+band*.19)-2,z),cyan if i%3 else pink)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.4;add_child(light)
	for x in [-4.0,4.0]:
		var fill:=OmniLight3D.new();fill.position=Vector3(x,4,-1);fill.light_color=Color("b6e7ff");fill.light_energy=4;fill.omni_range=12;add_child(fill)
static func make_avatar(style:int=0)->Node3D:
	var root:=Node3D.new();root.name="FieldCharacter091"
	var body:=preload("res://scripts/player_body.gd").new();root.add_child(body);body._build();body.set_process(false)
	body.pieces.Jacket.transform=Transform3D(Basis.IDENTITY.scaled(Vector3(1,.55,1)),Vector3(0,1.20,0));body.pieces.ChestPlate.position=Vector3(0,1.24,-.17);body.pieces.Belt.position=Vector3(0,.91,0)
	for s in [-1.0,1.0]:
		var prefix:="L" if s<0 else "R"
		pose_segment(body,prefix+"UpperArm",Vector3(s*.205,1.47,0),Vector3(s*.30,1.20,.015),.105)
		pose_segment(body,prefix+"Forearm",Vector3(s*.30,1.20,.015),Vector3(s*.26,.97,-.04),.085)
		pose_segment(body,prefix+"Thigh",Vector3(s*.105,.91,0),Vector3(s*.12,.51,-.02),.14)
		pose_segment(body,prefix+"Shin",Vector3(s*.12,.51,-.02),Vector3(s*.13,.12,.015),.115)
		body.pieces[prefix+"Boot"].position=Vector3(s*.13,.08,-.03)
		var glove:=preload("res://scripts/grip_hand_086.gd").new();root.add_child(glove);glove.setup(s<0);glove.position=Vector3(s*.26,.94,-.04);glove.rotation=Vector3(0,0,-s*.2)
	var rubber:Material=Items.material(Color("18242e"),.25,.55);var metal:Material=Items.material(Color("4e6070"),.6,.4)
	Items._cylinder(root,"NeckSeal",.061,.10,Vector3(0,1.53,0),rubber)
	var head:=MeshInstance3D.new();head.mesh=SphereMesh.new();head.mesh.radius=.095;head.mesh.height=.24;head.mesh.radial_segments=32;head.mesh.rings=16;head.position=Vector3(0,1.68,0);head.material_override=metal;root.add_child(head)
	Items._box(root,"FieldVisor",Vector3(.168,.070,.045),Vector3(0,1.70,-.080),Items.material(Color("13678a"),.75,.14),.018)
	Items._box(root,"HelmetCrest",Vector3(.15,.065,.17),Vector3(0,1.80,0),rubber,.025)
	apply_style(body,style);root.set_meta("character_style",style);return root
static func pose_segment(body:Node3D,label:String,start:Vector3,finish:Vector3,diameter:float)->void:
	var direction:=finish-start;var facing:=Basis(Quaternion(Vector3.UP,direction.normalized()))
	body.pieces[label].transform=Transform3D(facing.scaled_local(Vector3(diameter,direction.length(),diameter)),(start+finish)*.5)
static func apply_style(body:Node3D,style:int)->void:
	var tint:Color=[Color.WHITE,Color(.55,.68,.94),Color(1.5,1.45,1.3)][clampi(style,0,2)]
	for part in body.pieces.values():
		if not part.has_meta("lobby_original_mesh"):part.set_meta("lobby_original_mesh",part.mesh)
		var original:Mesh=part.get_meta("lobby_original_mesh");var mesh:Mesh=original.duplicate()
		for i in mesh.get_surface_count():
			var mat:=original.surface_get_material(i) as StandardMaterial3D
			if mat!=null and mat.albedo_texture==preload("res://scripts/field_suit_088.gd").fabric():
				var colored:StandardMaterial3D=mat.duplicate();colored.albedo_color=mat.albedo_color*tint;mesh.surface_set_material(i,colored)
		part.mesh=mesh
