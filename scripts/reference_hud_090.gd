extends Node3D
## Reference-inspired stacked shield/health meters with real local game state only.
var game:Node
var health:MeshInstance3D
var shield:MeshInstance3D
var health_text:Label3D
var shield_text:Label3D
var builds:Label3D
var status:Label3D
var heading:Node3D
var compass_marks:Array[Label3D]=[]
var notice_background:MeshInstance3D
var death_notice:Label3D
var zone_notice:=""
var death_seconds:=0.0
const WIDTH:=.29
func setup(owner_game:Node)->void:
	game=owner_game
	quad(Vector2(.039,.042),Vector3(.147,-.4445,-.806),Color("374047"))
	notice_background=quad(Vector2(.29,.017),Vector3(-.02,-.411,-.804),Color("d50012"));notice_background.hide()
	status=label("",Vector3(-.02,-.411,-.799),.012);status.hide()
	death_notice=label("",Vector3(-.02,-.389,-.799),.012);death_notice.hide()
	quad(Vector2(WIDTH,.019),Vector3(-.02,-.433,-.804),Color("134757"))
	quad(Vector2(WIDTH,.019),Vector3(-.02,-.456,-.804),Color("17451c"))
	shield=quad(Vector2(WIDTH,.019),Vector3(-.02,-.433,-.802),Color("00a9db"))
	health=quad(Vector2(WIDTH,.019),Vector3(-.02,-.456,-.802),Color("35d400"))
	shield_text=label("",Vector3(-.159,-.4315,-.798),.016)
	shield_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	health_text=label("",Vector3(-.159,-.4545,-.798),.016)
	health_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	builds=label("",Vector3(.145,-.429,-.798),.016)
	for x in 3:
		for y in 3:quad(Vector2(.006,.005),Vector3(.137+x*.007,-.446-y*.006,-.798),Color("e1e7df"))
	heading=Node3D.new();heading.name="ScrollingCompassRose";add_child(heading)
	for step in 24:
		var mark:=label(["N","NE","E","SE","S","SW","W","NW"][step/3] if step%3==0 else "·",Vector3(0,-.482,-.799),.013 if step%3==0 else .009)
		mark.reparent(heading);mark.set_meta("bearing",float(step)*15);compass_marks.append(mark)
func quad(size:Vector2,at:Vector3,color:Color)->MeshInstance3D:
	var mesh:=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.mesh.size=size;mesh.position=at;mesh.layers=1<<19
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.no_depth_test=false;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.render_priority=111 if at.z>=-.802 else 110;mesh.material_override=material;add_child(mesh);return mesh
func label(words:String,at:Vector3,height:float)->Label3D:
	var text:=Label3D.new();text.text=words;text.font_size=30;text.pixel_size=height/30;text.position=at;text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;text.outline_size=1;text.no_depth_test=false;text.render_priority=113;text.outline_render_priority=112;text.layers=1<<19;add_child(text);return text
func refresh()->void:
	if game==null:return
	var h:float=clampf(game.health/100.0,0,1);var s:float=clampf(game.shield/100.0,0,1)
	for pair in [[health,h],[shield,s]]:pair[0].scale.x=maxf(.0001,pair[1]);pair[0].position.x=-.02-WIDTH*(1-pair[1])*.5
	health_text.text=str(roundi(game.health));shield_text.text=str(roundi(game.shield))
	builds.text=str(game.field_builder.charges) if is_instance_valid(game.field_builder) else "0"
	status.text=zone_notice;status.visible=not zone_notice.is_empty();notice_background.visible=status.visible
	var forward:Vector3=-game.player.get_view_camera().global_basis.z
	var degrees:=fposmod(rad_to_deg(atan2(forward.x,-forward.z)),360.0)
	for mark in compass_marks:
		var difference:=wrapf(float(mark.get_meta("bearing"))-degrees,-180,180)
		mark.visible=absf(difference)<=65
		mark.position.x=-.02+difference*.0021
func set_zone_notice(words:String)->void:
	zone_notice=words.strip_edges()
func notify_death(words:String,seconds:float=4.0)->void:
	death_notice.text=words.strip_edges();death_seconds=maxf(0,seconds) if not death_notice.text.is_empty() else 0.0
func tick_notices(delta:float)->void:
	death_seconds=maxf(0,death_seconds-maxf(0,delta));death_notice.visible=death_seconds>0
