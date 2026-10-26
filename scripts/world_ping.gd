extends Node3D
## Local single-player world marker. Support Y/B; no networking or gameplay damage.
signal pinged(point:Vector3)
var actor:Node3D
var game:Node
var marker:Label3D
var remaining:=0.0
var blocked:=true
var previous:=false
var last_hand:XRController3D
var query:=PhysicsRayQueryParameters3D.new()
func setup(owner_actor:Node3D,owner_game:Node)->void:
	actor=owner_actor;game=owner_game
	query.collision_mask=1
	marker=Label3D.new()
	marker.text="◇"
	marker.font_size=36;marker.pixel_size=0.001
	marker.modulate=Color(0.1,0.48,1.0)
	marker.outline_modulate=Color(0.005,0.01,0.025)
	marker.outline_size=8
	marker.no_depth_test=false
	add_child(marker);marker.hide()
	process_priority=110
func _process(delta:float)->void:
	if actor==null or game==null:return
	var hand:XRController3D=actor.get_support_hand()
	if hand!=last_hand:
		blocked=true;previous=false;last_hand=hand
	var valid:bool=actor.xr_enabled and actor.input_enabled and not game.paused and not game.dead and not game.complete and actor.is_hand_input_ready(hand)
	if not valid:
		blocked=true;previous=false;marker.hide();return
	var pressed:=hand.is_button_pressed("by_button")
	if blocked:
		if not pressed:blocked=false
	elif pressed and not previous:
		place_from_hand(hand)
	previous=pressed
	remaining=maxf(0,remaining-maxf(delta,0))
	marker.visible=remaining>0
	if marker.visible:
		var camera:Camera3D=actor.get_view_camera()
		marker.global_basis=preload("res://scripts/upright_ui.gd").view_basis(camera.global_basis)
		marker.scale=Vector3.ONE*clampf(camera.global_position.distance_to(marker.global_position)*0.12,0.7,6)
func place_from_hand(hand:XRController3D)->bool:
	var ray:Transform3D=hand.global_transform*Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3.ZERO)
	query.from=ray.origin
	query.to=ray.origin-ray.basis.z*80
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return false
	marker.global_position=hit.position+hit.normal*0.035
	remaining=20.0
	marker.show()
	pinged.emit(hit.position)
	return true
func clear_all()->void:
	remaining=0;blocked=true;previous=false
	if marker!=null:marker.hide()

