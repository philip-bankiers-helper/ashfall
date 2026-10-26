extends RefCounted
## Per-box amounts transcribed from Al's supplied Population One Wiki screenshot.
const AMOUNTS={"pistol":16,"smg":20,"rifle":32,"shells":6,"sniper":5,"builds":6}
const TITLES={"pistol":"PISTOL","smg":"SMG","rifle":"ASSAULT","shells":"SHOTGUN","sniper":"SNIPER","builds":"BUILDS","rockets":"ROCKET"}
const COLORS={"pistol":"477bd4","smg":"a77332","rifle":"9d9c2c","shells":"7f3cc4","sniper":"a83f35","builds":"3f4851","rockets":"d23f86"}
static func model(family:String)->Node3D:
	var root:=Node3D.new();root.name="Supply088_"+family
	var art=preload("res://scripts/field_item_models.gd")
	var color:Color=Color(COLORS.get(family,"58645f"))
	var finish:Material=art.material(color,.35,.58)
	var dark:Material=art.material(Color("1c2529"),.25,.7)
	var pale:Material=art.material(Color("e4e8df"),.15,.55)
	art._box(root,"ColoredSupplyBody",Vector3(.22,.15,.13),Vector3.ZERO,finish,.009)
	art._box(root,"DarkLid",Vector3(.224,.025,.136),Vector3(0,.077,0),dark,.005)
	for x in [-.086,.086]:art._box(root,"CornerBand",Vector3(.012,.15,.135),Vector3(x,0,0),dark,.002)
	for i in 3:art._box(root,"SupplyMark",Vector3(.027,.009,.003),Vector3(-.057,-.035+i*.022,.067),pale,.001)
	if family=="builds":
		for i in 3:art._box(root,"BuildPanel",Vector3(.11,.018,.13),Vector3(.02,.015+i*.026,.01),pale,.003)
	else:
		var glyph:=Sprite3D.new();glyph.texture=load("res://assets/ui/supply_088_%s.svg"%family);glyph.pixel_size=.00038;glyph.position=Vector3(.021,.002,.067);root.add_child(glyph)
	return root
static func icon(family:String)->Texture2D:return load("res://assets/ui/supply_088_%s.svg"%family)
