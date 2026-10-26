extends "res://scripts/dual_pistols.gd"
## Eight-round paired shotguns; each occupied hand uses the same independent up flick.
func setup(actor:Node3D,connect_desktop:bool=true)->void:
	shotgun_mode=true
	super.setup(actor,connect_desktop)
