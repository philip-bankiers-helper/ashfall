class_name AshExtensionDetail
extends RefCounted
## Noncolliding fittings only; build after the validated campaign extension.
var built := false
var host: Node3D

func build(world: Node3D) -> void:
	if built: return
	host = world
	_crown_fittings()
	_spillway_fittings()
	host._flush_batches()
	built = true

func _crown_fittings() -> void:
	# Existing cabinet faces: thin panels, door hinges and identification plates.
	for x in [-8.0, 0.0, 8.0]:
		for side in [-1.0, 1.0]:
			var z: float = -91.0 + side * 1.115
			host._box(Vector3(x,25.7,z),Vector3(.025,1.75,.025),"trim")
			for dx in [-1.32,1.32]:
				for y in [25.0,26.2]:
					host._box(Vector3(x+dx,y,z),Vector3(.08,.14,.045),"trim")
			for dx in [-.16,.16]:
				host._box(Vector3(x+dx,25.65,z+side*.035),Vector3(.045,.24,.06),"black")
	# Protected rear parapet tray, outside both validated movement lanes.
	for z in [-94.55,-94.8]:
		host._box(Vector3(0,25.05,z),Vector3(34,.06,.045),"trim")
	for x in range(-17,18,2):
		host._box(Vector3(x,25.02,-94.675),Vector3(.08,.04,.3),"trim")
	for x in [-16.0,16.0]:
		host._box(Vector3(x,24.70,-92.6),Vector3(.11,.08,3.7),"orange")
		for z in [-93.8,-92.8]:
			host._box(Vector3(x,24.77,z),Vector3(.23,.035,.09),"trim")

func _spillway_fittings() -> void:
	# Pipe saddles and flanges sit inside existing vessel footprints.
	for z in [-74.0,-66.0]:
		for y in [6.45,9.55]:
			host._cylinder(Vector3(42,y,z),1.32,.10,"trim")
		host._pipe_flange(Vector3(42,10,z+2.5),Vector3.FORWARD,.35)
	# Structural base plates remain within the existing physical columns.
	for x in [40.0,54.0]:
		for z in [-78.0,-60.0]:
			host._box(Vector3(x,6.08,z),Vector3(.92,.12,.92),"trim")
			for dx in [-.34,.34]:
				for dz in [-.34,.34]:
					host._box(Vector3(x+dx,6.17,z+dz),Vector3(.08,.08,.08),"steel")
	# Gate frame is on existing concrete walls and above the clear opening.
	for x in [44.5,49.5]:
		host._box(Vector3(x,7.55,-51.025),Vector3(.85,2.95,.05),"steel")
		for y in [6.3,7.5,8.7]:
			host._box(Vector3(x,y,-51.06),Vector3(.65,.08,.045),"yellow")
	host._box(Vector3(47,9.35,-48),Vector3(6,.38,.5),"steel")
	_sign("EXIT",Vector3(47,9.36,-48.27),3.6,.28,PI)
	# The visible conduit links the isolator to the gate motor above head height.
	host._box(Vector3(43,7.78,-52.14),Vector3(.12,3.55,.12),"steel")
	host._box(Vector3(43,6.08,-52.14),Vector3(.42,.12,.42),"trim")
	host._pipe(Vector3(43,8.2,-52),Vector3(43,9.55,-52),.045,"orange")
	host._pipe(Vector3(43,9.55,-52),Vector3(44.5,9.55,-48),.045,"orange")
	host._pipe(Vector3(44.5,9.55,-48),Vector3(47,9.55,-48),.045,"orange")
	host._box(Vector3(47,9.55,-48),Vector3(.55,.45,.45),"trim")

func _sign(text: String, pos: Vector3, width: float, height: float, tilt: float) -> void:
	var rotation := Vector3(0,PI,0) if is_equal_approx(tilt,PI) else Vector3(tilt,0,0)
	host._box(pos,Vector3(width,height,.025),"black",false,rotation)
	var label := Label3D.new()
	label.text=text
	label.font_size=32
	label.pixel_size=minf(width/maxf(text.length()*18.0,1.0),height/40.0)
	label.modulate=Color(.85,.9,.87)
	label.outline_size=0
	label.position=pos+Basis.from_euler(rotation)*Vector3(0,0,.02)
	label.rotation=rotation
	host.add_child(label)



