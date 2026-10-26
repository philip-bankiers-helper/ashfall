extends Node3D
## One short-lived, depth-tested number per damage event. Never accumulate hits.
const LIMIT:=48
const LIFETIME:=.85
var actor:Node3D
var entries:Array[Dictionary]=[]
var serial:=0
func setup(value:Node3D)->void:actor=value;process_priority=112
func clear()->void:
	for entry in entries:entry.label.queue_free()
	entries.clear()
func emit_hit(amount:float,target:Node3D,shield_hit:bool)->void:
	if not is_instance_valid(target) or amount<=0 or not is_finite(amount):return
	var camera:Camera3D=actor.get_view_camera()
	var top:Vector3=target.global_position+Vector3.UP*1.85
	if target.has_method("get_damage_number_anchor"):top=target.get_damage_number_anchor()
	var distance:float=camera.global_position.distance_to(top)
	var right:Vector3=camera.global_basis.x.normalized()
	var point:Vector3=top+right*(maxf(.55,distance*.014)+.04*(serial%2))+Vector3.UP*(.10+.12*(serial%4))
	var label:=Label3D.new();label.text=str(maxi(1,roundi(amount)));label.font_size=26;label.pixel_size=clampf(distance*.00060,.0015,.025)
	label.outline_size=3;label.modulate=Color("4ed8ff") if shield_hit else Color("fff0ad")
	label.no_depth_test=false;label.shaded=false;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=point
	add_child(label);entries.append({"label":label,"start":point,"remaining":LIFETIME});serial+=1
	while entries.size()>LIMIT:entries.pop_front().label.queue_free()
func _process(delta:float)->void:
	for i in range(entries.size()-1,-1,-1):
		var entry:Dictionary=entries[i];entry.remaining-=maxf(0,delta)
		if entry.remaining<=0:entry.label.queue_free();entries.remove_at(i);continue
		entry.label.position=entry.start+Vector3.UP*(LIFETIME-entry.remaining)*.14
		entry.label.modulate.a=minf(1,float(entry.remaining)/.22)
