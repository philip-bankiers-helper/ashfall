extends RefCounted
## Original manual-opening policy; observed reference only establishes load/close.
var state := "ready"
var ammo := 2
var loaded := 2
func open() -> bool:
	if state != "ready": return false
	state="open_empty"
	ammo=0
	loaded=0
	return true
func grab() -> bool:
	if state!="open_empty": return false
	state="holding_shells"
	return true
func release() -> void:
	if state=="holding_shells": state="open_empty"
func insert() -> bool:
	if state!="holding_shells": return false
	state="open_loaded"
	loaded=2
	return true
func close() -> bool:
	if state!="open_loaded": return false
	state="ready"
	ammo=loaded
	return true
func fire() -> bool:
	if state!="ready" or ammo<=0: return false
	ammo-=1
	loaded=ammo
	return true
func reset() -> void:
	state="ready"
	ammo=2
	loaded=2
