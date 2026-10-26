extends "res://scripts/weapon.gd"
## Persistent numeric slot reserved for save compatibility; no standalone gun asset.
func _build_model()->void:
	super._build_model()
	for child in model.get_children():child.hide()
func allows_world_reticle()->bool:return false
