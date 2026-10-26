extends "res://scripts/melee_sword.gd"
## Original compact art. BigBox May20,2021:35damage independent of distance.
## https://steamcommunity.com/ogg/691260/announcements/detail/3024709067883935698
func _init()->void:archetype="knife"
func _damage_for_swing(_speed:float,_travel:float)->float:return 35.0
