extends Node3D
## Independent world-space wake producer; body visibility never hides the wake.
var actor:Node3D
var body:Node3D
var trails:Array[Node3D]=[]
var _diagnostic_left:=0.0
var _was_gliding:=false
func setup(player:Node3D,suit:Node3D)->void:
	actor=player;body=suit;process_priority=113
	for i in 2:
		var trail:=preload("res://scripts/flight_trail0992.gd").new();add_child(trail);trails.append(trail)
func _process(delta:float)->void:
	var valid:bool=actor.input_enabled and actor.gliding and (not actor.xr_enabled or actor.tracking_available)
	for i in trails.size():
		var point:Vector3=body.elbows[i] if body.elbows.size()==2 else actor.get_view_camera().global_position+actor.global_basis*Vector3(-.28 if i==0 else .28,-.30,0)
		trails[i].sample_point(point,delta,valid)
	_diagnostic_left-=delta
	if actor.gliding!=_was_gliding or (actor.gliding and _diagnostic_left<=0):
		print("ELBOW_WAKE0992 glide=",actor.gliding," enabled=",valid," tracked=",actor.tracking_available," elbows=",body.elbows.size()," length=",[trails[0].distance,trails[1].distance]," surfaces=",[trails[0].mesh.get_surface_count(),trails[1].mesh.get_surface_count()])
		_diagnostic_left=5;_was_gliding=actor.gliding
