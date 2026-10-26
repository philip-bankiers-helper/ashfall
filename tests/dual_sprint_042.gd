extends "res://tests/dual_pistols_042.gd"
## Actual floor, moving production player, rack delegation and both execution orders.
func run()->void:
	await sprint_regression()
	print("DUAL_SPRINT_042 checks=",checks," failures=",failures," synthetic=true headset_tested=false")
	quit(failures)
