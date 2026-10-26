class_name AshCampaignExtension
extends RefCounted
## Additive authored geometry. Call only after AshWorld.build().
var mission_positions: Array[Vector3] = [Vector3(0,25.6,-91),Vector3(47,7,-44)]
var jammer_positions: Array[Vector3] = [Vector3(-16,24.6,-91),Vector3(16,24.6,-91)]
var isolator_position := Vector3(43,7.2,-52)
var gate_position := Vector3(47,6,-48)
var exit_position := Vector3(47,6,-44)
var safe_spawns: Array[Vector3] = [Vector3(29,25,-86),Vector3(47,22.4,-77)]
var mission_spawns: Array = [
	[Vector3(-21,24.8,-94),Vector3(-7,24.8,-88),Vector3(7,24.8,-94),Vector3(22,24.8,-88)],
	[Vector3(42,6.2,-72),Vector3(51,6.2,-58),Vector3(43,6.2,-56),Vector3(50,22.2,-73)]
]
var route_waypoints: Dictionary = {
	"crown_entry":PackedVector3Array([Vector3(15,16,-69),Vector3(15,16,-64),Vector3(21,16,-64),Vector3(29,16,-64),Vector3(29,24.6,-85.5),Vector3(29,24.6,-88),Vector3(16,24.6,-88),Vector3(16,24.6,-89),Vector3(16,24.6,-88),Vector3(-16,24.6,-88),Vector3(-16,24.6,-89)]),
	"spillway_entry":PackedVector3Array([Vector3(-16,24.6,-89),Vector3(-16,24.6,-88),Vector3(0,24.6,-88),Vector3(29,24.6,-88),Vector3(29,24.6,-91),Vector3(47,24.6,-91),Vector3(47,24.6,-84.5),Vector3(47,22,-78)]),
	"spillway_stairs":PackedVector3Array([Vector3(47,22,-78),Vector3(52,22,-79),Vector3(56,22,-79),Vector3(58,22,-79),Vector3(58,22,-78),Vector3(58,6,-46),Vector3(52,6,-46),Vector3(52,6,-53),Vector3(43,6,-53),Vector3(43,6,-52)]),
	"spillway_glide":PackedVector3Array([Vector3(47,24.6,-83.5),Vector3(47,22,-70)]),
	"return":PackedVector3Array([Vector3(43,6,-52),Vector3(47,6,-52),Vector3(47,6,-44),Vector3(47,0,-26),Vector3(47,0,-3),Vector3(47,0,20),Vector3(30,0,20),Vector3(8,0,18),Vector3(5,.11,18),Vector3(0,.11,15)])
}
var guard_corridors: Array[PackedVector3Array] = []
var climb_routes: Array = [{"base":Vector3(27,16,-80),"top":Vector3(27,24.6,-86)}]
var built := false
var host: Node3D

func build(host_world: Node3D) -> void:
	if built:return
	assert(host_world.get("built") == true, "Build the base world before extension")
	host=host_world
	_crown_access()
	_crown()
	_spillway()
	_return_route()
	for key in ["crown_entry","spillway_entry","spillway_stairs","return"]:
		guard_corridors.append(route_waypoints[key])
	host._flush_batches()
	built=true

func _deck(center:Vector3,size:Vector3) -> void:
	# Caller specifies walking surface height, not slab center.
	host._platform(center-Vector3.UP*.2,Vector3(size.x,.4,size.z))

func _crown_access() -> void:
	_deck(Vector3(25,16,-64),Vector3(11,0,3))
	_deck(Vector3(26,16,-72),Vector3(3,0,18))
	host._stairs(Vector3(29,16,-64),43,.2,.5,3)
	_deck(Vector3(29,24.6,-87),Vector3(5,0,3))
	# Separate short climbing line with a broad landing; no rail at its mantle.
	_deck(Vector3(27,16,-79),Vector3(3,0,4))
	for x in [26.0,28.0]:
		host._box(Vector3(x,20.1,-80),Vector3(.3,8.2,.3),"orange",true)
		for y in range(17,25):host._box(Vector3(x,y,-79.8),Vector3(.7,.08,.25),"yellow")
	_deck(Vector3(27,24.6,-83),Vector3(2,0,7))
	host._label("DAM CROWN",Vector3(28,18,-63.9),.012,Color(1,.76,.3))

func _crown() -> void:
	# Existing dam crown is the collision floor. Equipment islands leave two lanes.
	for x in [-8.0,0.0,8.0]:
		host._box(Vector3(x,25.65,-91),Vector3(3,2.1,2.2),"steel",true)
		host._box(Vector3(x,26.75,-91),Vector3(3.2,.1,2.4),"trim")
		for z in [-92.14,-89.86]:
			for y in [25.0,25.4,25.8]:host._box(Vector3(x,y,z),Vector3(2.6,.12,.04),"black")
	for x in [-24.0,-12.0,12.0,24.0]:
		host._crate(Vector3(x,25.15,-93.2),Vector3(1.6,1.1,1.2))
	for x in [-16.0,16.0]:
		host._box(Vector3(x,24.64,-91),Vector3(2.6,.08,2.6),"yellow")
		host._pipe(Vector3(x,24.8,-91),Vector3(x,24.8,-88),.06,"orange")
	host._pipe(Vector3(-16,24.8,-88),Vector3(16,24.8,-88),.06,"orange")
	host._rail(Vector3(0,24.6,-95.1),52,false)
	host._label("ARRAY",Vector3(0,28,-91),.018,Color(.5,.88,1))

func _spillway() -> void:
	_deck(Vector3(47,24.6,-88),Vector3(4,0,8))
	# Crown itself extends to x56; this stair begins beyond the dam's front face.
	host._stairs(Vector3(47,22,-78),13,.2,.5,3)
	_deck(Vector3(47,22,-69),Vector3(14,0,20))
	_deck(Vector3(47,6,-65),Vector3(16,0,34))
	_deck(Vector3(52.5,22,-79.5),Vector3(14,0,3))
	host._stairs(Vector3(58,6,-46),80,.2,.4,3)
	_deck(Vector3(52.5,6,-46),Vector3(14,0,4))
	# Structural columns are physical and climbable; open south edge is the glide lip.
	for x in [40.0,54.0]:
		for z in [-78.0,-60.0]:
			host._box(Vector3(x,10,z),Vector3(.5,24,.5),"steel",true)
			host._box(Vector3(x,1,z),Vector3(2,4,2),"concrete",true)
	for z in [-74.0,-66.0]:
		host._cylinder(Vector3(42,8,-absf(z)),1.3,4,"rust",true)
		host._pipe(Vector3(42,10,z),Vector3(42,10,z+5),.35,"rust")
		host._crate(Vector3(52,6.65,z),Vector3(2,1.3,2))
	for x in [42.0,52.0]:
		host._crate(Vector3(x,22.55,-69),Vector3(1.5,1.1,3))
	host._box(Vector3(47,22.04,-59.2),Vector3(8,.08,.3),"yellow")
	host._box(Vector3(47,6.04,-51),Vector3(6,.08,4),"cyan")
	# Narrow gate corridor is visibly walled; keep the device aperture empty.
	for x in [44.5,49.5]:
		host._box(Vector3(x,7.5,-48),Vector3(1,3,6),"concrete",true)
	host._label("SPILLWAY",Vector3(47,24,-59),.016,Color(.4,.86,1))
	host._label("MANUAL RELEASE",Vector3(43,8.4,-52.1),.009,Color(1,.75,.3))
	host.get_child(host.get_child_count()-1).rotation.y=PI
	host._rail(Vector3(40.3,22,-69),19,true)
	host._rail(Vector3(53.7,22,-69),15,true)

func _return_route() -> void:
	_deck(Vector3(47,6,-45.5),Vector3(4,0,3))
	host._stairs(Vector3(47,0,-26),30,.2,.6,4)
	_deck(Vector3(47,0,-3),Vector3(5,0,46))
	_deck(Vector3(38,0,20),Vector3(23,0,5))
	_deck(Vector3(15,0,18),Vector3(30,0,6))
	# Additive apron transition, outside the old route; original apron stays intact.
	host._box(Vector3(7,0,18),Vector3(2.6,.11,2.4),"steel",true,Vector3(0,0,-atan(.055)))
	for z in [-20.0,-4.0,12.0]:
		host._box(Vector3(47,-3,z),Vector3(2,6,2),"concrete",true)
	host._label("EXTRACTION",Vector3(47,2,19),.013,Color(.4,.9,1))

