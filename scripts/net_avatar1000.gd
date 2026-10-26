extends StaticBody3D
## Remote poses are visual only. Local XR tracking is never written by networking.
var peer_id =0
var session:Node
var bridge:Node
var target:Dictionary={}
var head:Node3D
var left:Node3D
var right:Node3D
var body:MeshInstance3D
var tag:Node3D
var title:Label3D
var pools:Label3D
var health_bar:MeshInstance3D
var shield_bar:MeshInstance3D
var gun:Node3D
var _catalog =-2
var _initialized =false
var actor:Node3D
var suit:Node3D
var gloves:Array=[]
var _style=-1
func setup(id:int,net:Node,adapter:Node)->void:
	peer_id=id;session=net;bridge=adapter;name="RemotePlayer%d"%id
	collision_layer=4;collision_mask=0
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.27;capsule.height=1.75;shape.shape=capsule;shape.position.y=.9;add_child(shape)
	head=Camera3D.new();add_child(head);head.current=false;_part(head,Vector3(.19,.23,.20),Vector3.ZERO,Color("8daeb6"),true)
	left=Node3D.new();right=Node3D.new();add_child(left);add_child(right)
	for i in 2:
		var hand:Node3D=left if i==0 else right
		var wrapper:=Node3D.new();wrapper.name="ArticulatedGlove";hand.add_child(wrapper);wrapper.basis=preload("res://scripts/weapon.gd").corrected_grip_transform(Transform3D.IDENTITY).basis
		var glove:=preload("res://scripts/grip_hand_086.gd").new();wrapper.add_child(glove);glove.setup(i==0);gloves.append(glove)
	actor=preload("res://scripts/remote_actor1000.gd").new();add_child(actor);actor.left_hand=left;actor.right_hand=right;actor.view=head
	suit=preload("res://scripts/player_body.gd").new();add_child(suit);suit.setup(actor);body=suit.pieces.Jacket
	tag=Node3D.new();tag.name="FriendlyTagThroughWalls";add_child(tag)
	title=_text("",Vector3(0,.18,0),36,Color.WHITE);pools=_text("",Vector3(0,.065,0),22,Color.WHITE)
	health_bar=_part(tag,Vector3(.62,.022,.002),Vector3(0,-.015,0),Color("4ceb61"),false)
	shield_bar=_part(tag,Vector3(.62,.022,.002),Vector3(0,-.050,0),Color("28d9ef"),false)
	for bar in [health_bar,shield_bar]:bar.material_override.no_depth_test=true;bar.material_override.render_priority=120
	add_to_group("network_players1000");add_to_group("revivable_allies")
func _part(parent:Node,dimensions:Vector3,point:Vector3,color:Color,depth:bool)->MeshInstance3D:
	var view =MeshInstance3D.new();var mesh =BoxMesh.new();mesh.size=dimensions;view.mesh=mesh;view.position=point
	var mat =StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.7;mat.no_depth_test=not depth
	if not depth:mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	view.material_override=mat;view.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(view);return view
func _text(value:String,point:Vector3,size_value:int,color:Color)->Label3D:
	var t =Label3D.new();t.text=value;t.position=point;t.font_size=size_value;t.pixel_size=.0035;t.modulate=color;t.no_depth_test=true;t.outline_size=6;t.render_priority=122;tag.add_child(t);return t
func _process(delta:float)->void:
	if not session.players.has(peer_id):return
	var p:Dictionary=session.players[peer_id];var data:Dictionary=session.poses.get(peer_id,{})
	if _style!=int(p.get("style",0)):_style=int(p.get("style",0));preload("res://scripts/lobby_map_091.gd").apply_style(suit,_style)
	visible=session.stage in ["lobby","countdown","match","results"] and not p.spectator
	if data.is_empty():return
	var alpha =1.0 if not _initialized else 1.0-exp(-delta*18.0);_initialized=true
	var previous_position:Vector3=global_position;global_transform=global_transform.interpolate_with(data.root,alpha)
	actor.velocity=(global_position-previous_position)/maxf(.001,delta)
	for pair in [[head,"head"],[left,"left"],[right,"right"]]:pair[0].global_transform=pair[0].global_transform.interpolate_with(data[pair[1]],alpha)
	for i in gloves.size():gloves[i].update_pose(float(data.get("grip_left" if i==0 else "grip_right",0)),0.0,{"role":"weapon" if i==1 and not data.holstered else "free","weapon":bridge.game.weapon.weapons[maxi(0,int(data.weapon))]},delta)
	suit.update_pose(delta,true)
	if p.life=="downed":body.rotation.z=PI*.5
	tag.global_position=head.global_position+Vector3.UP*.35
	tag.global_basis=preload("res://scripts/upright_ui.gd").view_basis(bridge.game.player.get_view_camera().global_basis)
	tag.scale=Vector3.ONE*clampf(bridge.game.player.get_view_camera().global_position.distance_to(head.global_position)/5.0,.7,25.0)
	tag.visible=session.allied(session.me(),peer_id) and p.life!="eliminated"
	title.text=p.name+(" · DOWNED" if p.life=="downed" else "")
	pools.text="HP %d   SHIELD %d"%[ceili(float(p.health)),ceili(float(p.shield))]
	health_bar.scale.x=maxf(.001,float(p.health)/100.0);shield_bar.scale.x=maxf(.001,float(p.shield)/100.0)
	health_bar.position.x=-.31*(1-float(p.health)/100.0);shield_bar.position.x=-.31*(1-float(p.shield)/100.0)
	var cat =int(data.weapon)
	if cat!=_catalog:
		_catalog=cat
		if is_instance_valid(gun):gun.queue_free();gun=null
		if cat>=0 and cat<bridge.game.weapon.weapons.size():
			if cat in [11,12]:
				gun=Node3D.new();add_child(gun)
				for source in bridge.game.weapon.weapons[cat].guns:
					var model:Node3D=source.model.duplicate(0);bridge.game.weapon_inventory._strip(model);gun.add_child(model);model.show()
			else:gun=bridge.game.weapon.weapons[cat].model.duplicate(0);bridge.game.weapon_inventory._strip(gun);add_child(gun)
	if is_instance_valid(gun):
		gun.visible=not data.holstered and p.life=="alive"
		if _catalog in [11,12]:
			for i in gun.get_child_count():gun.get_child(i).global_transform=gun.get_child(i).global_transform.interpolate_with(data.get("pair%d"%i,right.global_transform if i==0 else left.global_transform),alpha)
		else:gun.global_transform=gun.global_transform.interpolate_with(data.get("gun_pose",preload("res://scripts/weapon.gd").corrected_grip_transform(right.global_transform)*Transform3D(Basis.IDENTITY.scaled(bridge.game.weapon.weapons[_catalog].model.scale),Vector3.ZERO)),alpha)
func can_revive()->bool:return session.players.has(peer_id) and session.players[peer_id].life=="downed" and session.allied(session.me(),peer_id)
func revive_contacts()->Array:
	return [body.global_position+body.global_basis*Vector3(-.13,.08,.17),body.global_position+body.global_basis*Vector3(.13,.08,.17)]
func revive()->bool:
	if not can_revive():return false
	session.request("revive",{"id":peer_id});return true
func take_damage(_amount:float)->void:pass # All outcomes go through the server bridge.
func take_melee_damage(_amount:float)->void:pass
func get_damage_number_anchor()->Vector3:return head.global_position+Vector3.UP*.2
