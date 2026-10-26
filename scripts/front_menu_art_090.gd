extends Control
## Original vector environment artwork, no downloaded menu or game imagery.
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0d1b22"))
	for i in 30:
		var tint:=Color("28434a");tint.a=.015+float(i)*.0007
		draw_circle(Vector2(1120,250),420-i*9,tint)
	for i in 4:
		var ridge:=PackedVector2Array([Vector2(560,800)])
		for x in range(560,1320,34):ridge.append(Vector2(x,360+i*82+sin(x*.011+i*2.1)*58+sin(x*.027+i)*23))
		ridge.append(Vector2(1320,800));draw_colored_polygon(ridge,Color("234047") if i==0 else Color("1a333c") if i==1 else Color("142a33") if i==2 else Color("10232c"))
	# Hydroelectric spillway silhouette echoes the playable valley.
	draw_colored_polygon(PackedVector2Array([Vector2(775,800),Vector2(875,420),Vector2(1135,398),Vector2(1260,800)]),Color("345058"))
	for i in 7:
		var x:=878+i*39;draw_line(Vector2(x,425-i*3),Vector2(793+i*72,800),Color("172e36"),12,true)
	draw_line(Vector2(869,420),Vector2(1146,398),Color("a5b8af"),4,true)
	var tower:=PackedVector2Array([Vector2(1079,400),Vector2(1093,245),Vector2(1108,400)]);draw_polyline(tower,Color("7a9596"),3,true)
	for y in [270,303,337,370]:draw_line(Vector2(1084,y),Vector2(1103,y+12),Color("7a9596"),2,true)
	draw_circle(Vector2(1093,244),4,Color("eab173"))
	for r in [23,42,62]:draw_arc(Vector2(1093,244),r,PI*1.12,PI*1.85,32,Color(.55,.76,.73,.18),1,true)
	draw_line(Vector2(82,69),Vector2(1198,69),Color("3e595f"),1,true)
	draw_line(Vector2(82,699),Vector2(1198,699),Color("3e595f"),1,true)
	draw_rect(Rect2(82,66,64,5),Color("d0a26d"))
