extends RefCounted
## Measures actual pool loss, including armor and overkill clamping.
static func snapshot(target:Node)->Dictionary:
	var result:Dictionary={}
	for property in target.get_property_list():
		if property.name in ["health","shield"]:
			var value=float(target.get(property.name))
			if is_finite(value):result[property.name]=maxf(0,value)
	return result

static func loss(before:Dictionary,target:Node)->Dictionary:
	var after:=snapshot(target)
	var health_loss:=maxf(0,float(before.get("health",0))-float(after.get("health",before.get("health",0))))
	var shield_loss:=maxf(0,float(before.get("shield",0))-float(after.get("shield",before.get("shield",0))))
	return {"amount":health_loss+shield_loss,"health":health_loss,"shield":shield_loss}
