extends RefCounted
const ALTERNATES={"fal":"fal_alt","ump":"ump_alt","katana":"katana_alt","dt11":"dt11_alt","frag":"frag_alt"}
static func active()->bool:
	return not preload("res://scripts/asset_quality.gd").lightweight() and (bool(ProjectSettings.get_setting("ashfall/model_alternatives",false)) or "--alternate-models" in OS.get_cmdline_user_args())
static func choose(id:String)->String:
	if id=="katana":return "katana_alt" # traditional sword, stand/scabbard excluded
	if id=="cyberblade":return "katana" # Genji; rejected gold source remains archived
	return str(ALTERNATES.get(id,id)) if active() else id
