extends Node3D
## Fixed backward two-tone readout. Existing label retains the numeric data API.
var label:Label3D
var face:MeshInstance3D
var connector:MeshInstance3D
var dimensions:=Vector2.ZERO
var stacked:=true
var rows:Array[Label3D]=[]
var upper_face:MeshInstance3D
const ROW_HEIGHT:=.022
func setup(number:Label3D)->void:
	label=number
	label.reparent(self)
	label.position=Vector3(0,0,.0018)
	label.rotation=Vector3.ZERO
	label.font_size=26
	label.pixel_size=.00055
	label.outline_size=0
	label.no_depth_test=false
	label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
	label.modulate=Color(1,1,1,0)
	face=MeshInstance3D.new();face.name="NumericPanelFace"
	face.mesh=BoxMesh.new()
	var material:=StandardMaterial3D.new();material.albedo_color=Color("1b252b");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	face.material_override=material;add_child(face)
	upper_face=MeshInstance3D.new();upper_face.name="LoadedBlueFace094";upper_face.mesh=BoxMesh.new();add_child(upper_face)
	var blue:=material.duplicate();blue.albedo_color=Color("008bca");upper_face.material_override=blue
	var font:=FontVariation.new();font.base_font=ThemeDB.fallback_font;font.variation_embolden=.7
	for i in 2:
		var row:=Label3D.new();row.name="LoadedCount094" if i==0 else "ReserveCount094"
		row.font=font;row.font_size=38;row.pixel_size=.00055;row.outline_size=0
		row.modulate=Color.WHITE;row.shaded=false;row.double_sided=false;row.no_depth_test=false
		row.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;row.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		row.position=Vector3(0,ROW_HEIGHT*(.5 if i==0 else -.5)+.0013,.0038);add_child(row);rows.append(row)
	connector=MeshInstance3D.new();connector.name="AmmoPanelHinge"
	var stem:=BoxMesh.new();stem.size=Vector3(.035,.004,.006);connector.mesh=stem
	connector.material_override=material;get_parent().add_child(connector);connector.hide()
func update_display(loaded:int,reserve:int,left_dominant:bool,_viewer:Camera3D)->void:
	stacked=true
	label.text="%d\n%s"%[loaded,str(reserve) if reserve>=0 else "-"]
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	rows[0].text=str(loaded);rows[1].text=str(reserve) if reserve>=0 else "-"
	var width:=.033
	for row in rows:width=maxf(width,row.font.get_string_size(row.text,HORIZONTAL_ALIGNMENT_LEFT,-1,row.font_size).x*row.pixel_size+.004)
	dimensions=Vector2(width,ROW_HEIGHT*2)
	face.mesh.size=Vector3(width,dimensions.y,.0025)
	upper_face.mesh.size=Vector3(width,ROW_HEIGHT,.0026);upper_face.position=Vector3(0,ROW_HEIGHT*.5,.0001)
	var parent_scale:float=maxf(.001,get_parent().global_basis.get_scale().x)
	position=Vector3((.06+width*.5/parent_scale)*(1 if left_dominant else -1),.05,-.14)
	connector.position=Vector3(.0475*(1 if left_dominant else -1),.05,-.14)
	rotation=Vector3.ZERO # Fixed gun-local +Z faces back along the receiver.
	scale=Vector3.ONE/parent_scale # One physical font size across every weapon.

