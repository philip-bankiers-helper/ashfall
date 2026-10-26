extends CharacterBody3D
## Render-only actor facade for the existing camo suit and its two-bone arm solver.
var xr_enabled:=true
var tracking_available:=true
var input_enabled:=true
var left_hand:Node3D
var right_hand:Node3D
var view:Camera3D
func get_view_camera()->Camera3D:return view
