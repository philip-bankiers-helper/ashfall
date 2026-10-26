extends Node3D
## Solo rescue exercise. This is not a network teammate or a multiplayer simulation.
signal revived
var downed:=true
var health:=0.0
var revive_count:=0
var _reset_left:=0.0
var _label:Label3D
var _pads:Array[MeshInstance3D]=[]

func _ready()->void:
	add_to_group("revivable_allies")
	var body:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.52,.7,.22);body.mesh=mesh;body.position.y=.51
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.12,.24,.28);body.material_override=mat;add_child(body)
	for side in [-1,1]:
		var pad:=MeshInstance3D.new();var disc:=CylinderMesh.new();disc.top_radius=.075;disc.bottom_radius=.075;disc.height=.012
		pad.mesh=disc;pad.rotation.x=PI/2;pad.position=Vector3(side*.13,.61,.13);add_child(pad);_pads.append(pad)
	_label=Label3D.new();_label.position.y=1.15;_label.font_size=30;_label.pixel_size=.002;_label.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;add_child(_label)
	reset_training()
func reset_training()->void:
	downed=true;health=0;_reset_left=0;_refresh()
func revive_contacts()->Array[Vector3]:
	return [to_global(Vector3(-.13,.61,.13)),to_global(Vector3(.13,.61,.13))]
func can_revive()->bool:return downed and is_visible_in_tree()
func revive()->bool:
	if not can_revive():return false
	downed=false;health=50;revive_count+=1;_reset_left=12;_refresh();revived.emit();return true
func _process(delta:float)->void:
	if _reset_left>0:
		_reset_left=maxf(0,_reset_left-maxf(0,delta))
		if _reset_left==0:reset_training()
func _refresh()->void:
	if _label:_label.text="RESCUE TRAINING\nDOWNED" if downed else "RESCUE COMPLETE\nTraining resets in 12 seconds"
	for pad in _pads:
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(1,.38,.15) if downed else Color(.25,1,.45);pad.material_override=mat
