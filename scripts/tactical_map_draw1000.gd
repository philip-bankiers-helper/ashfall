extends Control
var map:Node
const RECT:=Rect2(310,100,650,650)
func _draw()->void:
	draw_style_box(_panel(),Rect2(0,0,1400,850));var font =ThemeDB.fallback_font
	draw_string(font,Vector2(38,57),"ASHFALL  /  TACTICAL MAP",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("edf6ff"))
	draw_rect(RECT,Color("0c2530"));draw_rect(RECT,Color("337286"),false,2)
	if map.top_image!=null:draw_texture_rect(map.top_image,RECT,false,Color(.7,.8,.85))
	var info:Dictionary=map.Maps.info(map.map_id())
	for i in range(1,10):
		var f =float(i)/10;draw_line(RECT.position+Vector2(RECT.size.x*f,0),RECT.position+Vector2(RECT.size.x*f,RECT.size.y),Color("23434d"));draw_line(RECT.position+Vector2(0,RECT.size.y*f),RECT.position+Vector2(RECT.size.x,RECT.size.y*f),Color("23434d"))
	# Actual world footprints projected north-up; screenshot remains beside this live map.
	var active:Node=map.game.active_sandbox_map
	if is_instance_valid(active) and "buildings" in active:
		for b in active.buildings:
			var center:Vector3=active.global_position+b.center
			var uv:Vector2=map.Maps.uv(map.map_id(),center)
			var scale:Vector2=RECT.size/(info.max-info.min)
			var size_value =Vector2(float(b.width),float(b.depth))*scale
			draw_rect(Rect2(RECT.position+uv*RECT.size-size_value*.5,size_value),Color("3e6373"))
	var session:Node=map.session
	if session.active:
		for id in session.players:
			var p:Dictionary=session.players[id]
			if p.spectator or not session.poses.has(id):continue
			_marker(id,p.name,session.poses[id].root.origin,p.life)
	else:_marker(0,"YOU",map.game.player.global_position,"alive")
	draw_string(font,Vector2(620,85),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
	if session.active:
		for m in session.marks.values():
			var point =RECT.position+map.Maps.uv(map.map_id(),m.point).clamp(Vector2.ZERO,Vector2.ONE)*RECT.size;draw_circle(point,5,Color("ffcf38"))
func _marker(id:int,title:String,position:Vector3,life:String)->void:
	var uv:Vector2=map.Maps.uv(map.map_id(),position);var p =RECT.position+uv.clamp(Vector2.ZERO,Vector2.ONE)*RECT.size
	var color =Color("ffce3c") if id==map.session.me() or not map.session.active else (Color("41deed") if map.session.allied(map.session.me(),id) else Color("ff756e"))
	if life=="alive":draw_circle(p,8,color)
	else:draw_circle(p,8,color,false,2,true)
	draw_string(ThemeDB.fallback_font,p+Vector2(12,-8),title,HORIZONTAL_ALIGNMENT_LEFT,160,18,color)
func _panel()->StyleBoxFlat:
	var s =StyleBoxFlat.new();s.bg_color=Color(.02,.055,.075,.96);s.border_color=Color("32647a");s.set_border_width_all(2);s.set_corner_radius_all(14);return s
