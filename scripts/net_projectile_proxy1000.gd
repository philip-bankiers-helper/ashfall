extends Node
var adapter:Node
var player:Node
var paused =false
var dead =false
var complete =false
var owner_id =0
var cosmetic =false
func setup(bridge:Node,id:int,visual_only:bool)->void:adapter=bridge;player=bridge.game.player if id==bridge.net.me() else bridge.avatars.get(id,bridge.game.player);owner_id=id;cosmetic=visual_only
func apply_explosive_damage(point:Vector3,radius:float,power:float,falloff:bool)->void:
	if not cosmetic:adapter.explosion(owner_id,point,radius,power,falloff)
